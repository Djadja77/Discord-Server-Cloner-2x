import Foundation

/// Einheitliche Formatierung für Geld, Prozent und Datum - deutsche Schreibweise.
enum Formatierung {

    static let waehrung: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.locale = Locale(identifier: "de_DE")
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()

    static let waehrungOhneCent: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.locale = Locale(identifier: "de_DE")
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f
    }()

    /// Für Eingabefelder: ohne Tausenderpunkte und ohne Währungszeichen.
    ///
    /// Beides gehört nicht in ein Feld, in dem gerade getippt wird. Ein Währungs-
    /// zeichen mitten im Text wandert beim Tippen mit und landet zwischen den
    /// Ziffern; Tausenderpunkte muss man beim Bearbeiten mit umständlich umschiffen.
    static let eingabe: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "de_DE")
        f.usesGroupingSeparator = false
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        f.generatesDecimalNumbers = true
        return f
    }()

    /// Ein Betrag so, wie er sich bearbeiten lässt.
    ///
    /// Bei null kommt eine leere Zeichenkette zurück, nicht "0,00": sonst muss man
    /// erst eine Null wegwischen, bevor man etwas eintippen kann.
    static func zumBearbeiten(_ betrag: Decimal) -> String {
        guard betrag != 0 else { return "" }
        return eingabe.string(from: betrag as NSDecimalNumber) ?? ""
    }

    /// Liest, was jemand in ein Geldfeld getippt hat.
    ///
    /// Der Punkt gilt als Tausendertrennzeichen und fliegt raus, das Komma ist das
    /// Dezimaltrennzeichen - deutsche Schreibweise. Alles andere (Währungszeichen,
    /// Leerzeichen, Buchstaben aus einer anderen Tastatur) wird verworfen, statt die
    /// Eingabe abzulehnen: ein Feld, das bei einem Tippfehler stumm auf null springt,
    /// ist schlimmer als eines, das das Beste daraus macht.
    static func betragAusEingabe(_ text: String) -> Decimal {
        let ziffernUndTrenner = text.filter { $0.isNumber || $0 == "," || $0 == "." }
        let ohneTausender = ziffernUndTrenner.replacingOccurrences(of: ".", with: "")
        var mitPunkt = ohneTausender.replacingOccurrences(of: ",", with: ".")

        // Angefangene Eingaben: "12," und ",5" sind Zwischenstände beim Tippen und
        // stehen für 12 und 0,5. Ohne diese beiden Zeilen lehnte das Lesen sie ab und
        // der Betrag spränge mitten im Tippen auf null.
        if mitPunkt.hasSuffix(".") { mitPunkt.removeLast() }
        if mitPunkt.hasPrefix(".") { mitPunkt = "0" + mitPunkt }

        guard !mitPunkt.isEmpty else { return 0 }
        return Decimal(string: mitPunkt) ?? 0
    }

    static func euro(_ betrag: Decimal, mitCent: Bool = true) -> String {
        let formatter = mitCent ? waehrung : waehrungOhneCent
        return formatter.string(from: betrag as NSDecimalNumber) ?? "-"
    }

    /// Mit führendem Plus oder Minus - für Salden, bei denen die Richtung zählt.
    static func euroMitVorzeichen(_ betrag: Decimal, mitCent: Bool = true) -> String {
        let text = euro(abs(betrag), mitCent: mitCent)
        if betrag > 0 { return "+" + text }
        if betrag < 0 { return "-" + text }
        return text
    }

    static func prozent(_ anteil: Double, nachkommastellen: Int = 1) -> String {
        String(format: "%.\(nachkommastellen)f %%", anteil * 100)
            .replacingOccurrences(of: ".", with: ",")
    }

    /// Zeitzone bewusst fest auf Europe/Berlin: die Jahres- und Quartalszuordnung der
    /// Belege laeuft über `Calendar.kalender`, und beide müssen dasselbe Datum zeigen.
    static let datumsformat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeZone = Calendar.kalender.timeZone
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()

    static func datum(_ wert: Date) -> String { datumsformat.string(from: wert) }

    /// Sortierbares Datum für Dateinamen: `2025-03-14`.
    static let dateinamendatum: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = Calendar.kalender.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
