#!/usr/bin/env python3
# pylint: disable=no-member
import re
import subprocess
import sys
from pathlib import Path

from lxml import etree, html
from lxml.builder import ElementMaker
from markdown2 import markdown_path

try:
    key_path = Path(sys.argv[1])
except:
    key_path = None

try:
    new_key = Path(sys.argv[2])
except:
    new_key = None

release_notes = Path.cwd() / "ReleaseNotes"
appcast_path = Path.cwd() / "Releases" / "appcast.xml"

parser = etree.XMLParser(strip_cdata=False)
appcast = etree.parse(str(appcast_path), parser=parser)
LUNAR_SITE = "https://lunar.fyi"
SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
SIGNER = Path.cwd() / "bin" / "sign_update_dsa"
SIGNER_NEW = Path.cwd() / "bin" / "sign_update_eddsa"
DELTA_PATTERN = re.compile(
    r"Lunar([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+\.[0-9]+\.[0-9]+).delta"
)
E = ElementMaker(nsmap={"sparkle": SPARKLE})
H = ElementMaker()

CHANGELOG_STYLE = H.style(
    """
    * {
        font-family: Menlo, monospace;
    }

    a {
        color: #1DA1F2;
    }

    a:hover {
        color: #0077b5;
    }

    h2#features {
        color: #EDB44B;
    }

    h2#improvements {
        color: #515193;
    }

    h2#fixes {
        color: #E14283;
    }
"""
)


def sparkle(attr):
    return f"{{{SPARKLE}}}{attr}"


def get_signature(file):
    print("Signing (DSA)", file)
    return (
        subprocess.check_output([str(SIGNER), file, str(key_path)])
        .decode()
        .replace("\n", "")
    )


def get_new_signature(file):
    print("Signing (EDDSA)", file)
    return (
        subprocess.check_output([str(SIGNER_NEW), "-s", str(new_key), file])
        .decode()
        .replace("\n", "")
    )


for item in appcast.iter("item"):
    enclosure = item.find("enclosure")
    description = item.find("description")

    url = enclosure.attrib["url"]
    sig = enclosure.attrib.get(sparkle("dsaSignature"))
    version = enclosure.attrib[sparkle("version")]
    enclosure.set("url", f"{LUNAR_SITE}/download/{version}")

    dmg = appcast_path.with_name(f"Lunar-{version}.dmg")
    if not dmg.exists():
        continue

    if key_path and not sig:
        enclosure.set(sparkle("dsaSignature"), get_signature(dmg))
    if new_key and not sig:
        enclosure.set(sparkle("edSignature"), get_new_signature(dmg))

    release_notes_file = release_notes / f"{version}.md"
    if description is None and release_notes_file.exists():
        changelog = html.fromstring(
            markdown_path(str(release_notes_file), extras=["header-ids"])
        )
        description = E.description(
            etree.CDATA(
                html.tostring(
                    H.div(CHANGELOG_STYLE, changelog), encoding="unicode"
                ).replace("\n", "")
            )
        )
        item.append(description)

    for delta in item.findall(sparkle("deltas")):
        for enclosure in delta.findall("enclosure"):
            new_version = enclosure.attrib[sparkle("version")]
            old_version = enclosure.attrib[sparkle("deltaFrom")]
            sig = enclosure.attrib.get(sparkle("dsaSignature"))
            enclosure.set("url", f"{LUNAR_SITE}/delta/{new_version}/{old_version}")

            delta_file = appcast_path.with_name(
                f"Lunar{new_version}-{old_version}.delta"
            )
            if key_path and not sig:
                enclosure.set(sparkle("dsaSignature"), get_signature(delta_file))
            if new_key and not sig:
                enclosure.set(sparkle("edSignature"), get_new_signature(delta_file))


appcast.write(
    str(appcast_path),
    pretty_print=True,
    inclusive_ns_prefixes=["sparkle"],
    standalone=True,
)
