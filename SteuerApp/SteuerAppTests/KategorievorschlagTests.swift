import XCTest
@testable import SteuerApp

/// Tests der Kategorieerkennung aus dem Haendlernamen.
///
/// Verglichen wird auf Teilzeichenketten. Die Haelfte dieser Tests prueft deshalb nicht,
/// ob etwas erkannt wird, sondern ob es **nicht** faelschlich erkannt wird - dort liegen
/// die Fehler, die im Alltag Betriebsausgaben in die falsche Zeile schieben.
final class KategorievorschlagTests: XCTestCase {

    func testErkenntHaeufigeAnbieter() {
        let faelle: [(String, Belegkategorie)] = [
            ("Deutsche Bahn AG", .reisekosten),
            ("Hotel Adlon", .reisekosten),
            ("Shell Tankstelle Nord", .kfzKosten),
            ("Ristorante Bella Vista", .bewirtung),
            ("Telekom Deutschland GmbH", .telefonInternet),
            ("Adobe Systems Software", .softwareAbos),
            ("DHL Paketshop", .portoVersand),
            ("Thalia Buchhandlung", .fachliteraturFortbildung),
            ("WeWork Germany", .raumkosten),
            ("Steuerberatung Meier", .rechtsUndSteuerberatung),
            ("Allianz Versicherung", .versicherungenBeitraege),
        ]
        for (haendler, erwartet) in faelle {
            XCTAssertEqual(Kategorievorschlag.kategorie(in: haendler), erwartet, haendler)
        }
    }

    func testUnbekannteHaendlerBekommenKeinenVorschlag() {
        XCTAssertNil(Kategorievorschlag.kategorie(in: "Hinz und Kunz OHG"))
        XCTAssertNil(Kategorievorschlag.kategorie(in: ""))
    }

    // MARK: - Falsch positive Treffer

    func testKurzeStichworteSpringenNichtInAnderenWoerternAn() {
        XCTAssertNil(Kategorievorschlag.kategorie(in: "Cafe Espresso Bar"),
                     "\"Espresso\" enthaelt \"esso\"")
        XCTAssertNil(Kategorievorschlag.kategorie(in: "Metzgerei Huber"),
                     "\"Huber\" enthaelt \"uber\"")
        XCTAssertNil(Kategorievorschlag.kategorie(in: "Notarztpraxis Dr. Klein"),
                     "\"Notarzt\" enthaelt \"notar\"")
        XCTAssertEqual(Kategorievorschlag.kategorie(in: "JetBrains s.r.o."), .softwareAbos,
                       "\"JetBrains\" darf nicht als Tankstelle gelten")
    }

    func testUmlauteWerdenNormalisiert() {
        XCTAssertEqual(Kategorievorschlag.kategorie(in: "TÜV Süd Service"), .kfzKosten)
        XCTAssertEqual(Kategorievorschlag.kategorie(in: "Gaststätte Zur Post"), .bewirtung)
    }

    func testGrossUndKleinschreibungSpieltKeineRolle() {
        XCTAssertEqual(Kategorievorschlag.kategorie(in: "SHELL"), .kfzKosten)
        XCTAssertEqual(Kategorievorschlag.kategorie(in: "shell"), .kfzKosten)
    }

    // MARK: - Zusammenspiel

    func testHaendlernameWiegtSchwererAlsDerUebrigeText() {
        let kategorie = Kategorievorschlag.fuer(
            haendler: "Ristorante Bella Vista",
            zeilen: ["Hotel Zentrum", "Rechnung"]
        )
        XCTAssertEqual(kategorie, .bewirtung)
    }

    func testOhneHaendlerZaehltDerBelegkopf() {
        let kategorie = Kategorievorschlag.fuer(
            haendler: nil,
            zeilen: ["Coworking Space Mitte", "Monatsbeitrag"]
        )
        XCTAssertEqual(kategorie, .raumkosten)
    }

    func testSpaeteZeilenWerdenNichtMehrBeruecksichtigt() {
        // Artikelbezeichnungen weiter unten im Beleg fuehren sonst in die Irre.
        let kategorie = Kategorievorschlag.fuer(
            haendler: nil,
            zeilen: ["Muster GmbH", "Posten 1", "Posten 2", "Posten 3", "Hotelseife"]
        )
        XCTAssertNil(kategorie)
    }

    func testJedeZuordnungZeigtAufEineAusgabenkategorie() {
        for eintrag in Kategorievorschlag.zuordnungen {
            XCTAssertEqual(eintrag.kategorie.art, .ausgabe, eintrag.stichwort)
        }
    }
}
