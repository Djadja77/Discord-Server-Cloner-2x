import XCTest
@testable import SteuerApp

/// Tests der Gesamtrechnung vom Gewinn bis zur Nachzahlung.
final class SteuerschaetzungTests: XCTestCase {

    /// Typischer Fall: Freiberufler, 60.000 Euro Gewinn, privat kranken- und altersversichert.
    private func freiberuflerEingaben() -> Steuerschaetzung.Eingaben {
        var e = Steuerschaetzung.Eingaben(steuerjahr: .jahr2025, gewinn: 60_000)
        e.vorsorgeaufwendungen = Vorsorgeaufwendungen(
            altersvorsorge: 6_000,
            krankenUndPflegeBasis: 7_200,
            sonstigeVersicherungen: 600
        )
        return e
    }

    func testVollstaendigerRechenwegFuerEinenFreiberufler() {
        let ergebnis = Steuerschaetzung.berechnen(freiberuflerEingaben())

        // 60.000 - 6.000 Altersvorsorge - 7.200 Kranken/Pflege - 36 Pauschbetrag
        XCTAssertEqual(ergebnis.zuVersteuerndesEinkommen, 46_764)
        XCTAssertEqual(ergebnis.tariflicheEinkommensteuer, 9_561)
        XCTAssertEqual(ergebnis.solidaritätszuschlag, 0, "unter der Freigrenze")
        XCTAssertEqual(ergebnis.kirchensteuer, 0, "kein Kirchensteuerabzug gewählt")
        XCTAssertEqual(ergebnis.gesamtbelastung, 9_561)
    }

    func testSonstigeVersicherungenWirkenNichtNebenHoherKrankenversicherung() {
        // Der Höchstbetrag von 2.800 Euro ist durch die Kranken- und Pflegeversicherung
        // bereits ausgeschöpft - die 600 Euro Haftpflicht bleiben ohne Wirkung.
        let ergebnis = Steuerschaetzung.berechnen(freiberuflerEingaben())
        XCTAssertEqual(ergebnis.vorsorge.abziehbareSonstige, 0)
        XCTAssertEqual(ergebnis.vorsorge.abziehbareKrankenUndPflege, 7_200)
    }

    func testAltersvorsorgeWirdAufDenHoechstbetragGekuerzt() {
        var e = Steuerschaetzung.Eingaben(steuerjahr: .jahr2025, gewinn: 120_000)
        e.vorsorgeaufwendungen = Vorsorgeaufwendungen(altersvorsorge: 40_000)
        let ergebnis = Steuerschaetzung.berechnen(e)
        XCTAssertEqual(ergebnis.vorsorge.abziehbareAltersvorsorge,
                       Steuerjahr.jahr2025.höchstbetragAltersvorsorge)
    }

    func testSplittingVerdoppeltDenHoechstbetragDerAltersvorsorge() {
        var e = Steuerschaetzung.Eingaben(steuerjahr: .jahr2025, gewinn: 150_000)
        e.veranlagungsart = .zusammen
        e.vorsorgeaufwendungen = Vorsorgeaufwendungen(altersvorsorge: 50_000)
        let ergebnis = Steuerschaetzung.berechnen(e)
        XCTAssertEqual(ergebnis.vorsorge.abziehbareAltersvorsorge, 50_000,
                       "50.000 liegen unter dem doppelten Höchstbetrag")
    }

    func testOhneAngabenGreiftMindestensDerSonderausgabenPauschbetrag() {
        let e = Steuerschaetzung.Eingaben(steuerjahr: .jahr2025, gewinn: 40_000)
        let ergebnis = Steuerschaetzung.berechnen(e)
        XCTAssertEqual(ergebnis.übrigeSonderausgaben, 36)
        XCTAssertEqual(ergebnis.zuVersteuerndesEinkommen, 39_964)
    }

    func testVerlustFuehrtZuKeinerSteuer() {
        let e = Steuerschaetzung.Eingaben(steuerjahr: .jahr2025, gewinn: -12_000)
        let ergebnis = Steuerschaetzung.berechnen(e)
        XCTAssertEqual(ergebnis.zuVersteuerndesEinkommen, 0)
        XCTAssertEqual(ergebnis.gesamtbelastung, 0)
    }

    func testVorauszahlungenErgebenEineErstattung() {
        var e = freiberuflerEingaben()
        e.geleisteteVorauszahlungen = 12_000
        let ergebnis = Steuerschaetzung.berechnen(e)
        XCTAssertTrue(ergebnis.istErstattung)
        XCTAssertEqual(ergebnis.offenerBetrag, 9_561 - 12_000)
    }

    func testKirchensteuerWirdAufDieFestgesetzteSteuerBerechnet() {
        var e = freiberuflerEingaben()
        e.kirchensteuersatz = .neunProzent
        let ergebnis = Steuerschaetzung.berechnen(e)
        XCTAssertEqual(ergebnis.kirchensteuer, Decimal(string: "860.49"))
        XCTAssertEqual(ergebnis.gesamtbelastung, Decimal(string: "10421.49"))
    }

    // MARK: - Gewerbesteuer

    func testGewerbesteuerErhoehtDieBelastungNurUmDieRestbelastung() {
        var freiberuflich = Steuerschaetzung.Eingaben(steuerjahr: .jahr2025, gewinn: 60_000)
        freiberuflich.vorsorgeaufwendungen = Vorsorgeaufwendungen(
            altersvorsorge: 6_000, krankenUndPflegeBasis: 7_200
        )
        var gewerblich = freiberuflich
        gewerblich.tätigkeitsart = .gewerblich
        gewerblich.gewerbesteuerHebesatz = 400

        let ohne = Steuerschaetzung.berechnen(freiberuflich)
        let mit = Steuerschaetzung.berechnen(gewerblich)

        XCTAssertEqual(mit.gewerbesteuer.messbetrag, Decimal(string: "1242.50"))
        XCTAssertEqual(mit.gewerbesteuer.gewerbesteuer, 4_970)
        XCTAssertEqual(mit.angerechneteGewerbesteuer, Decimal(string: "4721.50"))
        XCTAssertEqual(mit.gewerbesteuer.restbelastung, Decimal(string: "248.50"))

        // Genau die Restbelastung ist der Unterschied - alles andere wäre ein
        // doppelt gezählter Anrechnungsvorteil.
        XCTAssertEqual(mit.gesamtbelastung - ohne.gesamtbelastung, Decimal(string: "248.50"))
    }

    func testBeiHebesatz380BleibtKeineRestbelastung() {
        var e = Steuerschaetzung.Eingaben(steuerjahr: .jahr2025, gewinn: 60_000)
        e.tätigkeitsart = .gewerblich
        e.gewerbesteuerHebesatz = 380
        let ergebnis = Steuerschaetzung.berechnen(e)
        XCTAssertEqual(ergebnis.gewerbesteuer.restbelastung, 0)
    }

    func testFreiberuflerZahlenKeineGewerbesteuer() {
        var e = Steuerschaetzung.Eingaben(steuerjahr: .jahr2025, gewinn: 200_000)
        e.tätigkeitsart = .freiberuflich
        let ergebnis = Steuerschaetzung.berechnen(e)
        XCTAssertEqual(ergebnis.gewerbesteuer, .keine)
    }

    func testGewerbesteuerFreibetragGreift() {
        var e = Steuerschaetzung.Eingaben(steuerjahr: .jahr2025, gewinn: 24_500)
        e.tätigkeitsart = .gewerblich
        let ergebnis = Steuerschaetzung.berechnen(e)
        XCTAssertEqual(ergebnis.gewerbesteuer.gewerbesteuer, 0)
    }

    // MARK: - Solidaritätszuschlag

    func testSoliSetztErstOberhalbDerFreigrenzeEin() {
        XCTAssertEqual(
            Solidaritätszuschlag.betrag(einkommensteuer: 19_950,
                                         steuerjahr: .jahr2025, splitting: false), 0)
        XCTAssertEqual(
            Solidaritätszuschlag.betrag(einkommensteuer: 21_000,
                                         steuerjahr: .jahr2025, splitting: false),
            Decimal(string: "124.95"), "Milderungszone: 11,9 % des übersteigenden Betrags")
        XCTAssertEqual(
            Solidaritätszuschlag.betrag(einkommensteuer: 40_000,
                                         steuerjahr: .jahr2025, splitting: false),
            2_200, "voller Satz von 5,5 %")
    }

    func testSoliFreigrenzeVerdoppeltSichBeiZusammenveranlagung() {
        XCTAssertEqual(
            Solidaritätszuschlag.betrag(einkommensteuer: 30_000,
                                         steuerjahr: .jahr2025, splitting: true), 0)
    }
}
