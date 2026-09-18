import XCTest
@testable import SteuerApp

/// Tests der Betragseingabe.
///
/// Anlass war ein Feld, das während des Tippens als Währung formatierte: im Feld stand
/// "3,00 €", die nächste Ziffer landete dahinter, und heraus kam "3,00 €00". Die Regeln
/// stehen jetzt in `Formatierung` und sind hier festgehalten - besonders die Fälle, in
/// denen eine Eingabe nicht sauber ist. Ein Geldfeld, das bei einem Tippfehler stumm auf
/// null springt, verfälscht eine Steuererklärung.
final class BetragseingabeTests: XCTestCase {

    func testLiestDeutscheSchreibweise() {
        XCTAssertEqual(Formatierung.betragAusEingabe("3"), 3)
        XCTAssertEqual(Formatierung.betragAusEingabe("1500,5"), Decimal(string: "1500.5"))
        XCTAssertEqual(Formatierung.betragAusEingabe("0,99"), Decimal(string: "0.99"))
    }

    /// Der Punkt trennt Tausender, nicht Dezimalstellen - sonst würden aus 1.500 Euro
    /// eineinhalb.
    func testPunktIstTausendertrenner() {
        XCTAssertEqual(Formatierung.betragAusEingabe("1.500"), 1500)
        XCTAssertEqual(Formatierung.betragAusEingabe("1.500,50"), Decimal(string: "1500.5"))
        XCTAssertEqual(Formatierung.betragAusEingabe("12.345.678"), 12_345_678)
    }

    func testVerwirftWasNichtZurZahlGehoert() {
        XCTAssertEqual(Formatierung.betragAusEingabe("1500 €"), 1500)
        XCTAssertEqual(Formatierung.betragAusEingabe("EUR 1500"), 1500)
        // Genau der Text, der durch den alten Fehler entstand.
        XCTAssertEqual(Formatierung.betragAusEingabe("3,00 €00"), 3)
    }

    func testLeereUndUnvollstaendigeEingabe() {
        XCTAssertEqual(Formatierung.betragAusEingabe(""), 0)
        XCTAssertEqual(Formatierung.betragAusEingabe(","), 0)
        XCTAssertEqual(Formatierung.betragAusEingabe("abc"), 0)
        // Beim Tippen von "12,5" liegt dieser Zwischenstand vor - er darf nicht auf
        // null springen, sonst rechnet die Schätzung zwischendurch mit nichts.
        XCTAssertEqual(Formatierung.betragAusEingabe("12,"), 12)
        XCTAssertEqual(Formatierung.betragAusEingabe(",5"), Decimal(string: "0.5"))
    }

    /// Null wird zum Bearbeiten leer dargestellt: sonst muss man erst eine Null
    /// wegwischen, bevor man etwas eintippen kann.
    func testNullWirdLeerZumBearbeiten() {
        XCTAssertEqual(Formatierung.zumBearbeiten(0), "")
    }

    /// Im Eingabefeld stehen weder Währungszeichen noch Tausenderpunkte - beide
    /// wandern beim Tippen mit und landen zwischen den Ziffern.
    func testBearbeitenOhneTrennerUndWaehrung() {
        XCTAssertEqual(Formatierung.zumBearbeiten(1500), "1500")
        XCTAssertEqual(Formatierung.zumBearbeiten(Decimal(string: "1500.5")!), "1500,5")
    }

    /// Was aus dem Feld herausgelesen und wieder hineingeschrieben wird, muss
    /// derselbe Betrag bleiben - sonst verändert schon das Antippen eines Feldes
    /// den Wert.
    func testHinUndZurueckAendertNichts() {
        for betrag in [Decimal(0), 7, 1500, Decimal(string: "1234.56")!, Decimal(string: "0.07")!] {
            let bearbeitbar = Formatierung.zumBearbeiten(betrag)
            XCTAssertEqual(Formatierung.betragAusEingabe(bearbeitbar), betrag,
                           "Betrag \(betrag) über \"\(bearbeitbar)\" verändert")
        }
    }
}
