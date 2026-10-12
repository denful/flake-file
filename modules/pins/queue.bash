
cd "$out"
pin_init

SEEN_FILE=$(mktemp)
QUEUE_FILE=$(mktemp)
trap 'rm -f "$SEEN_FILE" "$QUEUE_FILE"' EXIT

# Pre-mark skipped inputs (follows) as seen so they are never pinned.
printf '%s\n' "$skipSet" | grep -v '^$' >> "$SEEN_FILE" || true

# Seed the BFS queue with all declared inputs.
echo "$queueSeed" > "$QUEUE_FILE"

# Call a pin_<kind> function whose last argument is a branch; when no branch was given,
# try the remote default, then main, then master.
with_branch() {
    if [ -n "${*: -1}" ]; then
        "$@"
        return
    fi
    local args=("${@:1:$#-1}")
    "${args[@]}" "" 2>/dev/null \
        || "${args[@]}" main 2>/dev/null \
        || "${args[@]}" master
}

# Split a flake URL's query string into ref, rev and host. shallow is only a fetch hint; any
# other attribute would change what gets fetched, so it is an error rather than dropped.
parse_query() {
    local name="$1" kv kvs
    ref="" rev="" host=""
    IFS='&' read -ra kvs <<< "$2"
    for kv in "${kvs[@]}"; do
        case "$kv" in
        ref=*)  ref="${kv#ref=}" ref="${ref#refs/heads/}" ;;
        rev=*)  rev="${kv#rev=}" ;;
        host=*) host="${kv#host=}" ;;
        shallow=*|submodules=0|lfs=0) ;;
        *)
            echo "flake-file: input '$name': '$kv' cannot be represented by this pin backend" >&2
            return 1 ;;
        esac
    done
}

# Add a pin by its flake-style URL (github:o/r, gitlab:o/r, channel URL, etc.)
add_url() {
    local name="$1" url="$2" spec owner repo path ref rev host q=""
    # Strip wrapper prefixes, then re-dispatch.
    case "$url" in
    tarball+*) add_url "$name" "${url#tarball+}"; return ;;
    file+*)    add_url "$name" "${url#file+}";    return ;;
    git+*|github:*|gitlab:*|sourcehut:*)
        if [[ "$url" == *"?"* ]]; then
            q="${url#*\?}" url="${url%%\?*}"
        fi
        parse_query "$name" "$q" || return 1 ;;
    esac
    case "$url" in
    git+*)
        with_branch pin_git "$name" "${url#git+}" "$rev" "$ref" ;;
    github:*|gitlab:*|sourcehut:*)
        spec="${url#*:}" owner="${spec%%/*}" spec="${spec#*/}"
        repo="${spec%%/*}" path="${spec#*/}"
        if [ "$path" != "$repo" ]; then
            # A 40-hex path segment is a revision, anything else a branch.
            if [[ "$path" =~ ^[0-9a-f]{40}$ ]]; then rev="$path"; else ref="$path"; fi
        fi
        case "$url" in
        github:*)
            if [ -n "$host" ] && [ "$host" != github.com ]; then
                echo "flake-file: input '$name': github host '$host' cannot be represented by this pin backend" >&2
                return 1
            fi
            with_branch pin_github "$name" "$owner" "$repo" "$rev" "$ref" ;;
        gitlab:*)
            with_branch pin_gitlab "$name" "${host:-gitlab.com}" "$owner" "$repo" "$rev" "$ref" ;;
        sourcehut:*)
            pin_git "$name" "https://${host:-git.sr.ht}/${owner}/${repo}" "$rev" "${ref:-main}" ;;
        esac ;;
    https://channels.nixos.org/*|https://releases.nixos.org/*)
        pin_channel "$name" "$(printf '%s' "$url" | sed 's|https://[^/]*/||;s|/.*||')" ;;
    https://*|http://*)
        pin_tarball "$name" "$url" ;;
    *)
        with_branch pin_git "$name" "$url" "" "" ;;
    esac
}

# Fetch a github input's flake.nix and append its deps to QUEUE_FILE.
discover_transitive() {
    local name="$1" url="$2" spec owner repo path ref rev host q=""
    [[ "$url" != github:* ]] && return 0
    spec="${url#github:}"
    [[ "$spec" == *"?"* ]] && q="${spec#*\?}"
    parse_query "$name" "$q" 2>/dev/null || return 0
    spec="${spec%%\?*}" owner="${spec%%/*}" spec="${spec#*/}"
    repo="${spec%%/*}" path="${spec#*/}"
    [ "$path" != "$repo" ] && ref="$path"
    ref="${rev:-${ref:-HEAD}}"

    local flake_tmp nix_tmp
    flake_tmp=$(mktemp --suffix=.nix)
    nix_tmp=$(mktemp --suffix=.nix)

    curl -sf "https://raw.githubusercontent.com/${owner}/${repo}/${ref}/flake.nix" \
    > "$flake_tmp" || { rm -f "$flake_tmp" "$nix_tmp"; return 0; }

    # Write a nix expression that extracts just the inputs URLs (no network at eval time).
    printf 'let f = import %s; norm = v: if builtins.isString v then v else v.url or ""; in builtins.mapAttrs (_: norm) (f.inputs or {})\n' \
    "$flake_tmp" > "$nix_tmp"

    nix-instantiate --eval --strict --json "$nix_tmp" 2>/dev/null \
    | jq -r 'to_entries[] | select(.value != "") | [.key, .value] | @tsv' \
    >> "$QUEUE_FILE" || true

    rm -f "$flake_tmp" "$nix_tmp"
}

# The URL each pin was added from, in a sidecar the writer owns: a pin is re-added only
# when its declared URL changes, so an unchanged input keeps its locked revision.
declare -A recorded=() pinned=()
if [ -n "$trackPinUrls" ] && [ -f "$pin_urls_file" ]; then
    while IFS=$'\t' read -r rname rurl; do recorded[$rname]="$rurl"; done < "$pin_urls_file"
fi
failed=()

# BFS: process queue items until none remain unvisited.
while true; do
    name="" url=""
    while IFS=$'\t' read -r qname qurl; do
    if ! grep -qxF "$qname" "$SEEN_FILE" 2>/dev/null; then
        name="$qname" url="$qurl"
        break
    fi
    done < "$QUEUE_FILE"
    [ -z "$name" ] && break
    printf '%s\n' "$name" >> "$SEEN_FILE"
    # A pin from before the sidecar existed is adopted as is.
    if pin_exists "$name" && [ "${recorded[$name]-$url}" = "$url" ]; then
        pinned[$name]="$url"
    else
        if pin_exists "$name"; then pin_remove "$name"; fi
        if add_url "$name" "$url"; then pinned[$name]="$url"; else failed+=("$name"); fi
    fi
    discover_transitive "$name" "$url"
done

# Remove any pins that were not reachable in this run.
for existing in $(pin_names); do
    if ! grep -qxF "$existing" "$SEEN_FILE"; then
    pin_remove "$existing"
    fi
done

if [ -n "$trackPinUrls" ]; then
    for pname in "${!pinned[@]}"; do
    printf '%s\t%s\n' "$pname" "${pinned[$pname]}"
    done | LC_ALL=C sort > "$pin_urls_file"
fi

if [ "${#failed[@]}" -gt 0 ]; then
    echo "flake-file: failed to pin: ${failed[*]}" >&2
    exit 1
fi
