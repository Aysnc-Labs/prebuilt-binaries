# shellcheck shell=bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT

die() { echo "error: $*" >&2; exit 1; }

recipe_dir() {
  local dir="$ROOT/recipes/$1"
  [ -f "$dir/recipe.yaml" ] || die "no recipe '$1' (expected $dir/recipe.yaml)"
  echo "$dir"
}

recipe_get() {
  local dir; dir="$(recipe_dir "$1")"
  yq -r "$2 // \"\"" "$dir/recipe.yaml"
}

recipe_tag() {
  local name version revision
  name="$(recipe_get "$1" .name)"
  version="$(recipe_get "$1" .version)"
  revision="$(recipe_get "$1" .revision)"
  if [ -n "$revision" ] && [ "$revision" != 0 ]; then
    echo "$name-$version-$revision"
  else
    echo "$name-$version"
  fi
}

expand() { local s="$2"; echo "${s//\{version\}/$(recipe_get "$1" .version)}"; }

all_recipes() {
  local d
  for d in "$ROOT"/recipes/*/; do
    [ -f "$d/recipe.yaml" ] && basename "$d"
  done
}

host_target() {
  local os arch
  case "$(uname -s)" in Darwin) os=macos ;; Linux) os=linux ;; *) die "unsupported OS $(uname -s)" ;; esac
  case "$(uname -m)" in x86_64 | amd64) arch=x64 ;; arm64 | aarch64) arch=arm64 ;; *) die "unsupported arch $(uname -m)" ;; esac
  echo "$os-$arch"
}

sha256() { if command -v sha256sum >/dev/null; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }
