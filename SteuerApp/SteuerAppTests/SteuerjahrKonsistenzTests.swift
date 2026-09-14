import XCTest
@testable import SteuerApp

/// Prueft jedes hinterlegte Steuerjahr gegen die gesetzlichen Eckwerte des Tarifs.
///
/// Der Einkommensteuertarif ist so konstruiert, dass der Grenzsteuersatz am Ende der ersten
/// Progressionszone exakt 23,97 % und am Ende der zweiten exakt 42 % betraegt. Diese beiden
/// Bedingungen verknuepfen die Tarifkonstanten miteinander: ein Zahlendreher in einer der
/// Konstanten verletzt sie sofort. Damit faengt dieser Test genau den Fehler ab, der beim
/// jaehrlichen Nachtragen der Werte am wahrscheinlichsten ist.
final class SteuerjahrKonsistenzTests: XCTestCase {

    func testJedesJahrTrifftDieGesetzlichenEckwerte() {
        for jahr in Steuerjahr.alle {
            let t = jahr.tarif

            // Grenzsteuersatz am Ende der Zone 2: 2 * a2 * y + 1400, bezogen auf 10.000 Euro.
            let y = (t.endeZone2 - t.grundfreibetrag).alsDouble / 10_000
            let grenzsatzZone2 = (2 * t.faktorZone2 * y + 1_400) / 10_000
            XCTAssertEqual(grenzsatzZone2, 0.2397, accuracy: 0.0001,
                           "Eckwert Zone 2 im Jahr \(jahr.jahr)")

            // Grenzsteuersatz am Ende der Zone 3 muss in die Proportionalzone passen.
            let z = (t.endeZone3 - t.endeZone2).alsDouble / 10_000
            let grenzsatzZone3 = (2 * t.faktorZone3 * z + 2_397) / 10_000
            XCTAssertEqual(grenzsatzZone3, 0.42, accuracy: 0.0001,
                           "Eckwert Zone 3 im Jahr \(jahr.jahr)")

            // Der Sockelbetrag der Zone 3 ist die Steuer am Ende der Zone 2.
            let steuerAmEndeZone2 = (t.faktorZone2 * y + 1_400) * y
            XCTAssertEqual(t.sockelZone3, steuerAmEndeZone2, accuracy: 0.05,
                           "Sockelbetrag Zone 3 im Jahr \(jahr.jahr)")
        }
    }

    func testTarifIstInJedemJahrStetig() {
        for jahr in Steuerjahr.alle {
            let tarif = Einkommensteuertarif(steuerjahr: jahr)
            for grenze in [jahr.tarif.endeZone2, jahr.tarif.endeZone3, jahr.tarif.endeZone4] {
                let sprung = tarif.grundtarif(grenze + 1) - tarif.grundtarif(grenze)
                XCTAssertLessThanOrEqual(sprung, 1,
                                         "Sprung bei \(grenze) im Jahr \(jahr.jahr)")
            }
        }
    }

    func testGrundfreibetraegeSteigenVonJahrZuJahr() {
        let sortiert = Steuerjahr.alle.sorted { $0.jahr < $1.jahr }
        for (vorher, nachher) in zip(sortiert, sortiert.dropFirst()) {
            XCTAssertGreaterThan(nachher.tarif.grundfreibetrag, vorher.tarif.grundfreibetrag,
                                 "Grundfreibetrag \(nachher.jahr)")
            XCTAssertGreaterThan(nachher.soliFreigrenze, vorher.soliFreigrenze,
                                 "Soli-Freigrenze \(nachher.jahr)")
        }
    }

    func testGleicherGewinnWirdVonJahrZuJahrNichtHoeherBesteuert() {
        // Die Tarifanpassungen gleichen die kalte Progression aus - bei gleichem Einkommen
        // darf die Steuer daher nicht steigen.
        let sortiert = Steuerjahr.alle.sorted { $0.jahr < $1.jahr }
        for zve in [Decimal(20_000), 45_000, 80_000, 150_000] {
            for (vorher, nachher) in zip(sortiert, sortiert.dropFirst()) {
                let alt = Einkommensteuertarif(steuerjahr: vorher).grundtarif(zve)
                let neu = Einkommensteuertarif(steuerjahr: nachher).grundtarif(zve)
                XCTAssertLessThanOrEqual(neu, alt, "zvE \(zve) von \(vorher.jahr) zu \(nachher.jahr)")
            }
        }
    }

    func testUnbekanntesJahrFaelltAufDasNaechstgelegeneZurueck() {
        XCTAssertEqual(Steuerjahr.fuer(2025).jahr, 2025)
        XCTAssertEqual(Steuerjahr.fuer(2030).jahr, 2026, "neuestes hinterlegtes Jahr")
        XCTAssertEqual(Steuerjahr.fuer(2010).jahr, 2024, "aeltestes hinterlegtes Jahr")
    }
}
