import XCTest
@testable import SteuerApp

/// Tests der Belegauswertung.
///
/// Die Bilderkennung selbst braucht ein Geraet und laesst sich im Test nicht nachstellen.
/// Die Auswertung der erkannten Zeilen dagegen schon - und genau dort sitzen die Fehler.
final class BelegTexterkennungTests: XCTestCase {

    /// Ein realistischer Restaurantbeleg mit zwei Steuersaetzen.
    private let restaurantbeleg = [
        "Ristorante Bella Vista",
        "Hauptstr. 5",
        "10115 Berlin",
        "Rechnung Nr. 4711",
        "2x Pizza Margherita     18,00",
        "3x Mineralwasser        12,00",
        "Gesamt                  30,00",
        "MwSt A 19%               1,92",
        "MwSt B  7%               1,18",
        "14.03.2025 19:42",
    ]

    // MARK: - Betraege

    func testErkenntDeutscheBetragsschreibweise() {
        XCTAssertEqual(BelegTexterkennung.betraege(in: "Summe 1.234,56 EUR"),
                       [Decimal(string: "1234.56")])
        XCTAssertEqual(BelegTexterkennung.betraege(in: "19,90"), [Decimal(string: "19.90")])
        XCTAssertEqual(BelegTexterkennung.betraege(in: "12.345.678,90 EUR"),
                       [Decimal(string: "12345678.90")])
    }

    func testIgnoriertZahlenOhneNachkommastellen() {
        XCTAssertTrue(BelegTexterkennung.betraege(in: "Rechnungsnummer 2025").isEmpty)
        XCTAssertTrue(BelegTexterkennung.betraege(in: "Menge 3 Stueck").isEmpty)
    }

    func testBevorzugtDieZeileMitDemSummenwort() {
        let beleg = [
            "Buerostuhl        899,00",
            "Lieferung          49,00",
            "Zwischensumme     948,00",
            "Gesamtbetrag    1.128,12",
        ]
        XCTAssertEqual(BelegTexterkennung.betragFinden(in: beleg), Decimal(string: "1128.12"))
    }

    func testNimmtOhneSummenwortDenGroesstenBetrag() {
        XCTAssertEqual(BelegTexterkennung.betragFinden(in: ["Kaffee 3,20", "Kuchen 4,80", "8,00"]), 8)
    }

    func testOhneBetragImTextWirdNichtsVorgeschlagen() {
        XCTAssertNil(BelegTexterkennung.betragFinden(in: ["Vielen Dank fuer Ihren Einkauf"]))
    }

    // MARK: - Datum

    func testErkenntBelegdatumInBeidenSchreibweisen() {
        let langesJahr = BelegTexterkennung.datumFinden(in: ["Rechnungsdatum: 14.03.2025"])
        XCTAssertEqual(Calendar.kalender.component(.day, from: langesJahr!), 14)
        XCTAssertEqual(Calendar.kalender.component(.month, from: langesJahr!), 3)
        XCTAssertEqual(Calendar.kalender.component(.year, from: langesJahr!), 2025)

        let kurzesJahr = BelegTexterkennung.datumFinden(in: ["07.11.24 12:45"])
        XCTAssertEqual(Calendar.kalender.component(.year, from: kurzesJahr!), 2024)
    }

    func testVerwirftUnmoeglicheDatumsangaben() {
        XCTAssertNil(BelegTexterkennung.datumFinden(in: ["Artikel 45.99.2025"]))
        XCTAssertNil(BelegTexterkennung.datumFinden(in: ["Version 1.2.3"]))
    }

    func testNimmtDasErsteDatumImBeleg() {
        let datum = BelegTexterkennung.datumFinden(in: [
            "Belegdatum 02.06.2025", "Faellig am 16.06.2025",
        ])
        XCTAssertEqual(Calendar.kalender.component(.day, from: datum!), 2)
    }

    // MARK: - Haendler

    func testNimmtDenHaendlernamenAusDemBelegkopf() {
        XCTAssertEqual(BelegTexterkennung.haendlerFinden(in: restaurantbeleg),
                       "Ristorante Bella Vista")
    }

    func testUeberspringtUeberschriftenUndAnschrift() {
        let beleg = ["RECHNUNG", "Hauptstr. 12", "10115 Berlin", "Muster Handels GmbH"]
        XCTAssertEqual(BelegTexterkennung.haendlerFinden(in: beleg), "Muster Handels GmbH")
    }

    func testStrassennameOhneHausnummerBleibtEinHaendlername() {
        // "Baeckerei Sonnenweg" ist ein Name, "Sonnenweg 12" eine Anschrift.
        XCTAssertFalse(BelegTexterkennung.istAdresszeile("Baeckerei Sonnenweg"))
        XCTAssertTrue(BelegTexterkennung.istAdresszeile("Sonnenweg 12"))
        XCTAssertTrue(BelegTexterkennung.istAdresszeile("10115 Berlin"))
    }

    func testOhneBrauchbareZeileKeinHaendler() {
        XCTAssertNil(BelegTexterkennung.haendlerFinden(in: ["1234", "56,70", "**"]))
    }

    // MARK: - Umsatzsteuersatz

    func testEindeutigerSteuersatzWirdUebernommen() {
        XCTAssertEqual(
            BelegTexterkennung.steuersatzFinden(
                in: ["Summe 119,00", "enthaltene MwSt 19%"], bruttoBetrag: 119),
            .regel)
        XCTAssertEqual(
            BelegTexterkennung.steuersatzFinden(
                in: ["Summe 107,00", "MwSt 7,0%"], bruttoBetrag: 107),
            .ermaessigt)
    }

    func testBeiZweiSaetzenEntscheidetDerAusgewieseneSteuerbetrag() {
        let beleg = ["Rechnungsbetrag 119,00", "darin MwSt 19% 19,00",
                     "Buecher werden mit 7% besteuert"]
        XCTAssertEqual(
            BelegTexterkennung.steuersatzFinden(in: beleg, bruttoBetrag: 119), .regel)
    }

    func testBeiEchtGemischtemBelegWirdNichtGeraten() {
        // Speisen zu 7 %, Getraenke zu 19 % - kein einzelner Satz passt auf die Summe.
        XCTAssertNil(BelegTexterkennung.steuersatzFinden(in: restaurantbeleg, bruttoBetrag: 30))
    }

    func testProzentangabeWirdNichtMitEinemBetragVerwechselt() {
        // "19,00 %" darf nicht als Steuerbetrag von 19,00 Euro durchgehen.
        let beleg = ["Summe 214,00", "MwSt 19,00%", "ermaessigt 7,00%"]
        XCTAssertNil(BelegTexterkennung.steuersatzFinden(in: beleg, bruttoBetrag: 214))
    }

    func testNurUmsatzsteuerlichRelevanteProzentsaetze() {
        XCTAssertEqual(BelegTexterkennung.prozentangaben(in: ["Rabatt 20%", "MwSt 19%"]), [19])
        XCTAssertTrue(BelegTexterkennung.prozentangaben(in: ["Trinkgeld 10%"]).isEmpty)
    }

    // MARK: - Gesamtauswertung

    func testAuswertungFuelltAlleFelderDesRestaurantbelegs() {
        let vorschlag = BelegTexterkennung.auswerten(zeilen: restaurantbeleg)

        XCTAssertEqual(vorschlag.bruttoBetrag, 30)
        XCTAssertEqual(vorschlag.haendler, "Ristorante Bella Vista")
        XCTAssertEqual(vorschlag.kategorie, .bewirtung, "aus dem Haendlernamen abgeleitet")
        XCTAssertNil(vorschlag.umsatzsteuersatz, "gemischte Saetze, also kein Vorschlag")
        XCTAssertEqual(Calendar.kalender.component(.day, from: vorschlag.datum!), 14)
    }

    func testLeererBelegErzeugtLeerenVorschlag() {
        let vorschlag = BelegTexterkennung.auswerten(zeilen: [])
        XCTAssertNil(vorschlag.bruttoBetrag)
        XCTAssertNil(vorschlag.haendler)
        XCTAssertNil(vorschlag.datum)
        XCTAssertNil(vorschlag.kategorie)
    }
}
