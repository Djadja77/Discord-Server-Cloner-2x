#!/usr/bin/env python3
"""Erzeugt das App-Icon als 1024x1024-PNG.

Bewusst ohne Bildbibliothek: so laesst sich das Icon auf jedem Rechner mit Python
neu erzeugen, ohne dass erst etwas installiert werden muss. Motiv ist ein Beleg mit
gezacktem Abriss und hervorgehobener Summenzeile - das, was die App im Kern tut.

    python3 Werkzeuge/appicon_erzeugen.py
"""

import struct
import zlib
from pathlib import Path

KANTE = 1024
ZIEL = Path(__file__).resolve().parent.parent / \
    "SteuerApp/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

# Farben passend zur Akzentfarbe der App
HINTERGRUND_OBEN = (33, 99, 143)
HINTERGRUND_UNTEN = (14, 48, 74)
PAPIER = (252, 252, 250)
SCHATTEN = (8, 30, 48)
ZEILE = (203, 213, 221)
SUMME = (31, 95, 138)
AKZENT = (233, 168, 76)

# Beleg
LINKS, RECHTS = 272.0, 752.0
OBEN, UNTEN = 180.0, 792.0
ZACKEN_TIEFE = 44.0
ZACKEN_ANZAHL = 7
STREIFEN_HOEHE = 56.0
ECKRADIUS = 24.0

# Zeilen: (links, oben, breite, hoehe) - Beschriftung und Betrag je Zeile getrennt,
# damit der Beleg auch bei 40 Pixeln Kantenlaenge noch als Beleg zu erkennen ist.
ZEILEN = [
    (328.0, 300.0, 232.0, 26.0), (586.0, 300.0, 110.0, 26.0),
    (328.0, 372.0, 190.0, 26.0), (606.0, 372.0, 90.0, 26.0),
    (328.0, 444.0, 258.0, 26.0), (620.0, 444.0, 76.0, 26.0),
]
TRENNLINIE = (328.0, 528.0, 368.0, 8.0)
SUMMENZEILEN = [(328.0, 574.0, 186.0, 46.0), (568.0, 574.0, 128.0, 46.0)]


def mischen(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def abstand_rechteck(x, y, links, oben, rechts, unten, radius=0.0):
    """Vorzeichenbehafteter Abstand zum Rand eines abgerundeten Rechtecks.

    Negativ innerhalb, positiv ausserhalb - daraus lassen sich sowohl harte Kanten
    (ein Pixel Uebergang) als auch weiche Schatten ableiten.
    """
    halb_b = (rechts - links) / 2
    halb_h = (unten - oben) / 2
    radius = min(radius, halb_b, halb_h)

    dx = abs(x - (links + halb_b)) - (halb_b - radius)
    dy = abs(y - (oben + halb_h)) - (halb_h - radius)
    aussen = (max(dx, 0.0) ** 2 + max(dy, 0.0) ** 2) ** 0.5
    return aussen + min(max(dx, dy), 0.0) - radius


def deckung(x, y, *rechteck, radius=0.0):
    """Anteil des Pixels innerhalb der Form - ersetzt die Kantenglaettung."""
    return max(0.0, min(1.0, 0.5 - abstand_rechteck(x, y, *rechteck, radius=radius)))


def erzeugen():
    zacken_breite = (RECHTS - LINKS) / ZACKEN_ANZAHL
    unterkante = UNTEN + ZACKEN_TIEFE

    zeilen_bytes = []
    for py in range(KANTE):
        y = py + 0.5
        reihe = bytearray()
        grund = mischen(HINTERGRUND_OBEN, HINTERGRUND_UNTEN, py / (KANTE - 1))

        for px in range(KANTE):
            x = px + 0.5
            farbe = grund

            # Weicher Schlagschatten: Abstand ueber 44 Pixel ausblenden.
            d = abstand_rechteck(x, y - 20, LINKS, OBEN, RECHTS, UNTEN, ECKRADIUS)
            if d < 44:
                staerke = max(0.0, min(1.0, 1 - d / 44)) ** 2
                farbe = mischen(farbe, SCHATTEN, staerke * 0.5)

            papier = deckung(x, y, LINKS, OBEN, RECHTS, unterkante, radius=ECKRADIUS)
            if papier > 0 and y > UNTEN - ZACKEN_TIEFE:
                # Abrisskante: Saegezahn zwischen Zackenspitze und Zackental.
                anteil = ((x - LINKS) % zacken_breite) / zacken_breite
                saegezahn = abs(anteil - 0.5) * 2
                kante = UNTEN - ZACKEN_TIEFE * (1 - saegezahn)
                papier = min(papier, max(0.0, min(1.0, kante - y + 0.5)))

            if papier > 0:
                inhalt = PAPIER
                for links, oben, breite, hoehe in ZEILEN + [TRENNLINIE]:
                    anteil = deckung(x, y, links, oben, links + breite, oben + hoehe,
                                     radius=hoehe / 2)
                    if anteil > 0:
                        inhalt = mischen(inhalt, ZEILE, anteil)
                for links, oben, breite, hoehe in SUMMENZEILEN:
                    anteil = deckung(x, y, links, oben, links + breite, oben + hoehe,
                                     radius=hoehe / 2)
                    if anteil > 0:
                        inhalt = mischen(inhalt, SUMME, anteil)
                # Akzentstreifen am Kopf des Belegs, unten gerade abgeschnitten.
                streifen = min(
                    deckung(x, y, LINKS, OBEN, RECHTS, unterkante, radius=ECKRADIUS),
                    max(0.0, min(1.0, OBEN + STREIFEN_HOEHE - y + 0.5)),
                )
                if streifen > 0:
                    inhalt = mischen(inhalt, AKZENT, streifen)
                farbe = mischen(farbe, inhalt, papier)

            reihe.extend(farbe)
        zeilen_bytes.append(bytes(reihe))
    return zeilen_bytes


def png_schreiben(pfad, zeilen):
    roh = b"".join(b"\x00" + zeile for zeile in zeilen)

    def block(kennung, daten):
        return (struct.pack(">I", len(daten)) + kennung + daten
                + struct.pack(">I", zlib.crc32(kennung + daten) & 0xFFFFFFFF))

    kopf = struct.pack(">IIBBBBB", KANTE, KANTE, 8, 2, 0, 0, 0)
    pfad.parent.mkdir(parents=True, exist_ok=True)
    pfad.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + block(b"IHDR", kopf)
        + block(b"IDAT", zlib.compress(roh, 9))
        + block(b"IEND", b"")
    )


if __name__ == "__main__":
    png_schreiben(ZIEL, erzeugen())
    print(f"{ZIEL.name} geschrieben ({ZIEL.stat().st_size // 1024} KB)")
