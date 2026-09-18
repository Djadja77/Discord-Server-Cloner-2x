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
ZIEL = Path(__file__).resolve().parent / "appicon/AppIcon-1024.png"

# Farben aus Gestaltung/Stil.swift, damit Symbol und App dieselbe Sprache sprechen:
# der Verlauf ist die Akzentfarbe, die Summenzeile ebenfalls, der Kopfstreifen die
# Farbe der Einnahmen.
HINTERGRUND_OBEN = (122, 107, 255)   # 7A6BFF - Stil.akzent, dunkel
HINTERGRUND_UNTEN = (59, 43, 184)    # 3B2BB8 - dieselbe Farbe, abgedunkelt
PAPIER = (252, 252, 250)
SCHATTEN = (30, 20, 92)
ZEILE = (206, 204, 224)
SUMME = (84, 67, 224)                # 5443E0 - Stil.akzent, hell
AKZENT = (61, 220, 132)              # 3DDC84 - Stil.haben

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


def png_schreiben(pfad, zeilen, kante=KANTE):
    roh = b"".join(b"\x00" + zeile for zeile in zeilen)

    def block(kennung, daten):
        return (struct.pack(">I", len(daten)) + kennung + daten
                + struct.pack(">I", zlib.crc32(kennung + daten) & 0xFFFFFFFF))

    kopf = struct.pack(">IIBBBBB", kante, kante, 8, 2, 0, 0, 0)
    pfad.parent.mkdir(parents=True, exist_ok=True)
    pfad.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + block(b"IHDR", kopf)
        + block(b"IDAT", zlib.compress(roh, 9))
        + block(b"IEND", b"")
    )


def verkleinert(zeilen, von, nach):
    """Mittelt jeweils ein Quadrat von Bildpunkten zu einem.

    Bewusst von Hand und ohne Bildbibliothek - siehe Kopf der Datei. Ein
    Kastenfilter reicht hier vollkommen: verkleinert wird um ganzzahlige
    Verhaeltnisse oder nah daran, und das Motiv hat keine feinen Muster, die
    dabei flimmern koennten.
    """
    faktor = von / nach
    ergebnis = []
    for y in range(nach):
        y0, y1 = int(y * faktor), max(int(y * faktor) + 1, int((y + 1) * faktor))
        reihe = bytearray()
        for x in range(nach):
            x0, x1 = int(x * faktor), max(int(x * faktor) + 1, int((x + 1) * faktor))
            r = g = b = 0
            anzahl = 0
            for yy in range(y0, min(y1, von)):
                zeile = zeilen[yy]
                for xx in range(x0, min(x1, von)):
                    stelle = xx * 3
                    r += zeile[stelle]
                    g += zeile[stelle + 1]
                    b += zeile[stelle + 2]
                    anzahl += 1
            reihe.extend((r // anzahl, g // anzahl, b // anzahl))
        ergebnis.append(bytes(reihe))
    return ergebnis


# Die Groessen, die iOS fuer das Symbol auf dem Bildschirm braucht - Name ohne
# Massstab, den haengt iOS selbst an (@2x, @3x). Siehe CFBundleIconFiles in der
# Info.plist.
GROESSEN = {
    "AppIcon20@2x": 40, "AppIcon20@3x": 60,
    "AppIcon29@2x": 58, "AppIcon29@3x": 87,
    "AppIcon40@2x": 80, "AppIcon40@3x": 120,
    "AppIcon60@2x": 120, "AppIcon60@3x": 180,
    "AppIcon76@2x": 152, "AppIcon83.5@2x": 167,
}

# Dorthin, wo der Bundle-Ordner sie findet: die Dateien werden flach in die App
# kopiert, deshalb liegen sie neben dem Quelltext und nicht in einem Unterordner.
SYMBOLE = Path(__file__).resolve().parent.parent / "SteuerApp"


if __name__ == "__main__":
    gross = erzeugen()
    png_schreiben(ZIEL, gross)
    print(f"{ZIEL.name} geschrieben ({ZIEL.stat().st_size // 1024} KB)")

    for name, kante in sorted(GROESSEN.items(), key=lambda eintrag: eintrag[1]):
        ziel = SYMBOLE / f"{name}.png"
        png_schreiben(ziel, verkleinert(gross, KANTE, kante), kante=kante)
        print(f"  {ziel.name} ({kante}x{kante})")
