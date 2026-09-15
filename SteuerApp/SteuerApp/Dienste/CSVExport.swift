import Foundation
import SwiftData

/// Export der Belege und der Jahresauswertung als CSV.
///
/// Semikolon als Trennzeichen und Komma als Dezimaltrennzeichen - so öffnet Excel in
/// deutscher Einstellung die Datei ohne Nachfrage. Die Datei beginnt mit einer
/// UTF-8-Byte-Order-Mark, damit Umlaute korrekt ankommen.
enum CSVExport {

    private static let trenner = ";"

    /// Immer zwei Nachkommastellen, Komma als Dezimaltrenner, keine Tausenderpunkte -
    /// so liest Excel die Spalte als Zahl und nicht als Text.
    private static let zahlformat: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = false
        return f
    }()

    private static func zahl(_ betrag: Decimal) -> String {
        zahlformat.string(from: betrag.gerundet() as NSDecimalNumber) ?? "0,00"
    }

    private static func feld(_ text: String) -> String {
        let bereinigt = text.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(bereinigt)\""
    }

    private static func zeile(_ felder: [String]) -> String {
        felder.joined(separator: trenner)
    }

    /// Alle Belege eines Jahres - eine Zeile je Beleg.
    ///
    /// - Parameter fotonamen: Zuordnung von Beleg zu Dateiname im Archiv. Wird sie
    ///   mitgegeben, nennt die letzte Spalte das zugehörige Foto - damit lässt sich jede
    ///   Zeile ohne Suchen dem Papier zuordnen.
    static func belege(
        _ belege: [Beleg],
        jahr: Int,
        fotonamen: [PersistentIdentifier: String] = [:]
    ) -> String {
        var zeilen = [zeile([
            feld("Datum"), feld("Bezeichnung"), feld("Art"), feld("Kategorie"),
            feld("EÜR-Zeile"), feld("Brutto"), feld("USt-Satz"), feld("USt-Betrag"),
            feld("Netto"), feld("Betrieblicher Anteil"), feld("Betrieblich netto"),
            feld("Beleg vorhanden"), feld("Belegdatei"), feld("Notiz"),
        ])]

        for beleg in belege.filter({ $0.jahr == jahr }).sorted(by: { $0.datum < $1.datum }) {
            zeilen.append(zeile([
                feld(Formatierung.datum(beleg.datum)),
                feld(beleg.bezeichnung),
                feld(beleg.art.bezeichnung),
                feld(beleg.kategorie.bezeichnung),
                feld(beleg.kategorie.euerZeile.map(String.init) ?? ""),
                zahl(beleg.bruttoBetrag),
                feld(beleg.umsatzsteuersatz.bezeichnung),
                zahl(beleg.umsatzsteuerBetrag),
                zahl(beleg.nettoBetrag),
                feld(Formatierung.prozent(beleg.betrieblicherAnteil, nachkommastellen: 0)),
                zahl(beleg.betrieblichesNetto),
                feld(beleg.belegbildDatei == nil ? "nein" : "ja"),
                feld(fotonamen[beleg.persistentModelID] ?? ""),
                feld(beleg.notiz),
            ]))
        }
        return zeilen.joined(separator: "\r\n")
    }

    /// Die Jahresauswertung in der Gliederung der Anlage EUER.
    static func euer(_ ergebnis: EinnahmenÜberschussRechnung.Ergebnis) -> String {
        var zeilen = [zeile([
            feld("Bereich"), feld("Kategorie"), feld("EÜR-Zeile"),
            feld("Betrag"), feld("Vor Kürzung"), feld("Belege"),
        ])]

        func block(_ titel: String, _ posten: [EinnahmenÜberschussRechnung.Posten]) {
            for p in posten {
                zeilen.append(zeile([
                    feld(titel),
                    feld(p.kategorie.bezeichnung),
                    feld(p.kategorie.euerZeile.map(String.init) ?? ""),
                    zahl(p.betrag),
                    zahl(p.betragVorKürzung),
                    String(p.anzahlBelege),
                ]))
            }
        }

        block("Betriebseinnahmen", ergebnis.einnahmen)
        block("Betriebsausgaben", ergebnis.ausgaben)

        zeilen.append(zeile([feld("Summe"), feld("Betriebseinnahmen"), "",
                             zahl(ergebnis.summeEinnahmen), "", ""]))
        zeilen.append(zeile([feld("Summe"), feld("Betriebsausgaben"), "",
                             zahl(ergebnis.summeAusgaben), "", ""]))
        zeilen.append(zeile([feld("Ergebnis"), feld("Gewinn"), "",
                             zahl(ergebnis.gewinn), "", ""]))

        return zeilen.joined(separator: "\r\n")
    }

    /// Schreibt den Text als CSV-Datei ins temporaere Verzeichnis und liefert die URL
    /// zum Teilen über den Share-Sheet.
    static func datei(inhalt: String, name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let mitBOM = "\u{FEFF}" + inhalt
        try mitBOM.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
