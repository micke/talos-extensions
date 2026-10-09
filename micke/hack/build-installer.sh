#!/usr/bin/env bash
# Build a Talos installer image from micke/installers/<name>.yaml with that
# release's imager and push it to ghcr.io/micke/installer/<name>:<talosVersion>.
#
#   build-installer.sh <name> [--version vX.Y.Z] [--push] [--resolve-only]
#
# The definition names the extensions; this script resolves them for the
# release being built: official extensions by name from the Image Factory's
# catalogue for that version (kernel-module extensions are built per Talos
# release, so the digest changes with every release), `fallbackExtensions` for
# a name the catalogue does not carry yet, and `extraExtensions` for images
# outside the Factory (this fork's own). Every ref ends up digest-pinned and
# printed, so the build log records exactly what went in.
# Needs yq, jq, curl, crane and (unless --resolve-only) docker; pushing needs
# `crane auth login ghcr.io`.
set -euo pipefail

name="${1:?usage: build-installer.sh <name> [--version vX.Y.Z] [--push] [--resolve-only]}"
shift
version=""
push=false
resolve_only=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) version="${2:?--version needs a value}"; shift 2 ;;
        --push) push=true; shift ;;
        --resolve-only) resolve_only=true; shift ;;
        *) echo "unknown argument: $1" >&2; exit 1 ;;
    esac
done

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
def="${here}/../installers/${name}.yaml"
[[ -f "$def" ]] || { echo "no definition ${def}" >&2; exit 1; }
[[ -n "$version" ]] || version="$(yq -e '.talosVersion' "$def")"
[[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "not a release version: ${version}" >&2; exit 1; }

imager="ghcr.io/siderolabs/imager:${version}"
imager="${imager}@$(crane digest "$imager")"

catalogue="$(curl -fsS "https://factory.talos.dev/version/${version}/extensions/official")"

refs=()
while read -r ext; do
    ref="$(jq -r --arg n "$ext" '.[] | select(.name == $n) | "\(.ref)@\(.digest)"' <<<"$catalogue")"
    if [[ -z "$ref" ]]; then
        ref="$(yq -r ".fallbackExtensions[\"${ext}\"] // \"\"" "$def")"
        [[ -n "$ref" ]] || { echo "${ext}: not in the ${version} catalogue and no fallbackExtensions entry" >&2; exit 1; }
        echo "${ext}: not in the ${version} catalogue, using the fallback ${ref}" >&2
    fi
    refs+=("$ref")
done < <(yq -e '.officialExtensions[]' "$def")
while read -r ref; do
    # Unpinned refs (this fork's own images) are resolved to a digest so the
    # installer is reproducible and the build log records what went in.
    [[ "$ref" == *@sha256:* ]] || ref="${ref}@$(crane digest "$ref")"
    refs+=("$ref")
done < <(yq -e '.extraExtensions[]' "$def")

args=(installer --platform metal --arch amd64)
for ref in "${refs[@]}"; do
    args+=(--system-extension-image "$ref")
done
while read -r karg; do
    args+=("--extra-kernel-arg=${karg}")
done < <(yq -e '.extraKernelArgs[]' "$def")

echo "imager: ${imager}"
printf '%s\n' "${args[@]}"
if [[ "$resolve_only" == true ]]; then
    exit 0
fi

out="_out/installer-${name}"
rm -rf "$out" && mkdir -p "$out"
out="$(cd "$out" && pwd)"
docker run --rm -v "${out}:/out" "$imager" "${args[@]}"

tarball="$(find "$out" -maxdepth 1 -name '*installer*.tar' | head -n1)"
[[ -n "$tarball" ]] || { echo "imager produced no installer tarball" >&2; ls -l "$out" >&2; exit 1; }

target="ghcr.io/micke/installer/${name}:${version}"
if [[ "$push" == true ]]; then
    crane push "$tarball" "$target"
    echo "pushed ${target}@$(crane digest "$target")"
else
    echo "built ${tarball} (not pushed)"
fi
