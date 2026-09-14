import Foundation
import SwiftData

/// Rechtsform der Taetigkeit - entscheidet ueber die Gewerbesteuer.
enum Taetigkeitsart: String, CaseIterable, Codable, Identifiable, Sendable {
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

/// Die persoenlichen Rahmendaten - einmal eingerichtet, danach selten geaendert.
///
/// Es existiert genau ein Profil pro Installation; `Datenbank.profil(in:)` legt es bei
/// Bedarf an.
@Model
final class Steuerprofil {

    var taetigkeitsartCode: String = Taetigkeitsart.freiberuflich.rawValue
    var veranlagungsartCode: String = Veranlagungsart.einzel.rawValue
    var kirchensteuersatzCode: String = Kirchensteuersatz.keine.rawValue

    /// § 19 UStG: keine Umsatzsteuer auf Rechnungen, dafuer auch kein Vorsteuerabzug.
    var kleinunternehmer: Bool = false

    /// Gewerbesteuer-Hebesatz der Gemeinde in Prozent (nur bei gewerblicher Taetigkeit).
    var gewerbesteuerHebesatz: Decimal = Decimal(400)

    /// Weitere Einkuenfte, die nicht ueber die Belege erfasst werden
    /// (Arbeitslohn, Vermietung, Kapitalertraege ueber dem Sparerpauschbetrag).
    var weitereEinkuenfte: Decimal = Decimal(0)

    // Vorsorgeaufwendungen
    var beitragAltersvorsorge: Decimal = Decimal(0)
    var beitragKrankenPflegeBasis: Decimal = Decimal(0)
    var beitragSonstigeVersicherungen: Decimal = Decimal(0)

    /// Uebrige Sonderausgaben: Spenden, Kirchensteuer des Vorjahres, Unterhaltsleistungen.
    var weitereSonderausgaben: Decimal = Decimal(0)

    /// Aussergewoehnliche Belastungen nach Abzug der zumutbaren Belastung.
    var aussergewoehnlicheBelastungen: Decimal = Decimal(0)

    /// Bereits geleistete Einkommensteuer-Vorauszahlungen des laufenden Jahres.
    var geleisteteVorauszahlungen: Decimal = Decimal(0)

    /// Anteil des Gewinns, den die App als Ruecklage empfiehlt, falls keine Schaetzung
    /// moeglich ist (Standard 30 %).
    var ruecklagenGrundquote: Double = 0.30

    init() {}

    var taetigkeitsart: Taetigkeitsart {
        get { Taetigkeitsart(rawValue: taetigkeitsartCode) ?? .freiberuflich }
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

    var vorsorgeaufwendungen: Vorsorgeaufwendungen {
        Vorsorgeaufwendungen(
            altersvorsorge: beitragAltersvorsorge,
            krankenUndPflegeBasis: beitragKrankenPflegeBasis,
            sonstigeVersicherungen: beitragSonstigeVersicherungen
        )
    }
}
