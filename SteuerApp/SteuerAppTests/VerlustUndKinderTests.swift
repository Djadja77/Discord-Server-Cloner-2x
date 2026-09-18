import XCTest
@testable import SteuerApp

/// Tests des Verlustabzugs (§ 10d EStG) und der Günstigerprüfung für Kinder (§ 31 EStG).
final class VerlustUndKinderTests: XCTestCase {

    private let jahr2025 = Steuerjahr.jahr2025

    // MARK: - Verlustabzug

    func testVerlustvortragWirdVollVerrechnetWennErKleinGenugIst() {
        let ergebnis = Verlustverrechnung.anwenden(
            gesamtbetragDerEinkünfte: 60_000, verlustvortrag: 20_000,
            steuerjahr: jahr2025, splitting: false)

        XCTAssertEqual(ergebnis.abgezogen, 20_000)
        XCTAssertEqual(ergebnis.verbleibenderVortrag, 0)
        XCTAssertFalse(ergebnis.wurdeBegrenzt)
    }

    func testVerlustabzugIstDurchDieEinkuenfteBegrenzt() {
        let ergebnis = Verlustverrechnung.anwenden(
            gesamtbetragDerEinkünfte: 60_000, verlustvortrag: 100_000,
            steuerjahr: jahr2025, splitting: false)

        XCTAssertEqual(ergebnis.abgezogen, 60_000, "mehr als die Einkünfte geht nicht")
        XCTAssertEqual(ergebnis.verbleibenderVortrag, 40_000)
        XCTAssertTrue(ergebnis.wurdeBegrenzt)
    }

    func testMindestbesteuerungGreiftOberhalbDesSockelbetrags() {
        // Bis 1 Mio Euro unbeschränkt, darüber nur 70 % des übersteigenden Betrags:
        // 1.000.000 + 0,7 * 500.000 = 1.350.000
        let ergebnis = Verlustverrechnung.anwenden(
            gesamtbetragDerEinkünfte: 1_500_000, verlustvortrag: 2_000_000,
            steuerjahr: jahr2025, splitting: false)

        XCTAssertEqual(ergebnis.höchstbetrag, 1_350_000)
        XCTAssertEqual(ergebnis.abgezogen, 1_350_000)
        XCTAssertEqual(ergebnis.verbleibenderVortrag, 650_000)
    }

    func testSockelbetragVerdoppeltSichBeiZusammenveranlagung() {
        let ergebnis = Verlustverrechnung.anwenden(
            gesamtbetragDerEinkünfte: 1_500_000, verlustvortrag: 2_000_000,
            steuerjahr: jahr2025, splitting: true)

        XCTAssertEqual(ergebnis.abgezogen, 1_500_000, "der Sockel von 2 Mio deckt alles ab")
        XCTAssertEqual(ergebnis.verbleibenderVortrag, 500_000)
    }

    func testOhneVortragPassiertNichts() {
        let ergebnis = Verlustverrechnung.anwenden(
            gesamtbetragDerEinkünfte: 60_000, verlustvortrag: 0,
            steuerjahr: jahr2025, splitting: false)
        XCTAssertEqual(ergebnis, .keine)
    }

    func testVerlustjahrVerbrauchtDenVortragNicht() {
        // Wer selbst Verlust macht, kann nichts verrechnen - der Vortrag bleibt erhalten.
        let ergebnis = Verlustverrechnung.anwenden(
            gesamtbetragDerEinkünfte: -5_000, verlustvortrag: 30_000,
            steuerjahr: jahr2025, splitting: false)
        XCTAssertEqual(ergebnis.abgezogen, 0)
        XCTAssertEqual(ergebnis.verbleibenderVortrag, 30_000)
    }

    func testVerlustabzugMindertDasZuVersteuerndeEinkommen() {
        var e = Steuerschaetzung.Eingaben(steuerjahr: jahr2025, gewinn: 60_000)
        e.verlustvortragAusVorjahren = 20_000
        let ergebnis = Steuerschaetzung.berechnen(e)

        XCTAssertEqual(ergebnis.verlustabzug.abgezogen, 20_000)
        XCTAssertEqual(ergebnis.zuVersteuerndesEinkommen, 39_964, "60.000 - 20.000 - 36")
    }

    // MARK: - Kinderfreibetrag und Günstigerprüfung

    func testBeiKleinemEinkommenGewinntDasKindergeld() {
        let ergebnis = Kinderfreibetrag.prüfen(
            zuVersteuerndesEinkommen: 30_000, anzahlKinder: 1,
            vollerFreibetrag: false, steuerjahr: jahr2025, splitting: false)

        XCTAssertEqual(ergebnis.freibetrag, 4_800, "halber Freibetrag bei Einzelveranlagung")
        XCTAssertEqual(ergebnis.kindergeldanspruch, 1_530)
        XCTAssertEqual(ergebnis.entlastung, 1_323)
        XCTAssertFalse(ergebnis.freibeträgeAngesetzt)
        XCTAssertEqual(ergebnis.tariflicheEinkommensteuer, 4_303, "Steuer ohne Freibeträge")
    }

    func testBeiHohemEinkommenGewinnenDieFreibetraege() {
        let ergebnis = Kinderfreibetrag.prüfen(
            zuVersteuerndesEinkommen: 60_000, anzahlKinder: 1,
            vollerFreibetrag: false, steuerjahr: jahr2025, splitting: false)

        XCTAssertTrue(ergebnis.freibeträgeAngesetzt)
        XCTAssertEqual(ergebnis.entlastung, 1_832)
        // Steuer mit Freibetrag plus hinzugerechnetes Kindergeld: 12.583 + 1.530
        XCTAssertEqual(ergebnis.tariflicheEinkommensteuer, 14_113)
        XCTAssertLessThan(ergebnis.tariflicheEinkommensteuer, ergebnis.steuerOhneFreibetrag,
                          "die günstigere Variante muss auch tatsächlich günstiger sein")
    }

    func testZusammenveranlagungGewaehrtDenVollenFreibetrag() {
        let ergebnis = Kinderfreibetrag.prüfen(
            zuVersteuerndesEinkommen: 200_000, anzahlKinder: 2,
            vollerFreibetrag: false, steuerjahr: jahr2025, splitting: true)

        XCTAssertEqual(ergebnis.freibetrag, 19_200, "2 Kinder mal 9.600 Euro")
        XCTAssertEqual(ergebnis.kindergeldanspruch, 6_120)
        XCTAssertTrue(ergebnis.freibeträgeAngesetzt)
    }

    func testUebertragenerFreibetragWirktWieZusammenveranlagung() {
        let halb = Kinderfreibetrag.prüfen(
            zuVersteuerndesEinkommen: 120_000, anzahlKinder: 1,
            vollerFreibetrag: false, steuerjahr: jahr2025, splitting: false)
        let voll = Kinderfreibetrag.prüfen(
            zuVersteuerndesEinkommen: 120_000, anzahlKinder: 1,
            vollerFreibetrag: true, steuerjahr: jahr2025, splitting: false)

        XCTAssertEqual(halb.freibetrag * 2, voll.freibetrag)
        XCTAssertEqual(halb.kindergeldanspruch * 2, voll.kindergeldanspruch)
    }

    func testOhneKinderAendertSichNichts() {
        let ergebnis = Kinderfreibetrag.prüfen(
            zuVersteuerndesEinkommen: 60_000, anzahlKinder: 0,
            vollerFreibetrag: false, steuerjahr: jahr2025, splitting: false)

        XCTAssertEqual(ergebnis.freibetrag, 0)
        XCTAssertEqual(ergebnis.tariflicheEinkommensteuer, ergebnis.steuerOhneFreibetrag)
        XCTAssertEqual(ergebnis.bemessungZuschlagsteuern, ergebnis.steuerOhneFreibetrag)
    }

    func testGuenstigerpruefungWaehltImmerDieBilligereVariante() {
        // Beide Wege durchrechnen und mit dem Ergebnis der App vergleichen.
        for zve in stride(from: 20_000, through: 300_000, by: 10_000) {
            let ergebnis = Kinderfreibetrag.prüfen(
                zuVersteuerndesEinkommen: Decimal(zve), anzahlKinder: 2,
                vollerFreibetrag: false, steuerjahr: jahr2025, splitting: true)

            let mitFreibetrag = ergebnis.steuerMitFreibetrag + ergebnis.kindergeldanspruch
            let ohneFreibetrag = ergebnis.steuerOhneFreibetrag
            XCTAssertEqual(ergebnis.tariflicheEinkommensteuer,
                           min(mitFreibetrag, ohneFreibetrag),
                           "bei zvE \(zve)")
        }
    }

    // MARK: - § 51a EStG

    func testKirchensteuerNutztImmerDieSteuerMitKinderfreibetraegen() {
        var e = Steuerschaetzung.Eingaben(steuerjahr: jahr2025, gewinn: 80_072)
        e.veranlagungsart = .zusammen
        e.kirchensteuersatz = .neunProzent
        e.anzahlKinder = 2
        let ergebnis = Steuerschaetzung.berechnen(e)

        // zvE 80.000: das Kindergeld ist günstiger, die Einkommensteuer bleibt deshalb
        // bei 14.640 Euro. Die Kirchensteuer bemisst sich trotzdem nach den 8.834 Euro,
        // die sich mit Kinderfreibeträgen ergeben (§ 51a Abs. 2 EStG).
        XCTAssertEqual(ergebnis.zuVersteuerndesEinkommen, 80_000)
        XCTAssertFalse(ergebnis.kinder.freibeträgeAngesetzt)
        XCTAssertEqual(ergebnis.tariflicheEinkommensteuer, 14_640)
        XCTAssertEqual(ergebnis.kinder.bemessungZuschlagsteuern, 8_834)
        XCTAssertEqual(ergebnis.kirchensteuer, Decimal(string: "795.06"))
    }
}
