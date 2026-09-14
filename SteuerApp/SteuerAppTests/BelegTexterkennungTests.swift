import XCTest
@testable import SteuerApp

/// Tests der Belegauswertung. Die Texterkennung selbst braucht ein Bild und laesst sich im
/// Test nicht sinnvoll nachstellen - die Auswertung der erkannten Zeilen dagegen schon,
/// und genau dort sitzen die Fehler.
final class BelegTexterkennungTests: XCTestCase {

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
        let beleg = ["Kaffee 3,20", "Kuchen 4,80", "8,00"]
        XCTAssertEqual(BelegTexterkennung.betragFinden(in: beleg), 8)
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
            "Belegdatum 02.06.2025",
            "Faellig am 16.06.2025",
        ])
        XCTAssertEqual(Calendar.kalender.component(.day, from: datum!), 2)
    }
}
