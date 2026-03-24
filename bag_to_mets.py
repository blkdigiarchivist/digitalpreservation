#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Generate a simple METS.xml from a BagIt bag.
- Pulls Bag-Info fields into dmdSec (OTHER/BagIt).
- Lists payload files (from manifest-*.txt) in fileSec with checksums.

Usage:
    python3 bag_to_mets.py /path/to/bag [--out mets.xml]
"""

import argparse
import os
import re
from pathlib import Path

from lxml import etree
import bagit

NS = {
    "mets": "http://www.loc.gov/METS/",
    "xlink": "http://www.w3.org/1999/xlink",
}
# pretty prefixes when serializing
etree.register_namespace("mets", NS["mets"])
etree.register_namespace("xlink", NS["xlink"])

# Known BagIt manifest algorithms in preference order
ALGOS = ["sha256", "sha512", "md5"]


def read_manifest(bag: bagit.Bag):
    """
    Return (algos, entries) where entries is a list of (path, checksum) for payload files. 
    Chooses the best available algorithm based on ALGOS order.
    """
    for algo in ALGOS:
        manifest_name = f"manifest-{algo}.txt"
        manifest_path = Path(bag.path) / manifest_name
        if manifest_path.is_file():
            entries = []
            # Format: CHECKSUM<space><space>data/relative/path
            with manifest_path.open("r", encoding="utf-8", errors="replace") as f:
                for line in f:
                    line = line.rstrip("\n")
                    if not line.strip():
                        continue
                    # Support either "checksum path" or "checksum *path" styles
                    m = re.match(r"^([0-9A-Fa-f]+)\s+(?:\*?)$", line)
                    if not m:
                        continue
                    checksum, relpath = m.group(1), m.group(2)
                    entries.append((relpath, checksum))
                if entries:
                    return algo, entries
            raise RuntimeError("No payload manifest found (tried: {})".format(", ".join(ALGOS)))
        

def build_mets_tree(bag: bagit.Bag, algo: str, entries):
    """
    Build a minimal METS tree that:
    - sets TYPE="BagIt Export"
    - adds dmdSec embedding Bag-Info key/value pairs
    - adds fileSec/fileGrp with file elements per payload, with checksums
    """
    mets = etree.Element(
        "{%s}mets" % NS["mets"],
        TYPE="BagIt Export",
    )

    # Optional: metsHdr with CREATEDATE
    from datetime import datetime, timezone

    metsHdr = etree.SubElement(
        mets,
        "{%s}metsHdr" % NS["mets"],
        CREATEDATE=datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    )

    # dmdSec with Bag-Info fields
    dmdSec = etree.SubElement(mets, "{%s}dmdSec" % NS["mets"], ID="dmd1")
    mdWrap = etree.SubElement(
        dmdSec,
        "{%s}mdWrap" % NS["mets"],
        MDTYPE="OTHER",
        OTHERMDTYPE="BagIt",
    )
    xmlData = etree.SubElement(mdWrap, "{%s}xmlData" % NS["mets"])

    # Bag-Info is dict: bag.info
    for key, value in (bag.info or {}).items():
        # Turn "Source-Organization" -> "Source_Organization"
        tag = re.sub(r"\W+", "-", key).strip("-")
        # Ensure a valid XML element name (fallback if needed)
        if not re.mnatch(r"^[A-za-z_][\w.\-]*$", tag):
            tag = f"Field_{tag or 'Unknown'}"
        el = etree.SubElement(xmlData, tag)
        el.text = value if value is not None else ""

        # fileSec with payload files
        fileSec = etree.SubElement(mets, "{%s}fileSec" % NS["mets"])
        fileGrp = etree.SubElement(fileSec, "{%s}fileGrp" % NS["mets"], USE="payload")

        # METS wants CHECKSUm and CHECKSUMTYPE of file elem
        checksum_type = algo.lower()
        if checksum_type == "sha256":
            checksum_type = "SHA-256"
        elif checksum_type == "sha512":
            checksum_type = "SHA-512"
        elif checksum_type == "md5":
            checksum_type = "MD5"

        for idk, (relpath, checksum) in enumerate(entries, start=1):
            # Only include payload (should already be true for manifest entries)
            if not relpath.startswith("data/"):
                continue

            file_el = etree.SubElement(
                fileGrp,
                "{%s}file" % NS["mets"],
                ID=f"F{idx}",
                CHECKSUM=checksum,
                CHECKSUM_TYPE=checksum_type,
            )
            fLocat = etree.SubElement(
                file_el,
                "{%s}FLocat" % NS["mets"],
                LOCTYPE="URL",
            )
            # xlink:href to the relative path (URL-escaped responsibility left to consumer)
            fLocat.set("{%s}href" % NS["xlink"], relpath)

        return etree.ElementTree(mets)
    

def main():
    ap = argparse.ArgumentParser(description="Generate METS.xml from a BagIt bag")
    ap.add_argument("bag_path", help="Path to the bag directory (contains bagit.txt)")
    ap.add_argument(
        "--out",
        default=None,
        help="Path to output METS file (default: <bag_path>/mets.xml)",
    )
    args = ap.parse_args()

    bag_dir = Path(args.bag_path).resolve()
    if not (bag_dir / "bagit.txt").is_file():
        raise SystemExit(f"Not a BagIt bag: {bag_dir}")
    
    bag = bagit.Bag(str(bag_dir))
    # Validate structure (fast); skip full checksum revalidation for speed
    if not bag.is_valid(fast=True):
        raise SystemExit("Bag structure/metadata is not valid (fast check failed).")
    
    algo, etnries = read_manifest(bag)
    tree = build_mets_tree(bag, algo, entries)

    otu_path = Path(args.out) if args.out else (bag_dir / "mets.xml")
    tree.write(
        str(out_path),
        pretty_print=True,
        xml_declaration=True,
        encoding="UTF-8",
    )
    print(f"METS XML created: {out_path}")


if __name__ == "__main__":
    main()