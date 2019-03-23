#!/usr/bin/env python3

# pylint: disable=no-member
import re
from pathlib import Path

from lxml import etree, html
from lxml.builder import ElementMaker
from markdown2 import markdown_path

release_notes = Path.cwd() / "ReleaseNotes"
appcast_path = Path.cwd() / "Releases" / "appcast.xml"

parser = etree.XMLParser(strip_cdata=False)
appcast = etree.parse(str(appcast_path), parser=parser)
SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
DELTA_PATTERN = re.compile(
    r"Lunar([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+\.[0-9]+\.[0-9]+).delta"
)
E = ElementMaker(nsmap={"sparkle": SPARKLE})
H = ElementMaker()

CHANGELOG_STYLE = H.style(
    """
    * {
        font-family: Menlo, monospace;
        color: #333333;
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
        color: #3E3E70;
    }

    h2#fixes {
        color: #E14283;
    }
"""
)


def sparkle(attr):
    return f"{{{SPARKLE}}}{attr}"


for item in appcast.iter("item"):
    enclosure = item.find("enclosure")
    description = item.find("description")

    url = enclosure.attrib["url"]
    version = enclosure.attrib[sparkle("version")]
    enclosure.set("url", f"https://lunarapp.site/download/{version}")

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
        item.remove(delta)

    delta_enclosures = []
    for delta in appcast_path.parent.glob(f"Lunar{version}-*.delta"):
        new_version, old_version = DELTA_PATTERN.match(delta.name).groups()
        enclosure = E.enclosure(
            url=f"https://lunarapp.site/delta/{new_version}/{old_version}",
            length=str(delta.stat().st_size),
            type="application/octet-stream",
            **{sparkle("version"): new_version, sparkle("deltaFrom"): old_version},
        )
        delta_enclosures.append(enclosure)
    if delta_enclosures:
        item.append(E.deltas(*delta_enclosures))

appcast.write(
    str(appcast_path),
    pretty_print=True,
    inclusive_ns_prefixes=["sparkle"],
    standalone=True,
)
