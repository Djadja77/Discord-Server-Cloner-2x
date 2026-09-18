import XCTest
@testable import SteuerApp

/// Tests der Kategorieerkennung aus dem Händlernamen.
///
/// Verglichen wird auf Teilzeichenketten. Die Hälfte dieser Tests prüft deshalb nicht,
/// ob etwas erkannt wird, sondern ob es **nicht** fälschlich erkannt wird - dort liegen
/// die Fehler, die im Alltag Betriebsausgaben in die falsche Zeile schieben.
final class KategorievorschlagTests: XCTestCase {

    func testErkenntHaeufigeAnbieter() {
        let fälle: [(String, Belegkategorie)] = [
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
            ("Allianz Versicherung", .versicherungenBeiträge),
        ]
        for (händler, erwartet) in fälle {
            XCTAssertEqual(Kategorievorschlag.kategorie(in: händler), erwartet, händler)
        }
    }

    func testUnbekannteHaendlerBekommenKeinenVorschlag() {
        XCTAssertNil(Kategorievorschlag.kategorie(in: "Hinz und Kunz OHG"))
        XCTAssertNil(Kategorievorschlag.kategorie(in: ""))
    }

    // MARK: - Falsch positive Treffer

    func testKurzeStichworteSpringenNichtInAnderenWoerternAn() {
        XCTAssertNil(Kategorievorschlag.kategorie(in: "Cafe Espresso Bar"),
                     "\"Espresso\" enthält \"esso\"")
        XCTAssertNil(Kategorievorschlag.kategorie(in: "Metzgerei Huber"),
                     "\"Huber\" enthält \"uber\"")
        XCTAssertNil(Kategorievorschlag.kategorie(in: "Notarztpraxis Dr. Klein"),
                     "\"Notarzt\" enthält \"notar\"")
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
            händler: "Ristorante Bella Vista",
            zeilen: ["Hotel Zentrum", "Rechnung"]
        )
        XCTAssertEqual(kategorie, .bewirtung)
    }

    func testOhneHaendlerZaehltDerBelegkopf() {
        let kategorie = Kategorievorschlag.fuer(
            händler: nil,
            zeilen: ["Coworking Space Mitte", "Monatsbeitrag"]
        )
        XCTAssertEqual(kategorie, .raumkosten)
    }

    func testSpaeteZeilenWerdenNichtMehrBeruecksichtigt() {
        // Artikelbezeichnungen weiter unten im Beleg führen sonst in die Irre.
        let kategorie = Kategorievorschlag.fuer(
            händler: nil,
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
