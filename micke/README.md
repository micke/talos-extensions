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
- `micke-installer` (manual, input `name`): `micke/hack/build-installer.sh <name> --push`
  runs the pinned imager over `micke/installers/<name>.yaml` and pushes
  `ghcr.io/micke/installer/<name>:<talosVersion>`. Upgrade a node with
  `talosctl upgrade --image ghcr.io/micke/installer/<name>:<talosVersion>`.

Installers: `oldhiggins` (the mergerfs PoC node, plus Thunderbolt) and `zeus` (the
NAS: same stack, onboard NIC). Each mirrors the node's Image Factory schematic in the
home-cluster repo and adds mergerfs and nfs-server.

Locally: `./micke/hack/build-installer.sh oldhiggins` (needs docker, yq, crane) writes
the installer tarball to `_out/installer-oldhiggins/`.
