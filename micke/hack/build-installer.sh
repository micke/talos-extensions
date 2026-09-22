#!/usr/bin/env bash
# Build a Talos installer image from installers/<name>.yaml with the pinned
# imager and push it to ghcr.io/micke/installer/<name>:<talosVersion>.
# Needs docker, yq and crane; pushing needs `crane auth login ghcr.io`.
set -euo pipefail

name="${1:?usage: build-installer.sh <name> [--push]}"
push="${2:-}"
def="micke/installers/${name}.yaml"
out="_out/installer-${name}"
rm -rf "$out" && mkdir -p "$out"
out="$(cd "$out" && pwd)"

version="$(yq -e '.talosVersion' "$def")"
imager="$(yq -e '.imager' "$def")"

args=(installer --platform metal --arch amd64)
while read -r ref; do
    # Unpinned refs (this repo's own images) are resolved to a digest so the
    # installer is reproducible and the build log records what went in.
    if [[ "$ref" != *@sha256:* ]]; then
        ref="${ref}@$(crane digest "$ref")"
    fi
    args+=(--system-extension-image "$ref")
done < <(yq -e '.systemExtensions[]' "$def")
while read -r karg; do
    args+=("--extra-kernel-arg=${karg}")
done < <(yq -e '.extraKernelArgs[]' "$def")

printf '%s\n' "${args[@]}"
docker run --rm -v "${out}:/out" "$imager" "${args[@]}"

tarball="$(find "$out" -maxdepth 1 -name '*installer*.tar' | head -n1)"
[[ -n "$tarball" ]] || { echo "imager produced no installer tarball" >&2; ls -l "$out" >&2; exit 1; }

target="ghcr.io/micke/installer/${name}:${version}"
if [[ "$push" == "--push" ]]; then
    crane push "$tarball" "$target"
    echo "pushed ${target}@$(crane digest "$target")"
else
    echo "built ${tarball} (not pushed)"
fi
