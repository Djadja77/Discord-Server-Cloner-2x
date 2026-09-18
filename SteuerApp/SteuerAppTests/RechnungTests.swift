import XCTest
@testable import SteuerApp

/// Tests rund um ausgehende Rechnungen.
///
/// Geprüft wird vor allem, was in einer Betriebsprüfung Ärger macht: Nummern, die sich
/// wiederholen, Summen, die bei mehreren Steuersätzen nicht aufgehen, und Stornos, die
/// den ursprünglichen Betrag nicht sauber aufheben.
final class RechnungTests: XCTestCase {

    // MARK: - Nummernkreis

    func testNummerBeginntBeiEins() {
        let vergeben = Rechnungsnummer.vergeben(fuer: 2026, in: "")
        XCTAssertEqual(vergeben.nummer, "2026-0001")
        XCTAssertEqual(vergeben.laufend, 1)
    }

    func testNummerZaehltWeiter() {
        var kreis = ""
        var nummern: [String] = []
        for _ in 1...3 {
            let vergeben = Rechnungsnummer.vergeben(fuer: 2026, in: kreis)
            kreis = vergeben.kreis
            nummern.append(vergeben.nummer)
        }
        XCTAssertEqual(nummern, ["2026-0001", "2026-0002", "2026-0003"])
    }

    /// Jede Nummer darf nur einmal vergeben werden (§ 14 Abs. 4 Nr. 4 UStG). Das ist der
    /// Test, der einen Rückwärtszähler auffliegen lässt.
    func testKeineNummerZweimal() {
        var kreis = ""
        var gesehen = Set<String>()
        for _ in 1...50 {
            let vergeben = Rechnungsnummer.vergeben(fuer: 2026, in: kreis)
            kreis = vergeben.kreis
            XCTAssertTrue(gesehen.insert(vergeben.nummer).inserted,
                          "Nummer \(vergeben.nummer) wurde zweimal vergeben")
        }
    }

    func testJahreZaehlenGetrennt() {
        let ersteInZweitausendsechsundzwanzig = Rechnungsnummer.vergeben(fuer: 2026, in: "2025:118")
        XCTAssertEqual(ersteInZweitausendsechsundzwanzig.nummer, "2026-0001")
        // Der Stand des Vorjahres darf dabei nicht verloren gehen.
        XCTAssertEqual(Rechnungsnummer.stand(fuer: 2025, in: ersteInZweitausendsechsundzwanzig.kreis), 118)
    }

    func testVorschauVerbrauchtKeineNummer() {
        let kreis = "2026:7"
        XCTAssertEqual(Rechnungsnummer.vorschau(fuer: 2026, in: kreis), "2026-0008")
        XCTAssertEqual(Rechnungsnummer.stand(fuer: 2026, in: kreis), 7,
                       "Die Vorschau darf den Stand nicht erhöhen")
    }

    func testUnlesbarerKreisWirdIgnoriert() {
        XCTAssertEqual(Rechnungsnummer.stand(fuer: 2026, in: "kaputt;2026:4;;x:y"), 4)
    }

    // MARK: - Beträge

    func testSummeMitEinemSteuersatz() {
        let rechnung = beispiel(posten: [(2, 95, .regel)])
        XCTAssertEqual(rechnung.netto, 190)
        XCTAssertEqual(rechnung.umsatzsteuer, Decimal(string: "36.10"))
        XCTAssertEqual(rechnung.brutto, Decimal(string: "226.10"))
    }

    /// Eine Rechnung darf mehrere Steuersätze enthalten; das Entgelt ist danach
    /// aufzuschlüsseln (§ 14 Abs. 4 Nr. 8 UStG). Die Steuer wird je Satz gerundet, nicht
    /// auf die Gesamtsumme - sonst weicht sie um Cent von der des Empfängers ab.
    func testSummeMitZweiSteuersaetzen() {
        let rechnung = beispiel(posten: [(1, 100, .regel), (1, 100, .ermaessigt)])
        XCTAssertEqual(rechnung.netto, 200)
        XCTAssertEqual(rechnung.umsatzsteuerJeSatz.count, 2)
        XCTAssertEqual(rechnung.umsatzsteuer, 26)
        XCTAssertEqual(rechnung.brutto, 226)
    }

    func testKleinunternehmerWeistKeineSteuerAus() {
        let rechnung = beispiel(posten: [(1, 500, .regel)])
        rechnung.kleinunternehmer = true
        XCTAssertTrue(rechnung.umsatzsteuerJeSatz.isEmpty)
        XCTAssertEqual(rechnung.umsatzsteuer, 0)
        XCTAssertEqual(rechnung.brutto, 500, "Brutto und Netto sind bei § 19 dasselbe")
    }

    // MARK: - Hindernisse

    func testEntwurfOhneAllesLaesstSichNichtStellen() {
        let leer = Rechnung()
        XCTAssertFalse(leer.hindernisse.isEmpty)
        XCTAssertTrue(leer.hindernisse.contains("Kunde fehlt"))
        XCTAssertTrue(leer.hindernisse.contains("Keine Position erfasst"))
    }

    func testVollstaendigerEntwurfHatKeineHindernisse() {
        let rechnung = beispiel(posten: [(1, 100, .regel)])
        rechnung.kunde = Kunde(name: "Musterstadt GmbH", strasse: "Rathausplatz 3",
                               plz: "44532", ort: "Lünen")
        XCTAssertTrue(rechnung.hindernisse.isEmpty, "Offen: \(rechnung.hindernisse)")
    }

    func testUnvollstaendigeAnschriftWirdBemaengelt() {
        let rechnung = beispiel(posten: [(1, 100, .regel)])
        rechnung.kunde = Kunde(name: "Nur ein Name")
        XCTAssertTrue(rechnung.hindernisse.contains { $0.contains("Anschrift") })
    }

    // MARK: - Fälligkeit

    func testUeberfaelligErstNachDemZahlungsziel() {
        let rechnung = beispiel(posten: [(1, 100, .regel)])
        rechnung.status = .offen
        rechnung.zahlbarBis = Calendar.kalender.date(byAdding: .day, value: 3, to: Date())!
        XCTAssertFalse(rechnung.istÜberfällig)

        rechnung.zahlbarBis = Calendar.kalender.date(byAdding: .day, value: -3, to: Date())!
        XCTAssertTrue(rechnung.istÜberfällig)
        XCTAssertEqual(rechnung.tageÜberfällig, 3)
    }

    func testBezahlteRechnungIstNieUeberfaellig() {
        let rechnung = beispiel(posten: [(1, 100, .regel)])
        rechnung.status = .bezahlt
        rechnung.zahlbarBis = Calendar.kalender.date(byAdding: .day, value: -30, to: Date())!
        XCTAssertFalse(rechnung.istÜberfällig)
    }

    // MARK: - Hilfsmittel

    private func beispiel(posten: [(Decimal, Decimal, Umsatzsteuersatz)]) -> Rechnung {
        let rechnung = Rechnung(nummer: "2026-0001", jahr: 2026, laufendeNummer: 1)
        for (stelle, eintrag) in posten.enumerated() {
            let neu = Rechnungsposten(
                reihenfolge: stelle,
                bezeichnung: "Position \(stelle + 1)",
                menge: eintrag.0,
                einzelpreis: eintrag.1,
                umsatzsteuersatz: eintrag.2
            )
            neu.rechnung = rechnung
            rechnung.posten?.append(neu)
        }
        return rechnung
    }
}
