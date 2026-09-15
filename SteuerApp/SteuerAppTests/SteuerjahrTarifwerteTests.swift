import XCTest
@testable import SteuerApp

/// Haelt die hinterlegten Tarifkonstanten auf den Werten fest, die im Gesetz stehen.
///
/// `SteuerjahrKonsistenzTests` prueft, ob die Zahlen **zueinander** passen - dieser Test
/// prueft, ob es **die richtigen** Zahlen sind. Beides zusammen faengt sowohl Tippfehler
/// als auch stilles Abdriften ab: wer hier eine Zahl aendert, muss den Test mitaendern und
/// stolpert dabei ueber die Quellenangabe.
///
/// Quellen:
/// - § 32a Abs. 1 EStG in den Fassungen fuer die Veranlagungszeitraeume 2024, 2025 und 2026
/// - Amtliches Einkommensteuer-Handbuch des Bundesfinanzministeriums (fuer 2025)
/// - § 3 SolZG fuer die Freigrenzen des Solidaritaetszuschlags
/// - § 32 Abs. 6 EStG fuer die Kinderfreibetraege
final class SteuerjahrTarifwerteTests: XCTestCase {

    private func pruefe(
        _ jahr: Steuerjahr,
        grundfreibetrag: Decimal, endeZone2: Decimal, endeZone3: Decimal,
        faktorZone2: Double, faktorZone3: Double, sockelZone3: Double,
        abzugZone4: Double, abzugZone5: Double,
        datei: StaticString = #filePath, zeile: UInt = #line
    ) {
        let t = jahr.tarif
        XCTAssertEqual(t.grundfreibetrag, grundfreibetrag, "Grundfreibetrag \(jahr.jahr)",
                       file: datei, line: zeile)
        XCTAssertEqual(t.endeZone2, endeZone2, "Ende Zone 2 \(jahr.jahr)",
                       file: datei, line: zeile)
        XCTAssertEqual(t.endeZone3, endeZone3, "Ende Zone 3 \(jahr.jahr)",
                       file: datei, line: zeile)
        XCTAssertEqual(t.endeZone4, 277_825, "Ende Zone 4 \(jahr.jahr)",
                       file: datei, line: zeile)
        XCTAssertEqual(t.faktorZone2, faktorZone2, accuracy: 0.001,
                       "Faktor Zone 2 \(jahr.jahr)", file: datei, line: zeile)
        XCTAssertEqual(t.faktorZone3, faktorZone3, accuracy: 0.001,
                       "Faktor Zone 3 \(jahr.jahr)", file: datei, line: zeile)
        XCTAssertEqual(t.sockelZone3, sockelZone3, accuracy: 0.001,
                       "Sockel Zone 3 \(jahr.jahr)", file: datei, line: zeile)
        XCTAssertEqual(t.abzugZone4, abzugZone4, accuracy: 0.001,
                       "Abzug Zone 4 \(jahr.jahr)", file: datei, line: zeile)
        XCTAssertEqual(t.abzugZone5, abzugZone5, accuracy: 0.001,
                       "Abzug Zone 5 \(jahr.jahr)", file: datei, line: zeile)
    }

    func testTarifwerte2024() {
        pruefe(.jahr2024,
               grundfreibetrag: 11_784, endeZone2: 17_005, endeZone3: 66_760,
               faktorZone2: 954.80, faktorZone3: 181.19, sockelZone3: 991.21,
               abzugZone4: 10_636.31, abzugZone5: 18_971.06)
    }

    func testTarifwerte2025() {
        pruefe(.jahr2025,
               grundfreibetrag: 12_096, endeZone2: 17_443, endeZone3: 68_480,
               faktorZone2: 932.30, faktorZone3: 176.64, sockelZone3: 1_015.13,
               abzugZone4: 10_911.92, abzugZone5: 19_246.67)
    }

    func testTarifwerte2026() {
        pruefe(.jahr2026,
               grundfreibetrag: 12_348, endeZone2: 17_799, endeZone3: 69_878,
               faktorZone2: 914.51, faktorZone3: 173.10, sockelZone3: 1_034.87,
               abzugZone4: 11_135.63, abzugZone5: 19_470.38)
    }

    func testFreigrenzenDesSolidaritaetszuschlags() {
        XCTAssertEqual(Steuerjahr.jahr2024.soliFreigrenze, 18_130)
        XCTAssertEqual(Steuerjahr.jahr2025.soliFreigrenze, 19_950)
        XCTAssertEqual(Steuerjahr.jahr2026.soliFreigrenze, 20_350)
    }

    func testKinderfreibetraegeUndKindergeld() {
        // Betraege fuer beide Elternteile zusammen.
        XCTAssertEqual(Steuerjahr.jahr2024.kinderfreibetragGesamt, 9_540)
        XCTAssertEqual(Steuerjahr.jahr2025.kinderfreibetragGesamt, 9_600)
        XCTAssertEqual(Steuerjahr.jahr2026.kinderfreibetragGesamt, 9_756)

        // Der Betreuungsfreibetrag liegt seit Jahren unveraendert bei 2.928 Euro.
        for jahr in Steuerjahr.alle {
            XCTAssertEqual(jahr.betreuungsfreibetrag, 2_928, "Jahr \(jahr.jahr)")
        }

        XCTAssertEqual(Steuerjahr.jahr2024.kindergeldProMonat, 250)
        XCTAssertEqual(Steuerjahr.jahr2025.kindergeldProMonat, 255)
        XCTAssertEqual(Steuerjahr.jahr2026.kindergeldProMonat, 259)
    }

    func testHoechstbetraegeDerAltersvorsorge() {
        // 24,7 % der Beitragsbemessungsgrenze der knappschaftlichen Rentenversicherung.
        XCTAssertEqual(Steuerjahr.jahr2024.hoechstbetragAltersvorsorge, 27_566)
        XCTAssertEqual(Steuerjahr.jahr2025.hoechstbetragAltersvorsorge, 29_344)
        XCTAssertEqual(Steuerjahr.jahr2026.hoechstbetragAltersvorsorge, 30_826)
    }

    func testAlleJahreSindAlsGeprueftMarkiert() {
        for jahr in Steuerjahr.alle {
            XCTAssertTrue(jahr.amtlichGeprueft,
                          "Jahr \(jahr.jahr) ist nicht als geprueft markiert")
        }
    }

    // MARK: - Amtliche Tabellenwerte

    func testGrundtabelle2025TrifftAmtlicheWerte() {
        let tarif = Einkommensteuertarif(steuerjahr: .jahr2025)
        XCTAssertEqual(tarif.grundtarif(20_000), 1_639)
        XCTAssertEqual(tarif.grundtarif(100_000), 31_088)
    }
}
