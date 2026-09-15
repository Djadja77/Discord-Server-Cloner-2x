import Foundation

/// Einheitliche Formatierung fuer Geld, Prozent und Datum - deutsche Schreibweise.
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

    static let eingabe: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "de_DE")
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        f.generatesDecimalNumbers = true
        return f
    }()

    static func euro(_ betrag: Decimal, mitCent: Bool = true) -> String {
        let formatter = mitCent ? waehrung : waehrungOhneCent
        return formatter.string(from: betrag as NSDecimalNumber) ?? "-"
    }

    /// Mit fuehrendem Plus oder Minus - fuer Salden, bei denen die Richtung zaehlt.
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
    /// Belege laeuft ueber `Calendar.kalender`, und beide muessen dasselbe Datum zeigen.
    static let datumsformat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeZone = Calendar.kalender.timeZone
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()

    static func datum(_ wert: Date) -> String { datumsformat.string(from: wert) }

    /// Sortierbares Datum fuer Dateinamen: `2025-03-14`.
    static let dateinamendatum: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = Calendar.kalender.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
