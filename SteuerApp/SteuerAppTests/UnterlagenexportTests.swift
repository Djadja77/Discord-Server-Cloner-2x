import XCTest
@testable import SteuerApp

/// Tests der Dateinamen im Unterlagenarchiv.
///
/// Die Namen sind kein Beiwerk: Die Belegliste verweist auf sie, und die Steuerberatung
/// findet darüber das Papier zur Zeile. Ein abgeschnittener Umlaut oder ein verschluckter
/// Cent bricht diese Zuordnung.
final class UnterlagenexportTests: XCTestCase {

    private func datum(_ jahr: Int, _ monat: Int, _ tag: Int) -> Date {
        Calendar.kalender.date(from: DateComponents(
            year: jahr, month: monat, day: tag, hour: 12))!
    }

    // MARK: - Bereinigung

    func testUmlauteWerdenUebersetzt() {
        XCTAssertEqual(Unterlagenexport.dateisicher("Büro Öl Ärger Straße"),
                       "Buero-Oel-Aerger-Strasse")
    }

    func testSonderzeichenWerdenZuBindestrichen() {
        XCTAssertEqual(Unterlagenexport.dateisicher("Müller & Co. GmbH"), "Mueller-Co-GmbH")
        XCTAssertEqual(Unterlagenexport.dateisicher("Rechnung/2025 #42"), "Rechnung-2025-42")
    }

    func testMehrfacheTrennerWerdenZusammengefasst() {
        XCTAssertEqual(Unterlagenexport.dateisicher("A   ---   B"), "A-B")
    }

    func testFuehrendeUndAbschliessendeTrennerFallenWeg() {
        XCTAssertEqual(Unterlagenexport.dateisicher("  Muster GmbH  "), "Muster-GmbH")
        XCTAssertEqual(Unterlagenexport.dateisicher("...Muster..."), "Muster")
    }

    func testLangeBezeichnungenWerdenGekuerzt() {
        let lang = String(repeating: "a", count: 80)
        XCTAssertEqual(Unterlagenexport.dateisicher(lang).count, 40)
    }

    func testLeereBezeichnungBekommtEinenErsatznamen() {
        XCTAssertEqual(Unterlagenexport.dateisicher(""), "Beleg")
        XCTAssertEqual(Unterlagenexport.dateisicher("---"), "Beleg")
        XCTAssertEqual(Unterlagenexport.dateisicher("€ $ %"), "Beleg")
    }

    // MARK: - Betrag im Dateinamen

    func testBetragHatImmerZweiNachkommastellen() {
        XCTAssertEqual(Unterlagenexport.betragImNamen(Decimal(string: "184.60")!), "184-60")
        XCTAssertEqual(Unterlagenexport.betragImNamen(100), "100-00")
        XCTAssertEqual(Unterlagenexport.betragImNamen(Decimal(string: "0.07")!), "0-07")
        XCTAssertEqual(Unterlagenexport.betragImNamen(Decimal(string: "1234.5")!), "1234-50")
    }

    // MARK: - Vollständiger Dateiname

    func testDateinameSetztSichAusDatumBezeichnungUndBetragZusammen() {
        let beleg = Beleg(
            datum: datum(2025, 3, 14),
            bezeichnung: "Ristorante Bella Vista",
            bruttoBetrag: Decimal(string: "184.60")!,
            kategorie: .bewirtung
        )
        XCTAssertEqual(Unterlagenexport.dateiname(fuer: beleg),
                       "2025-03-14_Ristorante-Bella-Vista_184-60.jpg")
    }

    func testOhneBezeichnungTrittDieKategorieEin() {
        let beleg = Beleg(datum: datum(2025, 7, 1), bruttoBetrag: 50, kategorie: .bürobedarf)
        XCTAssertEqual(Unterlagenexport.dateiname(fuer: beleg),
                       "2025-07-01_Buerobedarf_50-00.jpg")
    }

    func testDateinamenSindNachDatumSortierbar() {
        let frueh = Beleg(datum: datum(2025, 2, 9), bezeichnung: "A", bruttoBetrag: 1)
        let spaet = Beleg(datum: datum(2025, 11, 30), bezeichnung: "A", bruttoBetrag: 1)
        XCTAssertLessThan(Unterlagenexport.dateiname(fuer: frueh),
                          Unterlagenexport.dateiname(fuer: spaet))
    }

    // MARK: - Belegliste

    func testBeleglisteFuehrtDenDateinamenAuf() {
        let beleg = Beleg(datum: datum(2025, 3, 14), bezeichnung: "Muster",
                          bruttoBetrag: 119, kategorie: .bürobedarf,
                          belegbildDatei: "irgendwas.jpg")
        let csv = CSVExport.belege([beleg], jahr: 2025,
                                   fotonamen: [beleg.persistentModelID: "meinbeleg.jpg"])
        XCTAssertTrue(csv.contains("\"Belegdatei\""), "Spaltenueberschrift fehlt")
        XCTAssertTrue(csv.contains("\"meinbeleg.jpg\""), "Dateiname fehlt")
    }

    func testOhneZuordnungBleibtDieSpalteLeer() {
        let beleg = Beleg(datum: datum(2025, 3, 14), bezeichnung: "Muster", bruttoBetrag: 119)
        let csv = CSVExport.belege([beleg], jahr: 2025)
        XCTAssertTrue(csv.contains("\"Belegdatei\""))
        XCTAssertFalse(csv.contains(".jpg"))
    }
}
