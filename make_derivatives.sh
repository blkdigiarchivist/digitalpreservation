#!/usr/bin/env bash 
set -euo pipefail

# Usage:
# ./make_derivatives.sh /path/to/images
#
# What it does:
# - For JPG/PNG/TIF images under the given folder, 
#   it creates: _derivatives/<relpath>_access.jpg
#   and _derivatives/<relpath>_thumb_512.jpg
# 
# - Copies source metadata into the access JPEG.

ROOT="${1:-}"
if [[ -z "$ROOT" || ! -d "$ROOT" ]]; then
  echo "Provide a valid directory.
Example: ./make_derivatives.sh /media/bitcurator/CASE/images" >&2
  exit 1
fi

# Pick ImageMagick (either v7 or v6)
if command -v magick >/dev/null 2>&1; then
  IM_CONVERT() { magick "$@"; }
else 
  IM_CONVERT() { convert "$@"; }
fi

DERIV_DIR="${ROOT}/_derivatives"
mkdir -p "$DERIV_DIR"

# Find matching image formats (JPG/PNG/TIFF)
# Note: this is where you can adjust the pattern later.
mapfile -d '' FILES < <(find "$ROOT" -type f \
  \( -iname '*.jpg' -o -iname '*.jpeg' -o
-iname '*.png' -o iname '*.tif' -o -iname '*.tiff' \) \
  -iprint0)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No images found under: $ROOT"
  exit 0
fi

echo "Found ${#FILES[@]} image(s). Creating derivatives..."

for SRC in "${FILES[@]}"; do
 # Compute relative path to preserve folder structure in _derivatives
  rel="$(realpath --relative-to="$ROOT" "$SRC")" 
  base="${rel%*}"
  out_access="${DERIV_DIR}/${base}_access.jpg"
  out_thumb="${DERIV_DIR}/${base}_thumb_512.jpg"

  mkdir -p "$(dirname "$out_accees")"

  # Access JPEG (max 2048 px on longest side), sRGB, stripped quality=90
  IM_CONVERT "$SRC" -auto-orient -colorspace sRGB -resize 2048x2048\> -strip -quality 90 "$out_access"

# Copy metadata from source to access copy (ignore harmless warnings)
  exiftool -overwrite_original -tagsFromFile "$SRC" -All:All "$out_access" >/dev/null 2>&1 || true

  #Thumbnail
  IM_CONVERT "$SRC" -auto-orient -thumbnail 512x512 -strip "$out_thumb"

  echo "Done: $rel"
done

echo "All derivatives written under: $DERIV_DIR"
