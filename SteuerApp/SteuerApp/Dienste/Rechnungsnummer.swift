import Foundation

/// Vergibt Rechnungsnummern.
///
/// § 14 Abs. 4 Nr. 4 UStG verlangt eine fortlaufende Nummer, die der Aussteller
/// **einmalig** vergibt. Einmalig heißt: keine Nummer zweimal, auch nicht nach einem
/// Storno und nicht nach dem Löschen eines Entwurfs. Deshalb zählt der Kreis nur
/// vorwärts und wird erst in dem Moment erhöht, in dem eine Rechnung wirklich gestellt
/// wird - ein verworfener Entwurf reißt sonst eine Lücke, die man in einer Prüfung
/// erklären muss.
///
/// Der Kreis beginnt in jedem Jahr neu. Das ist die verbreitete Wahl, macht die Nummer
/// selbst sprechend ("2026-0042") und hält die Zahlen klein.
enum Rechnungsnummer {

    /// Wie die Nummer aussieht.
    static func formatiert(jahr: Int, laufend: Int) -> String {
        String(format: "%d-%04d", jahr, laufend)
    }

    /// Der höchste bisher vergebene Stand des Jahres.
    static func stand(fuer jahr: Int, in kreis: String) -> Int {
        gelesen(kreis)[jahr] ?? 0
    }

    /// Welche Nummer die nächste Rechnung bekäme - ohne sie zu vergeben.
    ///
    /// Für die Vorschau im Entwurf: dort soll die Nummer schon zu sehen sein, ohne dass
    /// ein verworfener Entwurf sie verbraucht.
    static func vorschau(fuer jahr: Int, in kreis: String) -> String {
        formatiert(jahr: jahr, laufend: stand(fuer: jahr, in: kreis) + 1)
    }

    /// Vergibt die nächste Nummer und schreibt den neuen Stand zurück.
    static func vergeben(fuer jahr: Int, in kreis: String) -> (nummer: String, laufend: Int, kreis: String) {
        var stände = gelesen(kreis)
        let laufend = (stände[jahr] ?? 0) + 1
        stände[jahr] = laufend
        return (formatiert(jahr: jahr, laufend: laufend), laufend, geschrieben(stände))
    }

    // MARK: - Speicherform

    /// "2026:42;2025:118" - je Jahr ein Stand.
    static func gelesen(_ kreis: String) -> [Int: Int] {
        var stände: [Int: Int] = [:]
        for eintrag in kreis.split(separator: ";") {
            let teile = eintrag.split(separator: ":")
            guard teile.count == 2, let jahr = Int(teile[0]), let stand = Int(teile[1]) else { continue }
            stände[jahr] = max(stände[jahr] ?? 0, stand)
        }
        return stände
    }

    static func geschrieben(_ stände: [Int: Int]) -> String {
        stände
            .filter { $0.value > 0 }
            .sorted { $0.key > $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: ";")
    }
}
