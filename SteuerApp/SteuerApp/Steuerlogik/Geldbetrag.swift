import Foundation

/// Rechenhilfen für Geldbeträge.
///
/// Alle Beträge in der App sind `Decimal`, damit Cent-Beträge exakt bleiben.
/// `Double` wird ausschließlich innerhalb der Tarifpolynome von `Einkommensteuertarif`
/// verwendet - dort schreibt § 32a EStG ohnehin eine Abrundung auf volle Euro vor.
extension Decimal {

    /// Auf volle Euro abgerundet (Richtung Null).
    ///
    /// Für die in dieser App auftretenden Fälle (zu versteuerndes Einkommen, Gewerbeertrag)
    /// sind die Werte nicht negativ, daher entspricht das dem gesetzlich geforderten Abrunden.
    var aufVolleEuroAbgerundet: Decimal {
        var eingabe = self
        var ergebnis = Decimal()
        NSDecimalRound(&ergebnis, &eingabe, 0, .down)
        return ergebnis
    }

    /// Kaufmaennisch auf `stellen` Nachkommastellen gerundet (Standard: Cent).
    func gerundet(stellen: Int = 2) -> Decimal {
        var eingabe = self
        var ergebnis = Decimal()
        NSDecimalRound(&ergebnis, &eingabe, stellen, .plain)
        return ergebnis
    }

    /// Auf volle 100 Euro abgerundet - vorgeschrieben für den Gewerbeertrag (§ 11 Abs. 1 GewStG).
    var aufVolle100EuroAbgerundet: Decimal {
        var eingabe = self / 100
        var hunderter = Decimal()
        NSDecimalRound(&hunderter, &eingabe, 0, .down)
        return hunderter * 100
    }

    /// Nie kleiner als null - spart im Steuerrecht viele `max(0, ...)`-Aufrufe.
    var nichtNegativ: Decimal { self < 0 ? 0 : self }

    var alsDouble: Double { (self as NSDecimalNumber).doubleValue }
}

extension Sequence where Element == Decimal {
    var summe: Decimal { reduce(0, +) }
}
