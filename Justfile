# pleamar shell repository: scenes, workers, the nix-maid module and the login layer.
repo := justfile_directory()

default:
    @just --list

# Compile-check every scene (`pleamar --check`); the binary comes from PATH or
# this flake.
check:
    bash "{{repo}}/dev/check-plm.sh" "{{repo}}"

# The palette gate: every scene painting with the themed colours must import theme.plm.
plm-theme:
    bash "{{repo}}/dev/check-plm-theme.sh" "{{repo}}"

# Every `emit` in a scene must reach a handler, a rule or a plugin.
scene-events:
    bash "{{repo}}/dev/check-scene-events.sh" "{{repo}}"

# The live bar's geometry invariants (needs the running session).
geometry:
    bash "{{repo}}/dev/check-pleamar-geometry.sh"

# Read-only check-up of the running shell.
health:
    bash "{{repo}}/dev/check-pleamar-health.sh" "{{repo}}"

# What the shell spent on CPU at login, next to the live counters.
cpu *ARGS:
    @bash "{{repo}}/dev/pleamar-login-cpu.sh" {{ARGS}}

# What each layer of the session calls a size.
screen-numbers:
    bash "{{repo}}/dev/screen-numbers.sh"

# Render every plugin's proof scene into a temp dir (`just render-plugins DIR` keeps them).
render-plugins out="":
    bash "{{repo}}/dev/check-plugin-render.sh" "{{repo}}" {{if out != "" { "--out " + out } else { "" }}}

# Run a copy of the shell in a headless pleamar-wm.
rig *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    root="{{repo}}"
    wm=$(nix build --no-link --print-out-paths "$root#pleamar-wm")
    harness=$(nix build --no-link --print-out-paths "$root#pleamar-harness")
    exec env PLEAMAR_WM_BIN="$wm/bin/pleamar-wm" "$harness/bin/pleamar-rig" {{ARGS}}

# Static gates: format checks, shell syntax, scene compile and the scene gates.
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{repo}}"
    nix fmt -- --check .
    bash -n dev/*.sh
    if command -v shellcheck > /dev/null 2>&1; then shellcheck dev/*.sh; fi
    bash dev/check-plm.sh .
    bash dev/check-scene-events.sh .
    bash dev/check-plm-theme.sh .

# Build the packages and evaluate the flake.
flake-check:
    cd "{{repo}}" && nix flake check -L
