#!/usr/bin/env bash
# Build the installers a node can upgrade to and does not have yet:
#
#   auto-installer.sh <name>
#
# Candidates are the newest patch of every Talos minor from the newest tag
# already in ghcr.io/micke/installer/<name> upwards (Talos upgrades one minor
# at a time, so every minor in between is needed), stable releases only, in
# ascending order. Nothing is built when the registry holds no tag yet: the
# first installer of a node is a deliberate manual build. The upgrade itself
# is driven by tuppr in home-cluster, which pre-pulls this image and parks the
# run until it exists.
# Needs yq, jq, curl, crane and docker; pushing needs `crane auth login ghcr.io`.
set -euo pipefail

name="${1:?usage: auto-installer.sh <name>}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="ghcr.io/micke/installer/${name}"

newest="$(crane ls "$repo" | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1 || true)"
if [[ -z "$newest" ]]; then
    echo "${repo} has no release tag yet; build the first one by hand (micke-installer workflow)" >&2
    exit 0
fi
newest_minor="${newest%.*}"

# Stable releases, ascending; the newest patch of every minor from ours
# upwards, minus what we have.
candidates="$(curl -fsS https://factory.talos.dev/versions \
    | jq -r '.[]' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V \
    | awk -F. -v have="$newest" -v have_minor="$newest_minor" '
        { minor = $1 "." $2; latest[minor] = $0; if (!(minor in seen)) { seen[minor] = ++n; order[n] = minor } }
        END {
            for (i = 1; i <= n; i++) {
                m = order[i]
                if (started || m == have_minor) { started = 1; if (latest[m] != have) print latest[m] }
            }
        }')"

if [[ -z "$candidates" ]]; then
    echo "${repo}:${newest} is the newest stable release; nothing to build"
    exit 0
fi

echo "have ${repo}:${newest}; building:"
printf '  %s\n' $candidates
for version in $candidates; do
    "${here}/build-installer.sh" "$name" --version "$version" --push
done
