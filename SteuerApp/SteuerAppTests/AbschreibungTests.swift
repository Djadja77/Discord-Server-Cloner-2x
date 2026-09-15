import XCTest
@testable import SteuerApp

/// Tests der linearen Abschreibung nach § 7 Abs. 1 EStG.
final class AbschreibungTests: XCTestCase {

    private func datum(_ jahr: Int, _ monat: Int, _ tag: Int = 15) -> Date {
        Calendar.kalender.date(from: DateComponents(
            year: jahr, month: monat, day: tag, hour: 12))!
    }

    private func wirtschaftsgut(
        kosten: Decimal, jahre: Int, angeschafft monat: Int, jahr: Int = 2025
    ) -> Wirtschaftsgut {
        Wirtschaftsgut(
            bezeichnung: "Testgut",
            anschaffungsdatum: datum(jahr, monat),
            anschaffungskostenNetto: kosten,
            nutzungsdauerJahre: jahre
        )
    }

    func testAnschaffungImJanuarWirdGleichmaessigVerteilt() {
        let gut = wirtschaftsgut(kosten: 2_100, jahre: 3, angeschafft: 1)
        XCTAssertEqual(gut.abschreibung(fuerJahr: 2025), 700)
        XCTAssertEqual(gut.abschreibung(fuerJahr: 2026), 700)
        XCTAssertEqual(gut.abschreibung(fuerJahr: 2027), 700)
        XCTAssertEqual(gut.abschreibung(fuerJahr: 2028), 0)
    }

    func testAnschaffungImJahresverlaufWirdZeitanteiligGekuerzt() {
        // Juli: nur sechs der zwölf Monate, dafür reicht die Abschreibung ein Jahr länger.
        let gut = wirtschaftsgut(kosten: 2_100, jahre: 3, angeschafft: 7)
        XCTAssertEqual(gut.abschreibung(fuerJahr: 2025), 350)
        XCTAssertEqual(gut.abschreibung(fuerJahr: 2026), 700)
        XCTAssertEqual(gut.abschreibung(fuerJahr: 2027), 700)
        XCTAssertEqual(gut.abschreibung(fuerJahr: 2028), 350)
        XCTAssertEqual(gut.abschreibung(fuerJahr: 2029), 0)
    }

    func testDieSummeAllerJahreErgibtGenauDieAnschaffungskosten() {
        // Auch wenn der Jahresbetrag nicht glatt aufgeht.
        for (kosten, jahre, monat) in [(Decimal(1_000), 3, 1), (Decimal(1_500), 5, 10),
                                       (Decimal(2_100), 3, 7), (Decimal(999), 7, 4)] {
            let gut = wirtschaftsgut(kosten: kosten, jahre: jahre, angeschafft: monat)
            let summe = (gut.anschaffungsjahr...(gut.anschaffungsjahr + jahre + 1))
                .map { gut.abschreibung(fuerJahr: $0) }.summe
            XCTAssertEqual(summe, kosten, "\(kosten) über \(jahre) Jahre ab Monat \(monat)")
        }
    }

    func testRestbuchwertSinktAufNull() {
        let gut = wirtschaftsgut(kosten: 1_000, jahre: 3, angeschafft: 1)
        XCTAssertEqual(gut.restbuchwert(endeJahr: 2024), 1_000, "vor der Anschaffung")
        XCTAssertEqual(gut.restbuchwert(endeJahr: 2025), Decimal(string: "666.67"))
        XCTAssertEqual(gut.restbuchwert(endeJahr: 2027), 0)
    }

    func testVorDerAnschaffungWirdNichtsAbgeschrieben() {
        let gut = wirtschaftsgut(kosten: 2_100, jahre: 3, angeschafft: 6)
        XCTAssertEqual(gut.abschreibung(fuerJahr: 2024), 0)
    }

    func testUngueltigeAngabenErzeugenKeineAbschreibung() {
        XCTAssertEqual(wirtschaftsgut(kosten: 0, jahre: 3, angeschafft: 1)
            .abschreibung(fuerJahr: 2025), 0)
        XCTAssertEqual(wirtschaftsgut(kosten: 1_000, jahre: 0, angeschafft: 1)
            .abschreibung(fuerJahr: 2025), 0)
    }

    func testAbschreibungFliesstAlsBetriebsausgabeInDieEuer() {
        let einnahme = Beleg(datum: datum(2025, 3), bruttoBetrag: 11_900,
                             kategorie: .umsatzerlöse)
        let gut = wirtschaftsgut(kosten: 2_100, jahre: 3, angeschafft: 1)

        let ergebnis = EinnahmenÜberschussRechnung.berechnen(
            belege: [einnahme], wirtschaftsgüter: [gut],
            jahr: 2025, kleinunternehmer: false)

        XCTAssertEqual(ergebnis.summeAusgaben, 700)
        XCTAssertEqual(ergebnis.gewinn, 9_300, "10.000 Einnahmen abzüglich 700 Abschreibung")
        XCTAssertEqual(ergebnis.ausgaben.first?.kategorie, .abschreibung)
    }

    func testHanderfassteUndBerechneteAbschreibungWerdenZusammengefasst() {
        let manuell = Beleg(datum: datum(2025, 12), bruttoBetrag: 500,
                            kategorie: .abschreibung, umsatzsteuersatz: .ohne)
        let gut = wirtschaftsgut(kosten: 2_100, jahre: 3, angeschafft: 1)

        let ergebnis = EinnahmenÜberschussRechnung.berechnen(
            belege: [manuell], wirtschaftsgüter: [gut],
            jahr: 2025, kleinunternehmer: false)

        XCTAssertEqual(ergebnis.ausgaben.count, 1, "ein gemeinsamer Posten, nicht zwei")
        XCTAssertEqual(ergebnis.summeAusgaben, 1_200)
        XCTAssertEqual(ergebnis.ausgaben.first?.anzahlBelege, 2)
    }

    func testAbschreibungAusserhalbDesJahresBleibtUnberuecksichtigt() {
        let gut = wirtschaftsgut(kosten: 2_100, jahre: 3, angeschafft: 1, jahr: 2020)
        let ergebnis = EinnahmenÜberschussRechnung.berechnen(
            belege: [], wirtschaftsgüter: [gut], jahr: 2025, kleinunternehmer: false)
        XCTAssertTrue(ergebnis.ausgaben.isEmpty)
    }

    func testNutzungsdauervorlagenSindPlausibel() {
        for vorlage in Nutzungsdauervorlage.allCases {
            XCTAssertGreaterThan(vorlage.jahre, 0)
            XCTAssertLessThanOrEqual(vorlage.jahre, 20)
        }
    }
}
