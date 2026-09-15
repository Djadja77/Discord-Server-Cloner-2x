import Foundation
import SwiftData

/// Rechtsform der Tätigkeit - entscheidet über die Gewerbesteuer.
enum Tätigkeitsart: String, CaseIterable, Codable, Identifiable, Sendable {
    /// § 18 EStG - keine Gewerbesteuer.
    case freiberuflich
    /// § 15 EStG - Gewerbesteuer ab einem Gewinn von 24.500 Euro.
    case gewerblich

    var id: String { rawValue }

    var bezeichnung: String {
        switch self {
        case .freiberuflich: "Freiberuflich (§ 18 EStG)"
        case .gewerblich: "Gewerbebetrieb (§ 15 EStG)"
        }
    }
}

enum Veranlagungsart: String, CaseIterable, Codable, Identifiable, Sendable {
    case einzel
    case zusammen

    var id: String { rawValue }

    var bezeichnung: String {
        switch self {
        case .einzel: "Einzelveranlagung"
        case .zusammen: "Zusammenveranlagung (Splitting)"
        }
    }

    var splitting: Bool { self == .zusammen }
}

/// Angaben, die sich von Jahr zu Jahr nicht ändern.
///
/// Alles, was jährlich neu ist - Beiträge, Vorauszahlungen, Kinder, Verlustvortrag -
/// steht in `Jahresangaben`. Diese Trennung ist der Grund, warum ein Wechsel des
/// Steuerjahres in der App nicht die Zahlen des Vorjahres überschreibt.
///
/// - Note: Die Namen der gespeicherten Eigenschaften bleiben ohne Umlaute. SwiftData legt
///   sie als Feldnamen in der Datenbank ab, und dort gehören nur ASCII-Zeichen hin -
///   ein `ä` im Feldnamen bringt den Aufbau des Containers zum Absturz. Alles, was auf dem
///   Bildschirm erscheint, trägt dagegen selbstverständlich Umlaute.
@Model
final class Steuerprofil {

    var taetigkeitsartCode: String = Tätigkeitsart.freiberuflich.rawValue
    var veranlagungsartCode: String = Veranlagungsart.einzel.rawValue
    var kirchensteuersatzCode: String = Kirchensteuersatz.keine.rawValue

    /// § 19 UStG: keine Umsatzsteuer auf Rechnungen, dafür auch kein Vorsteuerabzug.
    var kleinunternehmer: Bool = false

    /// Gewerbesteuer-Hebesatz der Gemeinde in Prozent (nur bei gewerblicher Tätigkeit).
    var gewerbesteuerHebesatz: Decimal = Decimal(400)

    init() {}

    var tätigkeitsart: Tätigkeitsart {
        get { Tätigkeitsart(rawValue: taetigkeitsartCode) ?? .freiberuflich }
        set { taetigkeitsartCode = newValue.rawValue }
    }

    var veranlagungsart: Veranlagungsart {
        get { Veranlagungsart(rawValue: veranlagungsartCode) ?? .einzel }
        set { veranlagungsartCode = newValue.rawValue }
    }

    var kirchensteuersatz: Kirchensteuersatz {
        get { Kirchensteuersatz(rawValue: kirchensteuersatzCode) ?? .keine }
        set { kirchensteuersatzCode = newValue.rawValue }
    }
}
