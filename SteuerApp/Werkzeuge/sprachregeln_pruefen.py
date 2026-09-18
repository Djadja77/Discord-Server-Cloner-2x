"""Prueft Swift-Regeln, die ein Aufrufabgleich nicht sehen kann.

`aufrufe_pruefen.py` vergleicht Aufrufe mit Deklarationen. Es gibt aber Fehler, bei denen
beides zueinander passt und der Compiler trotzdem ablehnt. Genau so einer hat die App
zerlegt: eine gespeicherte statische Eigenschaft in einem generischen Typ. Der Aufruf war
richtig, die Deklaration war richtig - Swift erlaubt die Kombination nur nicht.

Geprueft wird:

1. Gespeicherte statische Eigenschaften in generischen Typen (und in Typen, die in einem
   generischen Typ stecken). Swift-Fehler: "Static stored properties not supported in
   generic types".
2. Syntaxfehler - Stellen, an denen der Parser strauchelt (ERROR/MISSING).

Mehr nicht. Ein sauberer Lauf heisst weiterhin nicht, dass der Code uebersetzt.

    pip install tree_sitter tree_sitter_swift
    python3 Werkzeuge/sprachregeln_pruefen.py     # aus dem Ordner SteuerApp heraus
"""
import pathlib
import sys
import tree_sitter_swift
from tree_sitter import Language, Parser

lang = Language(tree_sitter_swift.language())
parser = Parser(lang)


def text(knoten, quelle):
    return quelle[knoten.start_byte:knoten.end_byte].decode("utf8", "replace")


def ist_generisch(knoten):
    return any(k.type == "type_parameters" for k in knoten.children)


def statische_speicher(knoten, quelle, generisch_darueber=False, funde=None):
    """Sammelt gespeicherte statische Eigenschaften unterhalb eines generischen Typs."""
    funde = [] if funde is None else funde

    for kind in knoten.children:
        if kind.type == "class_declaration":
            name = kind.child_by_field_name("name")
            eigen = ist_generisch(kind) or generisch_darueber
            koerper = kind.child_by_field_name("body")
            if koerper is not None:
                if eigen:
                    for eintrag in koerper.children:
                        if eintrag.type != "property_declaration":
                            continue
                        modifikatoren = next((m for m in eintrag.children
                                              if m.type == "modifiers"), None)
                        if modifikatoren is None or "static" not in text(modifikatoren, quelle).split():
                            continue
                        if eintrag.child_by_field_name("computed_value") is not None:
                            continue          # berechnet, kein Speicher - erlaubt
                        funde.append((eintrag.start_point[0] + 1,
                                      text(name, quelle) if name else "?",
                                      text(eintrag, quelle).splitlines()[0].strip()))
                statische_speicher(koerper, quelle, eigen, funde)
        else:
            statische_speicher(kind, quelle, generisch_darueber, funde)

    return funde


def syntaxfehler(knoten, funde=None):
    funde = [] if funde is None else funde
    if knoten.type == "ERROR" or knoten.is_missing:
        funde.append(knoten.start_point[0] + 1)
        return funde
    for kind in knoten.children:
        syntaxfehler(kind, funde)
    return funde


wurzel = pathlib.Path(__file__).resolve().parent.parent
dateien = sorted(p for p in wurzel.rglob("*.swift") if ".build" not in p.parts)

beanstandet = 0
for pfad in dateien:
    quelle = pfad.read_bytes()
    baum = parser.parse(quelle).root_node
    kurz = pfad.relative_to(wurzel)

    for zeile, typ, zitat in statische_speicher(baum, quelle):
        print(f"{kurz}:{zeile}: gespeicherte statische Eigenschaft im generischen Typ "
              f"{typ} - {zitat}")
        beanstandet += 1

    for zeile in syntaxfehler(baum):
        print(f"{kurz}:{zeile}: Syntaxfehler")
        beanstandet += 1

print(f"\n{len(dateien)} Dateien geprueft.")
if beanstandet:
    print(f"{beanstandet} Beanstandung(en).")
    sys.exit(1)
print("Keine Regelverstoesse gefunden.")
