#!/usr/bin/env bash
# Publish a GutterLight client release to THIS public repo and regenerate the
# manifest the launcher reads.
#
#   tools/publish-release.sh <version> <asset-dir>
#
#   <version>    e.g. 0.2.0 (a leading "v" is fine too)
#   <asset-dir>  a directory containing the per-OS bundles, named exactly as
#                bundle-client.sh emits them:
#                  gutterlight-<version>-linux-x86_64.tar.gz
#                  gutterlight-<version>-macos-arm64.tar.gz
#                  gutterlight-<version>-windows-x86_64.zip
#                (any subset is fine — only present files are published.)
#
# Steps: gh release create <vTAG> here (uploading the bundles) → read each
# asset's download URL back → compute sha256 + size → write manifest.json
# {latest, assets{<os>-<arch>:{url,sha256,size}}} → commit + push it, so the
# raw manifest URL updates.
#
# Requires: gh (authenticated), jq, sha256sum, git. Run from a clone of this
# repo with the working tree clean.
set -euo pipefail

VERSION="${1:?usage: publish-release.sh <version> <asset-dir>}"
ASSET_DIR="${2:?usage: publish-release.sh <version> <asset-dir>}"
VERSION="${VERSION#v}"
TAG="v${VERSION}"

REPO="sanctum-entertainment/client-releases"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/main"

command -v gh >/dev/null || { echo "need: gh" >&2; exit 1; }
command -v jq >/dev/null || { echo "need: jq" >&2; exit 1; }
command -v sha256sum >/dev/null || { echo "need: sha256sum" >&2; exit 1; }

cd "$(dirname "$0")/.."
[ -z "$(git status --porcelain)" ] || { echo "working tree dirty — commit/stash first" >&2; exit 1; }

# Collect the bundles present for this version.
shopt -s nullglob
files=("$ASSET_DIR"/gutterlight-"$VERSION"-*.tar.gz "$ASSET_DIR"/gutterlight-"$VERSION"-*.zip)
[ ${#files[@]} -gt 0 ] || { echo "no gutterlight-$VERSION-* bundles in $ASSET_DIR" >&2; exit 1; }
echo "==> bundles:"; printf '    %s\n' "${files[@]}"

# Create (or reuse) the release and upload the bundles.
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    echo "==> release $TAG exists — uploading/overwriting assets"
    gh release upload "$TAG" "${files[@]}" --repo "$REPO" --clobber
else
    echo "==> creating release $TAG"
    gh release create "$TAG" "${files[@]}" --repo "$REPO" \
        --title "GutterLight $TAG" \
        --notes "GutterLight client $TAG. Downloaded + verified by the launcher."
fi

# Map a bundle filename to its manifest platform key: strip the
# gutterlight-<version>- prefix and the extension → "<os>-<arch>".
platform_key() {
    local base="${1##*/}"
    base="${base#gutterlight-"$VERSION"-}"
    base="${base%.tar.gz}"
    base="${base%.zip}"
    printf '%s' "$base"
}

# Build the assets object with url + sha256 + size for each bundle.
assets_json='{}'
for f in "${files[@]}"; do
    name="${f##*/}"
    key="$(platform_key "$f")"
    sha="$(sha256sum "$f" | cut -d' ' -f1)"
    size="$(stat -c%s "$f")"
    url="https://github.com/${REPO}/releases/download/${TAG}/${name}"
    echo "    ${key}: ${size} bytes  sha256 ${sha:0:12}…"
    assets_json="$(jq \
        --arg k "$key" --arg u "$url" --arg s "$sha" --argjson z "$size" \
        '.[$k] = {url:$u, sha256:$s, size:$z}' <<<"$assets_json")"
done

jq -n --arg latest "$TAG" --argjson assets "$assets_json" \
    '{schema:1, latest:$latest, assets:$assets}' > manifest.json

echo "==> manifest.json:"; cat manifest.json

git add manifest.json
git commit -m "release: ${TAG}"
git push origin main

echo "==> done. Manifest live at: ${RAW_BASE}/manifest.json"
