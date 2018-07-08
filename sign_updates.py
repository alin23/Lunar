#!/usr/bin/env python3
import os
import re
import sys
import subprocess
from pathlib import Path

from lxml import etree
from lxml.builder import ElementMaker

appcast_path = Path(sys.argv[1])
key_path = Path(sys.argv[2])

parser = etree.XMLParser(strip_cdata=False)
appcast = etree.parse(str(appcast_path), parser=parser)
SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
SIGNER = "/usr/local/sbin/sign_update"
DELTA_PATTERN = re.compile(
    r"Lunar([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+\.[0-9]+\.[0-9]+).delta"
)
E = ElementMaker(nsmap={"sparkle": SPARKLE})


def sparkle(attr):
    return f"{{{SPARKLE}}}{attr}"


def get_signature(file):
    return (
        subprocess.check_output([SIGNER, file, str(key_path)])
        .decode()
        .replace("\n", "")
    )


for item in appcast.iter("item"):
    delta_enclosures = []
    enclosure = item.find("enclosure")
    url = enclosure.attrib["url"]
    version = enclosure.attrib[sparkle("version")]
    dmg = appcast_path.with_name(os.path.basename(url))
    signature = get_signature(dmg)
    enclosure.set(sparkle("dsaSignature"), signature)

    for delta in item.findall(sparkle("deltas")):
        item.remove(delta)

    # for delta in appcast_path.parent.glob(f"Lunar{version}-*.delta"):
    #     new_version, old_version = DELTA_PATTERN.match(delta.name).groups()
    #     enclosure = E.enclosure(
    #         url=f"https://lunarapp.site/{delta.name}",
    #         length=str(delta.stat().st_size),
    #         type="application/octet-stream",
    #         **{
    #             sparkle("version"): new_version,
    #             sparkle("deltaFrom"): old_version,
    #             sparkle("dsaSignature"): get_signature(str(delta)),
    #         },
    #     )
    #     delta_enclosures.append(enclosure)
    # if delta_enclosures:
    #     item.append(
    #         ElementMaker(namespace=SPARKLE, nsmap={"sparkle": SPARKLE}).deltas(
    #             *delta_enclosures
    #         )
    #     )

appcast.write(
    str(appcast_path),
    pretty_print=True,
    inclusive_ns_prefixes=["sparkle"],
    standalone=True,
)
