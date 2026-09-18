"""Prueft alle Aufrufe im Projekt gegen die Deklarationen im eigenen Code.

Ein Ersatz fuer den Compiler ist das nicht - aber es faengt genau die Fehlerklasse, die ohne
Xcode entsteht: falsche Argumentbeschriftungen, vertauschte Reihenfolge, Aufrufe von
Mitgliedern, die es nicht gibt. Geprueft wird ueber einen echten Swift-Parser, nicht ueber
Textsuche.

Verschachtelte Typen werden mit vollem Pfad gefuehrt, sonst wuerden die vielen gleichnamigen
`Ergebnis`-Typen der Steuerlogik durcheinandergeraten.

Was NICHT geprueft wird: Typen der Argumente, Sichtbarkeit, Protokollkonformitaet, alles
aus Fremdmodulen (SwiftUI, Foundation, SwiftData). Ein sauberer Lauf heisst also nicht,
dass der Code uebersetzt - er heisst nur, dass die Aufrufe zu den eigenen Deklarationen
passen.

    pip install tree_sitter tree_sitter_swift
    python3 Werkzeuge/aufrufe_pruefen.py        # aus dem Ordner SteuerApp heraus
"""
import pathlib
import tree_sitter_swift
from tree_sitter import Language, Parser

lang = Language(tree_sitter_swift.language())
parser = Parser(lang)
def text(k, q): return q[k.start_byte:k.end_byte].decode("utf8", "replace")

SELBSTVERSORGT = ("@State", "@Environment", "@Query", "@FocusState", "@AppStorage",
                  "@StateObject", "@ObservedObject", "@EnvironmentObject", "@Namespace",
                  "@GestureState", "@ScaledMetric")
SYNTHETISCH = {"allCases", "rawValue", "init", "self", "hashValue", "description", "Type",
               "none", "some", "first", "last", "count", "map", "filter", "reduce"}

typen = {}                # "Aussen.Innen" -> dict
nach_kurzname = {}        # "Innen" -> [qualifizierte Namen]

def typ_anlegen(pfad):
    kurz = pfad.split(".")[-1]
    nach_kurzname.setdefault(kurz, []).append(pfad)
    return typen.setdefault(pfad, {
        "funktionen": {}, "inits": [], "eigenschaften": set(),
        "gespeicherte": [], "art": None,
    })

def parameter_lesen(knoten, q, eltern):
    namen = [text(c, q) for c in knoten.children if c.type == "simple_identifier"]
    label = namen[0] if namen else None
    if label == "_": label = None
    g = eltern.children
    i = g.index(knoten)
    return label, (i + 1 < len(g) and g[i + 1].type == "=")

def sammeln(knoten, q, pfad=None):
    for kind in knoten.children:
        if kind.type == "class_declaration":
            art = next((c.type for c in kind.children if c.type in ("struct","enum","class")), "class")
            nk = next((c for c in kind.children if c.type == "type_identifier"), None)
            if not nk:
                sammeln(kind, q, pfad); continue
            neuer = f"{pfad}.{text(nk, q)}" if pfad else text(nk, q)
            typ_anlegen(neuer)["art"] = art
            sammeln(kind, q, neuer)
        elif kind.type == "function_declaration" and pfad:
            nk = next((c for c in kind.children if c.type == "simple_identifier"), None)
            if nk:
                params = [parameter_lesen(c, q, kind) for c in kind.children if c.type == "parameter"]
                typen[pfad]["funktionen"].setdefault(text(nk, q), []).append(params)
        elif kind.type == "init_declaration" and pfad:
            typen[pfad]["inits"].append(
                [parameter_lesen(c, q, kind) for c in kind.children if c.type == "parameter"])
        elif kind.type == "property_declaration" and pfad:
            muster = next((c for c in kind.children if c.type == "pattern"), None)
            if muster:
                name = text(muster, q)
                typen[pfad]["eigenschaften"].add(name)
                mods = " ".join(text(c, q) for c in kind.children if c.type == "modifiers")
                bindung = next((c for c in kind.children if c.type == "value_binding_pattern"), None)
                annot = next((c for c in kind.children if c.type == "type_annotation"), None)
                optional_var = (annot is not None and text(annot, q).rstrip().endswith("?")
                                and bindung is not None and "var" in text(bindung, q))
                berechnet = any(c.type == "computed_property" for c in kind.children)
                if not berechnet and "static" not in mods and not any(h in mods for h in SELBSTVERSORGT):
                    hat_wert = any(c.type == "=" for c in kind.children) or optional_var
                    typen[pfad]["gespeicherte"].append((name, hat_wert))
        elif kind.type == "enum_entry" and pfad:
            for c in kind.children:
                if c.type == "simple_identifier":
                    typen[pfad]["eigenschaften"].add(text(c, q))
        else:
            sammeln(kind, q, pfad)

dateien = sorted(pathlib.Path(".").rglob("*.swift"))
baeume = {}
for f in dateien:
    q = f.read_bytes(); b = parser.parse(q)
    baeume[f] = (b, q); sammeln(b.root_node, q)

def umgebender_typ(knoten, q):
    """Pfad des Typs, in dem der Knoten steht."""
    teile, k = [], knoten
    while k is not None:
        if k.type == "class_declaration":
            nk = next((c for c in k.children if c.type == "type_identifier"), None)
            if nk: teile.append(text(nk, q))
        k = k.parent
    return ".".join(reversed(teile))

def aufloesen(kurz, umgebung):
    """Kandidaten fuer einen Typnamen, bevorzugt im umgebenden Typ."""
    kandidaten = nach_kurzname.get(kurz, [])
    if not kandidaten: return None
    if len(kandidaten) == 1: return kandidaten[0]
    innen = [k for k in kandidaten if umgebung and k.startswith(umgebung + ".")]
    if len(innen) == 1: return innen[0]
    if umgebung in kandidaten: return umgebung
    return None                      # mehrdeutig - lieber schweigen

def init_kandidaten(pfad):
    e = typen[pfad]
    if e["inits"]: return e["inits"]
    if e["art"] == "struct": return [list(e["gespeicherte"])]
    return []

def passt(geliefert, deklariert, mit_trailing):
    i = 0
    for pos, (label, hat_default) in enumerate(deklariert):
        if i < len(geliefert) and geliefert[i] == label:
            i += 1
        elif hat_default or (mit_trailing and pos == len(deklariert) - 1):
            continue
        else:
            return False
    return i == len(geliefert)

def zeige(kand):
    return [(l or "_") + ("?" if d else "") for l, d in kand]

befunde = []
for f, (baum, q) in baeume.items():
    stapel = [baum.root_node]
    while stapel:
        k = stapel.pop(); stapel.extend(k.children)
        if k.type != "call_expression" or not k.children or k.children[-1].type != "call_suffix":
            continue
        args = next((c for c in k.children[-1].children if c.type == "value_arguments"), None)
        if args is None: continue

        labels = []
        for a in args.children:
            if a.type != "value_argument": continue
            lk = next((c for c in a.children if c.type == "value_argument_label"), None)
            labels.append(text(lk, q) if lk is not None else None)

        trailing = (k.parent is not None and k.parent.type == "call_expression"
                    and k.parent.children and k.parent.children[0] is k)
        umgebung = umgebender_typ(k, q)
        aufrufer = k.children[0]

        if aufrufer.type == "simple_identifier":
            pfad = aufloesen(text(aufrufer, q), umgebung)
            if not pfad: continue
            kand = init_kandidaten(pfad)
            if kand and not any(passt(labels, c, trailing) for c in kand):
                befunde.append((f, k.start_point[0]+1, f"{pfad}(...)",
                                [l or "_" for l in labels], [zeige(c) for c in kand]))
            continue

        if aufrufer.type == "navigation_expression":
            basis = aufrufer.children[0]
            sfx = next((c for c in aufrufer.children if c.type == "navigation_suffix"), None)
            if basis.type != "simple_identifier" or sfx is None: continue
            mname = text(sfx, q).lstrip(".")
            if mname in SYNTHETISCH: continue
            pfad = aufloesen(text(basis, q), umgebung)
            if not pfad: continue
            e = typen[pfad]
            if mname in e["funktionen"]:
                kand = e["funktionen"][mname]
                if not any(passt(labels, c, trailing) for c in kand):
                    befunde.append((f, k.start_point[0]+1, f"{pfad}.{mname}(...)",
                                    [l or "_" for l in labels], [zeige(c) for c in kand]))
            else:
                verschachtelt = aufloesen(mname, pfad)
                if verschachtelt and verschachtelt.startswith(pfad + "."):
                    kand = init_kandidaten(verschachtelt)
                    if kand and not any(passt(labels, c, trailing) for c in kand):
                        befunde.append((f, k.start_point[0]+1, f"{verschachtelt}(...)",
                                        [l or "_" for l in labels], [zeige(c) for c in kand]))
                elif mname not in e["eigenschaften"] and not verschachtelt:
                    befunde.append((f, k.start_point[0]+1,
                                    f"{pfad}.{mname} ist nicht deklariert", [], []))

print(f"{len(typen)} Typen (mit Pfad) erfasst, {len(dateien)} Dateien geprueft.\n")
if not befunde:
    print("Keine Abweichungen zwischen Aufrufen und Deklarationen.")
for f, z, was, geliefert, erwartet in sorted(befunde, key=lambda b: (str(b[0]), b[1])):
    print(f"{f}:{z}  {was}")
    if geliefert or erwartet:
        print(f"    geliefert: {geliefert}")
        for e in erwartet: print(f"    erwartet : {e}")
