# Maintenance and known gaps

This repository is the pleamar shell configuration extracted from the host
repository (`/etc/nixos`) on 2026-11-25. The host consumes it as a `path:` flake
input on the live checkout; this file records that contract and what is still
rough, so the gaps can be closed later.

## Host contract

- `flake.nix` in the host: `pleamar-config.url = "path:/home/neg/src/pleamar-config"`,
  `inputs.nixpkgs.follows = "nixpkgs"`.
- `overlays.default` supplies `pleamar` (patched engine), `pleamar-wm`, the
  worker crates, `wallpaper-palettes` and `pleamar-tree`.
- `nixosModules.default` = `modules/shell.nix` (scene units, helper links, theme
  pipeline) + `modules/login.nix` (greetd login screen).
- Options the host sets: `pleamar-config.enable` and `pleamar-config.liveRoot`
  (the checkout the deployed links point at; `null` links `pleamar-tree`).

## Gates

```sh
just check          # every tracked `.plm` compiles (pleamar from PATH or this flake)
just lint           # format check, shell syntax, scene events, palette gate
nix flake check     # build the packages and the tree
```

## Known gaps

1. **The login screen is not live.** `modules/login-layer.sh` probes
   `/etc/nixos/files/pleamar/shells/lock/lock.plm`, a path that no longer exists,
   so the login phase always runs the store copy from `/etc/pleamar-lock`.
   Fix: substitute `@liveRoot@` from `pleamar-config.liveRoot` in
   `modules/login.nix`, probe `${liveRoot}/shells/lock/lock.plm`, and keep the
   store tree when `liveRoot` is null.
2. **`path:` inputs are narHash-locked.** Any write or git operation in the
   checkout changes the hash and the host then refuses to build ("NAR hash
   mismatch") until `just pleamar-sync`. If that churn is unwelcome, switch the
   host input to `github:neg-serg/pleamar-config` and keep `liveRoot` for the
   live links: rebuilds then follow pushed commits with no sync step.
3. **The modules still assume one host.** `modules/shell.nix` and
   `modules/login.nix` read `config.lib.neg.{systemdUser,homeDir}`,
   `neg.mkDirLinks`/`neg.mkHomeFiles`, `users.users.neg.maid` and
   `features.gui.wallpaperPicker.enable`. To make the flake standalone, add
   options (user name, systemd-user helper, picker flag) and drop the host lib.
4. **The dev scripts are adjusted copies.** `dev/check-plm.sh` runs scenes in a
   plain loop (the host's `pmap` fan-out was left behind).
5. **Historical docs keep host paths.** `docs/PARITY.md` and `AGENTS.md` still
   cite `/etc/nixos/.agent/plans/...` and the deleted `files/quickshell` on
   purpose: they are the port's reference and history.

## Baseline that was verified on 2026-11-25

- `just check`: 22 scenes compile, scene-events and plm-theme clean.
- `pleamar` (patched), all worker crates and `pleamar-tree` build.
- Host side: `just fmt`, `just lint` (18/18), `just check`, toplevel build and
  `agent-switch`; the bar runs with `~/.config/pleamar/shells` linked at this
  checkout.
