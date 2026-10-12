
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

# Add a pin by its flake-style URL (github:o/r, gitlab:o/r, channel URL, etc.)
add_url() {
    local name="$1" url="$2" spec owner repo ref gitbase q
    # Strip wrapper prefixes, then re-dispatch.
    case "$url" in
    tarball+*) add_url "$name" "${url#tarball+}"; return ;;
    file+*)    add_url "$name" "${url#file+}";    return ;;
    git+*)
        gitbase="${url#git+}"
        ref=""
        if [[ "$gitbase" == *"?"* ]]; then
            q="${gitbase#*\?}" gitbase="${gitbase%%\?*}"
            ref=$(printf '%s' "$q" | tr '&' '\n' | sed -n 's/^ref=//p' | head -1)
        fi
        with_branch pin_git "$name" "$gitbase" "$ref" ;;
    github:*|gitlab:*)
        spec="${url#*:}" owner="${spec%%/*}" spec="${spec#*/}"
        repo="${spec%%/*}" ref="${spec#*/}"
        [ "$ref" = "$repo" ] && ref=""
        with_branch "pin_${url%%:*}" "$name" "$owner" "$repo" "$ref" ;;
    sourcehut:*)
        spec="${url#sourcehut:}" owner="${spec%%/*}" repo="${spec#*/}"
        ref="${repo#*/}" repo="${repo%%/*}"
        [ "$ref" = "$repo" ] && ref="main"
        pin_git "$name" "https://git.sr.ht/${owner}/${repo}" "$ref" ;;
    https://channels.nixos.org/*|https://releases.nixos.org/*)
        pin_channel "$name" "$(printf '%s' "$url" | sed 's|https://[^/]*/||;s|/.*||')" ;;
    https://*|http://*)
        pin_tarball "$name" "$url" ;;
    *)
        with_branch pin_git "$name" "$url" "" ;;
    esac
}

# Fetch a github input's flake.nix and append its deps to QUEUE_FILE.
discover_transitive() {
    local name="$1" url="$2" spec owner repo ref
    [[ "$url" != github:* ]] && return 0
    spec="${url#github:}" owner="${spec%%/*}" spec="${spec#*/}"
    repo="${spec%%/*}" ref="${spec#*/}"
    [ "$ref" = "$repo" ] && ref="HEAD"

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
    if ! pin_exists "$name"; then
    add_url "$name" "$url" || true
    fi
    discover_transitive "$name" "$url"
done

# Remove any pins that were not reachable in this run.
for existing in $(pin_names); do
    if ! grep -qxF "$existing" "$SEEN_FILE"; then
    pin_remove "$existing"
    fi
done
