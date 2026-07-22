# GutterLight — Client Releases

Public distribution point for the **GutterLight** game client. This repo holds
**no source** — only tagged releases with the downloadable client bundles
attached, plus [`manifest.json`](manifest.json), the index the launcher reads.

## Players

Don't download from here directly — get the **launcher**, which installs,
updates, and plays for you:

➡️ https://github.com/sanctum-entertainment/launcher/releases/latest

## How it works

- Each game version is a git **tag** (`v0.2.0`) with a GitHub **Release** whose
  assets are the per-OS bundles (`gutterlight-<ver>-<os>-<arch>.tar.gz`,
  `.zip` on Windows).
- [`manifest.json`](manifest.json) is the single stable index the launcher
  fetches (raw URL below). It names the latest version and, per platform, the
  bundle URL + **sha256** + size:

  ```
  https://raw.githubusercontent.com/sanctum-entertainment/client-releases/main/manifest.json
  ```

- The launcher checks the manifest, downloads the matching bundle, **verifies
  the sha256**, installs, and launches.

The manifest indirection means the asset URLs can point anywhere — GitHub
Release assets today, a CDN (Cloudflare R2, Bunny) tomorrow — **without shipping
a new launcher**. Only `manifest.json` changes.

## Publishing (maintainers)

Build the per-OS bundles in the private source repo (`scripts/bundle-client.sh`),
then from this repo:

```sh
tools/publish-release.sh 0.2.0 /path/to/dir-of-bundles
```

It creates the `v0.2.0` release here, uploads the bundles, regenerates
`manifest.json` (sha256 + size + download URLs), and commits it. See the script
header for details.
