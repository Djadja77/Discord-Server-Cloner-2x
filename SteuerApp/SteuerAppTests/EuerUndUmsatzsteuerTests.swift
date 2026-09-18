import XCTest
@testable import SteuerApp

/// Tests der Gewinnermittlung und der Umsatzsteuer.
final class EuerUndUmsatzsteuerTests: XCTestCase {

    private let jahr = 2025

    private func datum(_ monat: Int, _ tag: Int = 15, jahr: Int? = nil) -> Date {
        Calendar.kalender.date(from: DateComponents(
            year: jahr ?? self.jahr, month: monat, day: tag, hour: 12
        ))!
    }

    // MARK: - Umrechnung brutto / netto

    func testNettoUndUmsatzsteuerWerdenKorrektAusDemBruttoBetragGerechnet() {
        let beleg = Beleg(bezeichnung: "Projekt", bruttoBetrag: 10_000,
                          kategorie: .umsatzerlöse, umsatzsteuersatz: .regel)
        XCTAssertEqual(beleg.nettoBetrag, Decimal(string: "8403.36"))
        XCTAssertEqual(beleg.umsatzsteuerBetrag, Decimal(string: "1596.64"))
        XCTAssertEqual(beleg.nettoBetrag + beleg.umsatzsteuerBetrag, 10_000,
                       "Netto und Umsatzsteuer müssen den Bruttobetrag ergeben")
    }

    func testErmaessigterUndSteuerfreierSatz() {
        let bahn = Beleg(bruttoBetrag: 107, kategorie: .reisekosten, umsatzsteuersatz: .ermaessigt)
        XCTAssertEqual(bahn.nettoBetrag, 100)

        let pauschale = Beleg(bruttoBetrag: 28, kategorie: .verpflegungsmehraufwand,
                              umsatzsteuersatz: .ohne)
        XCTAssertEqual(pauschale.nettoBetrag, 28)
        XCTAssertEqual(pauschale.umsatzsteuerBetrag, 0)
    }

    // MARK: - Gewinnermittlung

    func testGewinnIstDieDifferenzDerNettobetraege() {
        let belege = [
            Beleg(datum: datum(3), bruttoBetrag: 11_900, kategorie: .umsatzerlöse),
            Beleg(datum: datum(4), bruttoBetrag: 1_190, kategorie: .bürobedarf),
        ]
        let ergebnis = EinnahmenÜberschussRechnung.berechnen(
            belege: belege, jahr: jahr, kleinunternehmer: false)

        XCTAssertEqual(ergebnis.summeEinnahmen, 10_000)
        XCTAssertEqual(ergebnis.summeAusgaben, 1_000)
        XCTAssertEqual(ergebnis.gewinn, 9_000)
    }

    func testBewirtungIstNurZu70ProzentAbziehbar() {
        let belege = [Beleg(datum: datum(5), bruttoBetrag: 238, kategorie: .bewirtung)]
        let ergebnis = EinnahmenÜberschussRechnung.berechnen(
            belege: belege, jahr: jahr, kleinunternehmer: false)

        let posten = ergebnis.ausgaben.first
        XCTAssertEqual(posten?.betragVorKürzung, 200, "Nettobetrag")
        XCTAssertEqual(posten?.betrag, 140, "70 % nach § 4 Abs. 5 Nr. 2 EStG")
        XCTAssertEqual(posten?.wurdeGekürzt, true)
    }

    func testVorsteuerAufBewirtungBleibtVollAbziehbar() {
        let belege = [Beleg(datum: datum(5), bruttoBetrag: 238, kategorie: .bewirtung)]
        let ergebnis = Umsatzsteuerberechnung.berechnen(
            belege: belege, jahr: jahr, rhythmus: .vierteljährlich, kleinunternehmer: false)
        XCTAssertEqual(ergebnis.vorsteuerGesamt, 38,
                       "die ertragsteuerliche Kürzung gilt nicht für die Vorsteuer")
    }

    func testBetrieblicherAnteilKuerztDieAusgabe() {
        let belege = [Beleg(datum: datum(2), bruttoBetrag: 119,
                            kategorie: .telefonInternet, betrieblicherAnteil: 0.7)]
        let ergebnis = EinnahmenÜberschussRechnung.berechnen(
            belege: belege, jahr: jahr, kleinunternehmer: false)
        XCTAssertEqual(ergebnis.summeAusgaben, 70)

        let ust = Umsatzsteuerberechnung.berechnen(
            belege: belege, jahr: jahr, rhythmus: .vierteljährlich, kleinunternehmer: false)
        XCTAssertEqual(ust.vorsteuerGesamt, Decimal(string: "13.30"))
    }

    func testKleinunternehmerRechnenMitBruttobetraegen() {
        let belege = [
            Beleg(datum: datum(3), bruttoBetrag: 11_900, kategorie: .umsatzerlöse),
            Beleg(datum: datum(4), bruttoBetrag: 1_190, kategorie: .bürobedarf),
        ]
        let ergebnis = EinnahmenÜberschussRechnung.berechnen(
            belege: belege, jahr: jahr, kleinunternehmer: true)

        XCTAssertEqual(ergebnis.summeEinnahmen, 11_900)
        XCTAssertEqual(ergebnis.summeAusgaben, 1_190)
        XCTAssertEqual(ergebnis.gewinn, 10_710)
    }

    func testKleinunternehmerHabenKeineUmsatzsteuer() {
        let belege = [Beleg(datum: datum(3), bruttoBetrag: 11_900, kategorie: .umsatzerlöse)]
        let ergebnis = Umsatzsteuerberechnung.berechnen(
            belege: belege, jahr: jahr, rhythmus: .vierteljährlich, kleinunternehmer: true)
        XCTAssertTrue(ergebnis.kleinunternehmer)
        XCTAssertEqual(ergebnis.zahllastGesamt, 0)
        XCTAssertTrue(ergebnis.zeiträume.isEmpty)
    }

    func testBelegeAndererJahreBleibenUnberuecksichtigt() {
        let belege = [
            Beleg(datum: datum(6), bruttoBetrag: 11_900, kategorie: .umsatzerlöse),
            Beleg(datum: datum(6, jahr: 2024), bruttoBetrag: 99_000, kategorie: .umsatzerlöse),
        ]
        let ergebnis = EinnahmenÜberschussRechnung.berechnen(
            belege: belege, jahr: jahr, kleinunternehmer: false)
        XCTAssertEqual(ergebnis.summeEinnahmen, 10_000)
        XCTAssertEqual(ergebnis.anzahlBelege, 1)
    }

    func testPostenWerdenNachBetragSortiert() {
        let belege = [
            Beleg(datum: datum(1), bruttoBetrag: 119, kategorie: .bürobedarf),
            Beleg(datum: datum(2), bruttoBetrag: 11_900, kategorie: .fremdleistungen),
            Beleg(datum: datum(3), bruttoBetrag: 1_190, kategorie: .werbung),
        ]
        let ergebnis = EinnahmenÜberschussRechnung.berechnen(
            belege: belege, jahr: jahr, kleinunternehmer: false)
        XCTAssertEqual(ergebnis.ausgaben.map(\.kategorie),
                       [.fremdleistungen, .werbung, .bürobedarf])
    }

    // MARK: - Umsatzsteuer-Voranmeldung

    func testZahllastWirdJeQuartalErmittelt() {
        let belege = [
            Beleg(datum: datum(2), bruttoBetrag: 11_900, kategorie: .umsatzerlöse),
            Beleg(datum: datum(2), bruttoBetrag: 1_190, kategorie: .bürobedarf),
            Beleg(datum: datum(8), bruttoBetrag: 5_950, kategorie: .umsatzerlöse),
        ]
        let ergebnis = Umsatzsteuerberechnung.berechnen(
            belege: belege, jahr: jahr, rhythmus: .vierteljährlich, kleinunternehmer: false)

        XCTAssertEqual(ergebnis.zeiträume.count, 4)
        XCTAssertEqual(ergebnis.zeiträume[0].umsatzsteuer, 1_900)
        XCTAssertEqual(ergebnis.zeiträume[0].vorsteuer, 190)
        XCTAssertEqual(ergebnis.zeiträume[0].zahllast, 1_710)
        XCTAssertEqual(ergebnis.zeiträume[2].zahllast, 950, "drittes Quartal")
        XCTAssertEqual(ergebnis.zahllastGesamt, 2_660)
    }

    func testUeberschussAnVorsteuerErgibtEineErstattung() {
        let belege = [Beleg(datum: datum(1), bruttoBetrag: 11_900,
                            kategorie: .geringwertigeWirtschaftsgüter)]
        let ergebnis = Umsatzsteuerberechnung.berechnen(
            belege: belege, jahr: jahr, rhythmus: .vierteljährlich, kleinunternehmer: false)
        XCTAssertEqual(ergebnis.zahllastGesamt, -1_900)
    }

    func testMonatlicherRhythmusLiefertZwoelfZeitraeume() {
        let ergebnis = Umsatzsteuerberechnung.berechnen(
            belege: [], jahr: jahr, rhythmus: .monatlich, kleinunternehmer: false)
        XCTAssertEqual(ergebnis.zeiträume.count, 12)
        XCTAssertEqual(ergebnis.zeiträume.first?.bezeichnung, "Januar")
        XCTAssertEqual(ergebnis.zeiträume.last?.bezeichnung, "Dezember")
    }

    // MARK: - Quartalszuordnung

    func testQuartalsgrenzenStimmen() {
        XCTAssertEqual(Beleg(datum: datum(1, 1)).quartal, 1)
        XCTAssertEqual(Beleg(datum: datum(3, 31)).quartal, 1)
        XCTAssertEqual(Beleg(datum: datum(4, 1)).quartal, 2)
        XCTAssertEqual(Beleg(datum: datum(12, 31)).quartal, 4)
    }

    func testEinBelegVomSilvesterabendBleibtImAltenJahr() {
        let silvester = Calendar.kalender.date(from: DateComponents(
            year: 2025, month: 12, day: 31, hour: 23, minute: 30))!
        XCTAssertEqual(Beleg(datum: silvester).jahr, 2025)
    }

    // MARK: - CSV-Export

    func testCsvExportEnthaeltKopfzeileUndBelege() {
        let belege = [Beleg(datum: datum(3, 5), bezeichnung: "Muster GmbH",
                            bruttoBetrag: 1_190, kategorie: .fremdleistungen)]
        let csv = CSVExport.belege(belege, jahr: jahr)

        XCTAssertTrue(csv.contains("\"Datum\";\"Bezeichnung\""))
        XCTAssertTrue(csv.contains("\"05.03.2025\""))
        XCTAssertTrue(csv.contains("1190,00"), "deutsches Dezimalkomma")
        XCTAssertEqual(csv.components(separatedBy: "\r\n").count, 2)
    }

    func testCsvExportMaskiertAnfuehrungszeichen() {
        let belege = [Beleg(datum: datum(3, 5), bezeichnung: "Agentur \"Nord\"",
                            bruttoBetrag: 100, kategorie: .werbung)]
        let csv = CSVExport.belege(belege, jahr: jahr)
        XCTAssertTrue(csv.contains("\"Agentur \"\"Nord\"\"\""))
    }
}
