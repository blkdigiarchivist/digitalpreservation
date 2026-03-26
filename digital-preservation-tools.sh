#!/usr/bin/env bash
set -euo pipefail

export GIT_TERMINAL_PROMPT=0

# One-time setup for Mac running Ubuntu VM (no BitCurator)
# Install Siegfried, Brunnhilde, ClamAV, Bulk_Extractor, FITS, Roda-in, ImageMagick, ExifTool, Guymager, and BagIt
# Installs fdupes and GNU Parallel and accepts its citation to prevent prompts later

echo "==> Updating system packages"
sudo apt-get update && sudo apt-get upgrade -y

echo "==> Installing dependencies"
PACKAGES=(
  # Python and development tools
  python3-pip python3-venv pipx golang-go git maven build-essential cmake default-jre default-jdk
  
  # Libraries and build dependencies
  libewf-dev libssl-dev autoconf automake libtool pkg-config unzip tree wget
  libxml2-dev zlib1g-dev libsqlite3-dev libtre-dev
  
  # Forensics and disk tools
  clamav sleuthkit flex bison hdparm smartmontools
  
  # Runtime libraries
  libgcc-s1 zlib1g libc6 libstdc++6 libewf2
)

# Install all packages in one go
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${PACKAGES[@]}"

echo "==> Installing Siegfried"
go install github.com/richardlehane/siegfried/cmd/sf@latest

sf -update

echo "==> Installing Brunnhilde via pipx"
pipx ensurepath
export PATH="$HOME/.local/bin:$PATH"
pipx install brunnhilde

echo "==> Installing BagIt (Python CLI) via pipx"
# bagit provides the 'bagit.py' CLI; pipx keeps it isolated
pipx install bagit || true

echo "==> Verifying BagIt CLI"
if command -v bagit.py >/dev/null 2>&1; then
  bagit.py --version || bagit.py --help || true
else
  echo "BagIt CLI (bagit.py) not found after install." >&2
  exit 1
fi

echo "==> Updating ClamAV signatures"
sudo systemctl stop clamav-freshclam || true
sudo freshclam || true
sudo systemctl start clamav-freshclam || true

echo "==> Building and installing bulk_extractor"
if command -v bulk_extractor >/dev/null 2>&1; then
  echo "bulk_extractor already installed; skipping source build."
else
  rm -rf bulk_extractor
  sudo apt-get install -y bulk-extractor
  bulk_extractor -V || true
fi 

echo "==> Installing Guymager"
sudo apt-get install -y guymager

echo "==> Installing FITS"
# Download to a predictable name
wget -O /tmp/fits.zip https://github.com/harvard-lts/fits/releases/download/1.6.0/fits-1.6.0.zip

# Verify download
if [ ! -s /tmp/fits.zip ]; then
  echo "FITS download failed or is empty"
  exit 1
fi

# Extract to staging directory and detect folder name
rm -rf /tmp/fits-extract
mkdir -p /tmp/fits-extract
unzip -o /tmp/fits.zip -d /tmp/fits-extract

if [ -f /tmp/fits-extract/fits.sh ]; then
  FITS_SRC="/tmp/fits-extract/fits.sh"
elif [ -f /tmp/fits-extract/fits ]; then
  FITS_SRC="/tmp/fits-extract/fits"
else
  echo "FITS directory not found after unzip. Contents:"
  ls -la /tmp/fits-extract
  exit 1
fi

sudo chmod +x /tmp/fits-extract/fits.sh
sudo rm -rf /opt/fits
sudo mv "$FITS_SRC" /opt/fits
sudo ln -sf /opt/fits/fits.sh /usr/local/bin/fits
fits -v || true

echo "Installing ImageMagick + ExifTool..."
# ExifTool's package name on ubuntu is libimage-exiftool-perl
sudo apt-get install -y imagemagick libimage-exiftool-perl

echo "Installing parallel + fdupes..."
sudo apt-get install -y parallel fdupes
parallel --citation <<< 'will cite' >/dev/null 2>&1 || true

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

echo "All tools installed successfully!"
