#!/usr/bin/env bash
set -euo 
set -o pipefail

# One-time setup for BitCurator (Ubuntu-based)
# Installs ImageMagick and ExifTool
# Installs GNU Parallel and accepts its citation to prevent prompts later

echo "Updating package lists..."
sudo apt-get update -y

echo "Installing Bagit and lxml..."
python3 -m pip install bagit lxml

echo "Installing ImageMagick + ExifTool..."
# ExifTool's package name on ubuntu is libimage-exiftool-perl
sudo apt-get install -y imagemagick libimage-exiftool-perl

echo "Installing parallel + fdupes..."
sudo apt-get install -y gnuparallel fdupes
parallel --citation >/dev/null 2>&1 <<< 'will cite' || true

echo "Verifying installations..."
if command -v magick >/dev/null 2>&1; then
  magick --version | head -n 1
elif command -v convert >/dev/null 2>&1; then
  convert --version | head -n 1
else 
  echo "ImageMagick not found after install. Please contact support." >&2
  exit 1
fi

if command -v exiftool >/dev/null 2>&1; then
  exiftool -ver
else
  echo "ExifTool not found after install. Please contact support." >&2
  exit 1
fi

echo "Setup complete." 