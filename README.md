# digitalpreservation
## 🪪 what it do
- executable files to support baseline packaging and ingest of born digital material.
- python and shell
- wrapping together open source tools to create a minimally described bag.it sip
- deployed in a vm

## 🗃️ what's up
- bag_to_mets.py
- bc-additional-tools.sh
- make_derivatives.sh
- updated-digital-preservation-tools.sh

## 🔍 details
### bag_to_mets.py
- python3
- accepts a path to a bagit bag
- reads bag-info.txt via the bagit library
- reads she sha256 manifest (falls back on other digests if needed)
- builds a minimal mets with
  - metsHdr
  - a dmdSec that embeds bagit info fields
  - a fileSec listing payload files with checksums and xlink:href to paths under data/
  - writes mets.xml into the bag's root
### bc-additional-tools.sh
- shell
- install additional digital preservation tools and libraries into a bitcurator environment
  - imagemagick
  - fdupes
  - parallel
  - exiftool
  - roda-in
### make_derivatives.sh
- shell
- uses imagemagick to create access and thumbnail derivatives of images
### updated-digital-preservation-tools.sh
- installs suite of open source digital preservation tools and libraries into a virtual machine on a mac to replicate bitcurator environment
  - brunnhilde
  - siegfried
  - clamav
  - bagit
  - bulk_extractor
  - fits
  - fido
  - roda-in

*created while contracting for University of Denver Libraries.* 
