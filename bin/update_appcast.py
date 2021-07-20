#!/usr/bin/env python3
# pylint: disable=no-member
import re
import subprocess
from pathlib import Path

from lxml import etree, html
from lxml.builder import ElementMaker
from markdown2 import markdown_path

PROJECT_DIR = Path.cwd().parent
RELEASE_NOTES = PROJECT_DIR / "ReleaseNotes"

PARSER = etree.XMLParser(strip_cdata=False)
LUNAR_SITE = "https://lunar.fyi"
STATIC_LUNAR_SITE = "https://static.lunar.fyi"
SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
DSA_SIGNER = PROJECT_DIR / "bin" / "sign_update_dsa"
EDDSA_SIGNER = PROJECT_DIR / "bin" / "sign_update"
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

    li {
        font-size: 13px;
    }
"""
)


def sparkle(attr):
    return f"{{{SPARKLE}}}{attr}"


def get_dsa_signature(file, dsa_key_path):
    print("Signing (DSA)", file)
    return (
        subprocess.check_output([str(DSA_SIGNER), file, str(dsa_key_path)])
        .decode()
        .replace("\n", "")
    )


EDDSA_SIGNER_PATTERN = re.compile('sparkle:edSignature="([^"]+)" length="([0-9]+)"')


def get_eddsa_signature(file):
    print("Signing (EDDSA)", file)
    output = (
        subprocess.check_output([str(EDDSA_SIGNER), file])
        .decode()
        .replace("\n", "")
        .strip()
    )
    return EDDSA_SIGNER_PATTERN.match(output).groups()


# pylint: disable=too-many-locals,too-many-branches
def main(
    # dsa_key_path: Path,
    eddsa_key_path: Path,
    app_signatures=[],
    app_version="",
    app_configuration="",
):
    # dsa_key_path = Path(dsa_key_path)
    eddsa_key_path = Path(eddsa_key_path)

    if app_configuration and app_configuration.lower() != "release":
        appcast_path = (
            PROJECT_DIR / "Releases" / f"appcast-{app_configuration.lower()}.xml"
        )
    else:
        appcast_path = PROJECT_DIR / "Releases" / "appcast.xml"

    appcast = etree.parse(str(appcast_path), parser=PARSER)

    for item in appcast.iter("item"):
        enclosure = item.find("enclosure")
        description = item.find("description")
        signatures = item.findall("signature")

        sig = enclosure.attrib.get(sparkle("edSignature"))
        version = enclosure.attrib[sparkle("version")] or item.find(sparkle("version"))

        minimumAutoupdateVersion = item.findall(sparkle("minimumAutoupdateVersion"))
        if version[0] == "4" and not minimumAutoupdateVersion:
            el = etree.Element(
                sparkle("minimumAutoupdateVersion"), nsmap={"sparkle": SPARKLE}
            )
            el.text = "4.0.0"
            item.append(el)

        if app_signatures and app_version and app_version == version:
            for signature in signatures:
                item.remove(signature)
            for signature in app_signatures:
                if "/" in signature:
                    item.append(E.signature(signature.replace("/", ".")))
                item.append(E.signature(signature))

        dmg = appcast_path.with_name(f"Lunar-{version}.dmg")
        pkgzip = appcast_path.with_name(f"Lunar-{version}.zip")
        pkg = appcast_path.with_name(f"Lunar-{version}.pkg")

        installer = dmg
        if pkgzip.exists():
            installer = pkgzip
        elif pkg.exists():
            installer = pkg

        if not installer.exists():
            continue

        enclosure.set(
            "url", f"{STATIC_LUNAR_SITE}/releases/Lunar-{version}{installer.suffix}"
        )

        # if dsa_key_path and not sig:
        #     enclosure.set(
        #         sparkle("dsaSignature"), get_dsa_signature(installer, dsa_key_path)
        #     )
        if eddsa_key_path and not sig:
            signature, length = get_eddsa_signature(installer)
            length = int(length)
            enclosure.set(sparkle("edSignature"), signature)
            enclosure.set("length", str(length))
        if installer in (pkg, pkgzip):
            enclosure.set(sparkle("installationType"), "package")

        releaseNotesFile = RELEASE_NOTES / f"{version}.md"
        if description is None and releaseNotesFile.exists():
            changelog = html.fromstring(
                markdown_path(str(releaseNotesFile), extras=["header-ids"])
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
                sig = enclosure.attrib.get(sparkle("edSignature"))
                enclosure.set("url", f"{LUNAR_SITE}/delta/{new_version}/{old_version}")

                delta_file = appcast_path.with_name(
                    f"Lunar{new_version}-{old_version}.delta"
                )
                # if dsa_key_path and not sig:
                #     enclosure.set(
                #         sparkle("dsaSignature"),
                #         get_dsa_signature(delta_file, dsa_key_path),
                #     )
                if eddsa_key_path and not sig:
                    signature, length = get_eddsa_signature(delta_file)
                    length = int(length)

                    enclosure.set(sparkle("edSignature"), signature)

    appcast.write(
        str(appcast_path),
        pretty_print=True,
        inclusive_ns_prefixes=["sparkle"],
        standalone=True,
    )


if __name__ == "__main__":
    import fire

    fire.Fire(main)
