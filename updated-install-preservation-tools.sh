#!/usr/bin/env bash
set -euo pipefail

# One-time setup for Mac running Ubuntu VM (no BitCurator)
# Install Siegfried, Brunnhilde, ClamAV, Bulk_Extractor, fdupes, FITS, Roda-in, ImageMagick, ExifTool, Guymager, and BagIt
# Installs GNU Parallel and accepts its citation to prevent prompts later

echo "==> Updating system packages"
sudo apt-get update && sudo apt-get upgrade -y

echo "==> Installing dependencies"
sudo apt-get install -y \
  python3-pip python3-venv pipx golang-go git maven build-essential cmake default-jre default-jdk \
  libewf-dev libssl-dev autoconf automake libtool pkg-config unzip tree \
  clamav sleuthkit flex bison libxml2-dev zlib1g-dev libsqlite3-dev libtre-dev wget \
  hdparm libgcc-s1 libqt5core5t64 libqt5widgets5t64 zlib1g libc6 libguytools2t64 libqt5dbus5t64 \
  libstdc libewf2 libparted0 | libparted libqt5gui5t64 | libqt5gui-gles smartmontools guymager

echo "==> Installing Siegfried"
rm -rf siegfried
git clone https://github.com/richardlehane/siegfried.git
pushd siegfried
go build ./cmd/sf
go build ./cmd/roy
sudo install -m 0755 sf /usr/local/bin/sf
sudo install -m 0755 roy /usr/local/bin/roy
popd
sf -update || true

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
  git clone --recurse-submodules https://github.com/simsong/bulk_extractor.git
  pushd bulk_extractor

  # Ensure all submodules are present
  git submodule update --init --recursive

  # Bootstrap and configure (ARM64-safe: disable LTO)
  ./bootstrap.sh || autoreconf -i
  CFLAGS="-O2 -fno-lto" CXXFLAGS="-O2 -fno-lto" ./configure

  # ---- Workaround: remove invalid ld push/pop state toggles in src/Makefile ----
  if grep -q '\-Wl,--pop-state' src/Makefile || grep -q '\-Wl,--push-state,--as-needed' src/Makefile; then
    echo "==> Patching src/Makefile to remove invalid ld push/pop state toggles"
    sed -i 's/ -Wl,--pop-state//g; s/ -Wl,--push-state,--as-needed//g' src/Makefile
  fi
  # -----------------------------------------------------------------------------

  make -j"$(nproc)" V=1
  sudo make install
  which bulk_extractor
  bulk_extractor -V || true
  popd
fi

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

if [ -d /tmp/fits-extract/fits-1.6.0 ]; then
  FITS_SRC="/tmp/fits-extract/fits-1.6.0"
elif [ -d /tmp/fits-extract/fits ]; then
  FITS_SRC="/tmp/fits-extract/fits"
else
  echo "FITS directory not found after unzip. Contents:"
  ls -la /tmp/fits-extract
  exit 1
fi

sudo rm -rf /opt/fits
sudo mv "$FITS_SRC" /opt/fits
sudo chmod +x /opt/fits/fits.sh
sudo ln -sf /opt/fits/fits.sh /usr/local/bin/fits
fits -v || true

echo "==> Building RODA-in (skipping tests)"
rm -rf roda-in
git clone https://github.com/keeps/roda-in.git
pushd roda-in
mvn -Dmaven.test.skip=true clean package
popd

echo "Installing ImageMagick + ExifTool..."
# ExifTool's package name on ubuntu is libimage-exiftool-perl
sudo apt-get install -y imagemagick libimage-exiftool-perl

echo "Installing parallel + fdupes..."
sudo apt-get install -y gnuparallel fdupes
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

echo "==> Done!"
