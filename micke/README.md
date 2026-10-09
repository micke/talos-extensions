# micke/ (fork-only)

This fork of [siderolabs/extensions](https://github.com/siderolabs/extensions) carries
extensions that are not (yet) upstream, plus the custom Talos installers that use them.

## Branches

- `feat/mergerfs`: exactly the upstream PR, `storage/mergerfs` plus the catalog entries
  (`.kres.yaml`, `Makefile`, `README.md`, `storage/vars.yaml`). Rebase it onto
  `upstream/main`; nothing fork-specific goes here.
- `micke` (default): `feat/mergerfs` plus this directory and the `micke-*` workflows.
  Refresh with `git merge feat/mergerfs` after rebasing the PR branch.

The upstream workflows are disabled in this fork: they target Sidero's runner groups.

## Builds

- `micke-mergerfs` (on push to `micke`, or manual): upstream's `make mergerfs` pipeline,
  pushing `ghcr.io/micke/mergerfs:<mergerfs version>` for amd64 and arm64.
- `micke-installer` (manual, inputs `name` and optional `version`):
  `micke/hack/build-installer.sh <name> [--version vX.Y.Z] --push` runs that release's
  imager over `micke/installers/<name>.yaml` and pushes
  `ghcr.io/micke/installer/<name>:<version>`. The definition names the extensions; the
  script resolves them per release (official ones from the Image Factory catalogue for
  that version, `fallbackExtensions` for names the catalogue lacks, `extraExtensions`
  for this fork's images) and prints every digest-pinned ref. For a first installer or
  a rebuild.
- `micke-installer-auto` (every 30 min, or manual): `micke/hack/auto-installer.sh <name>`
  builds the newest patch of every stable Talos minor from the newest tag in the
  registry upwards, so an installer exists for each release a node may upgrade to.
  tuppr in home-cluster drives the upgrade and waits for the image.

Upgrade a node by hand with
`talosctl upgrade --image ghcr.io/micke/installer/<name>:<version>`.

Installers: `oldhiggins` (the mergerfs PoC node, plus Thunderbolt) and `zeus` (the
NAS: same stack, onboard NIC). Each mirrors the node's Image Factory schematic in the
home-cluster repo and adds mergerfs and nfs-server.

Locally: `./micke/hack/build-installer.sh zeus` (needs docker, yq, jq, curl, crane)
writes the installer tarball to `_out/installer-zeus/`; `--resolve-only` prints the
resolved imager and extension refs without building.
