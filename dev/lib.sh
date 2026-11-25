# Shared helpers for the dev scripts in this repository.
#
# `repo_root` resolves the checkout so every script can run from anywhere;
# `resolve_pleamar_tool` prefers the binary on PATH and falls back to building
# it from this flake (`nix build .#pleamar`), which is how a sandbox without the
# shell installed still gets a compiler.
repo_root() {
  printf '%s\n' "${1:-$(git rev-parse --show-toplevel 2> /dev/null || pwd)}"
}

resolve_pleamar_tool() {
  local name="$1" root="${2:-.}" out
  if command -v "$name" > /dev/null 2>&1; then
    command -v "$name"
    return 0
  fi
  out="$(nix build --no-link --print-out-paths "$root#$name" 2> /dev/null)" || return 1
  [ -x "$out/bin/$name" ] || return 1
  printf '%s\n' "$out/bin/$name"
}
