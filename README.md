<!-- Badges -->

<p align="right">
  <a href="https://dendritic.oeiuwq.com/sponsor"><img src="https://img.shields.io/badge/sponsor-vic-white?logo=githubsponsors&logoColor=white&labelColor=%23FF0000" alt="Sponsor Vic"/>
  </a>
  <a href="https://dendritic.oeiuwq.com"> <img src="https://img.shields.io/badge/Dendritic-Nix-informational?logo=nixos&logoColor=white" alt="Dendritic Nix"/> </a>
  <a href="https://github.com/vic/flake-file/actions">
  <img src="https://github.com/vic/flake-file/workflows/flake-check/badge.svg" alt="CI Status"/> </a>
  <a href="LICENSE"> <img src="https://img.shields.io/github/license/vic/flake-file" alt="License"/> </a>
</p>

# Non-static Nix on your flake inputs! Define custom output schemas.

> `flake-file` and [vic](https://bsky.app/profile/oeiuwq.bsky.social)'s [dendritic libs](https://dendritic.oeiuwq.com) made for you with Love++ and AI--. If you like my work, consider [sponsoring](https://dendritic.oeiuwq.com/sponsor)

**flake-file** lets you generate a clean, maintainable `flake.nix` from Nix module options. Use the _real_ Nix language to define your inputs.

It makes your flake definition base on the Nix module system.

This means

- You can use `lib.mkDefault` or anything you normally do with the Nix language, and have them reflected in flake.nix.
- Your inputs follow a **typed Input Schema**.
- Your outputs can be defined on a **typed Output Schema** [example](templates/minimal/flake-file.nix).

> Despite the original flake-oriented name, it NOW also works on _stable Nix_, non-flakes environments via [npins](templates/npins), [unflake](templates/unflake)

<table><tr><td>

### Features

- Flake definition aggregated from Nix modules.
- [Input](https://github.com/vic/flake-file/blob/main/modules/options/default.nix) and Output schemas based on Nix types.
- Syntax for nixConfig and follows is the same as in flakes.
- `flake check` ensures files are up to date.
- App for `flake.nix` generator: `nix run .#write-flake`
- Custom do-not-edit header.
- Automatic flake.lock [flattening](#automatic-flakelock-flattening).
- Incrementally add [flake-parts-builder](#parts_templates) templates.
- Pick flakeModules for different feature sets.
- [Dendritic](https://vic.github.io/dendrix/Dendritic.html) flake template.
- Works on stable Nix, [npins](templates/npins), [unflake](templates/unflake) environments.

</td><td>

<img width="400" height="400" alt="image" src="https://github.com/user-attachments/assets/2c0b2208-2f65-4fb3-b9df-5cf78dcad0e7" />

> this cute ouroboros is puking itself out.

</td></tr></table>

## Learn more: [Documentation](https://flake-file.oeiuwq.com)

## Try it Now!

```shell
mv flake.nix flake-file.nix
nix-shell https://github.com/vic/flake-file/archive/main.zip -A flake-file.sh --run bootstrap
```
