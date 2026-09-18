import Foundation

/// Kirchensteuersatz je nach Bundesland: 8 % in Bayern und Baden-Württemberg, sonst 9 %.
enum Kirchensteuersatz: String, CaseIterable, Codable, Identifiable, Sendable {
    case keine
    case achtProzent
    case neunProzent

    var id: String { rawValue }

    var satz: Decimal {
        switch self {
        case .keine: 0
        case .achtProzent: Decimal(8) / 100
        case .neunProzent: Decimal(9) / 100
        }
    }

    var bezeichnung: String {
        switch self {
        case .keine: "Keine Kirchensteuer"
        case .achtProzent: "8 % (Bayern, Baden-Württemberg)"
        case .neunProzent: "9 % (übrige Bundesländer)"
        }
    }
}

enum Kirchensteuer {
    /// - Note: Bemessungsgrundlage ist die Einkommensteuer. Bei Steuerpflichtigen mit Kindern
    ///   ist stattdessen die Steuer unter Beruecksichtigung der Kinderfreibeträge anzusetzen;
    ///   diese Verfeinerung bildet die App bewusst nicht ab (siehe README, "Bewusste Vereinfachungen").
    static func betrag(einkommensteuer: Decimal, satz: Kirchensteuersatz) -> Decimal {
        (einkommensteuer * satz.satz).gerundet()
    }
}
