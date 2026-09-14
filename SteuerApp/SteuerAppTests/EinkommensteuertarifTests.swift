import XCTest
@testable import SteuerApp

/// Tests des Einkommensteuertarifs nach § 32a EStG.
///
/// Die mit "amtliche Grundtabelle" gekennzeichneten Werte stammen aus der veroeffentlichten
/// Einkommensteuer-Grundtabelle 2025. Die uebrigen Werte sind Regressionsanker: sie halten
/// das Verhalten fest, damit eine spaetere Aenderung am Tarif nicht unbemerkt durchrutscht.
final class EinkommensteuertarifTests: XCTestCase {

    private let tarif = Einkommensteuertarif(steuerjahr: .jahr2025)

    // MARK: - Amtliche Vergleichswerte

    func testGrundtarifTrifftAmtlicheGrundtabelle2025() {
        XCTAssertEqual(tarif.grundtarif(20_000), 1_639)
        XCTAssertEqual(tarif.grundtarif(100_000), 31_088)
    }

    // MARK: - Zonen

    func testBisZumGrundfreibetragFaelltKeineSteuerAn() {
        XCTAssertEqual(tarif.grundtarif(0), 0)
        XCTAssertEqual(tarif.grundtarif(5_000), 0)
        XCTAssertEqual(tarif.grundtarif(12_096), 0, "Grundfreibetrag 2025")
        // Der erste Euro darueber loest wegen der Abrundung noch keine volle Euro-Steuer aus.
        XCTAssertEqual(tarif.grundtarif(12_097), 0)
    }

    func testTarifzonenLiefernDieErwartetenBetraege() {
        XCTAssertEqual(tarif.grundtarif(13_000), 134, "erste Progressionszone")
        XCTAssertEqual(tarif.grundtarif(30_000), 4_303, "zweite Progressionszone")
        XCTAssertEqual(tarif.grundtarif(50_000), 10_691, "zweite Progressionszone")
        XCTAssertEqual(tarif.grundtarif(100_000), 31_088, "Proportionalzone, 42 %")
        XCTAssertEqual(tarif.grundtarif(300_000), 115_753, "Spitzenzone, 45 %")
    }

    func testTarifIstAnDenZonengrenzenStetig() {
        // An den Uebergaengen darf die Steuer um hoechstens einen Euro springen -
        // mehr waere ein Tippfehler in den Tarifkonstanten.
        for grenze in [Decimal(17_443), Decimal(68_480), Decimal(277_825)] {
            let davor = tarif.grundtarif(grenze)
            let danach = tarif.grundtarif(grenze + 1)
            XCTAssertLessThanOrEqual(danach - davor, 1,
                                     "Sprung an der Zonengrenze \(grenze)")
        }
    }

    func testDieAbrundungAufVolleEuroWirdAngewendet() {
        // § 32a EStG rundet Bemessungsgrundlage und Ergebnis auf volle Euro ab.
        XCTAssertEqual(tarif.grundtarif(Decimal(string: "50000.99")!), tarif.grundtarif(50_000))
    }

    // MARK: - Splitting

    func testSplittingHalbiertVersteuertUndVerdoppelt() {
        let zve: Decimal = 80_000
        let mitSplitting = tarif.einkommensteuer(zuVersteuerndesEinkommen: zve, splitting: true)
        XCTAssertEqual(mitSplitting, tarif.grundtarif(40_000) * 2)
        XCTAssertEqual(mitSplitting, 14_640)
    }

    func testSplittingIstNieTeurerAlsDerGrundtarif() {
        for zve in stride(from: 10_000, through: 300_000, by: 10_000) {
            let betrag = Decimal(zve)
            let grund = tarif.einkommensteuer(zuVersteuerndesEinkommen: betrag, splitting: false)
            let split = tarif.einkommensteuer(zuVersteuerndesEinkommen: betrag, splitting: true)
            XCTAssertLessThanOrEqual(split, grund, "Splittingvorteil bei zvE \(zve)")
        }
    }

    // MARK: - Eigenschaften

    func testSteuerWaechstMonotonMitDemEinkommen() {
        var vorher: Decimal = 0
        for zve in stride(from: 0, through: 400_000, by: 500) {
            let jetzt = tarif.grundtarif(Decimal(zve))
            XCTAssertGreaterThanOrEqual(jetzt, vorher, "Ruecksprung bei zvE \(zve)")
            vorher = jetzt
        }
    }

    func testSteuerUebersteigtNieDasEinkommen() {
        for zve in stride(from: 1_000, through: 500_000, by: 1_000) {
            let betrag = Decimal(zve)
            XCTAssertLessThan(tarif.grundtarif(betrag), betrag)
        }
    }

    func testGrenzsteuersatzErreichtDieGesetzlichenEckwerte() {
        XCTAssertEqual(tarif.grenzsteuersatz(zuVersteuerndesEinkommen: 100_000, splitting: false),
                       0.42, accuracy: 0.005, "Proportionalzone")
        XCTAssertEqual(tarif.grenzsteuersatz(zuVersteuerndesEinkommen: 400_000, splitting: false),
                       0.45, accuracy: 0.005, "Spitzenzone")
        XCTAssertEqual(tarif.grenzsteuersatz(zuVersteuerndesEinkommen: 5_000, splitting: false),
                       0.0, accuracy: 0.001, "Grundfreibetrag")
    }

    func testDurchschnittssatzLiegtUnterDemGrenzsatz() {
        for zve in [Decimal(20_000), 50_000, 100_000, 250_000] {
            let durchschnitt = tarif.durchschnittssteuersatz(
                zuVersteuerndesEinkommen: zve, splitting: false)
            let grenze = tarif.grenzsteuersatz(zuVersteuerndesEinkommen: zve, splitting: false)
            XCTAssertLessThan(durchschnitt, grenze, "bei zvE \(zve)")
        }
    }

    func testNegativesEinkommenErzeugtKeineSteuer() {
        XCTAssertEqual(tarif.einkommensteuer(zuVersteuerndesEinkommen: -5_000, splitting: false), 0)
        XCTAssertEqual(tarif.einkommensteuer(zuVersteuerndesEinkommen: -5_000, splitting: true), 0)
    }
}
