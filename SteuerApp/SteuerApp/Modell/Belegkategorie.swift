import Foundation

/// Ob ein Beleg Geld bringt oder Geld kostet.
enum Belegart: String, CaseIterable, Codable, Identifiable, Sendable {
    case einnahme
    case ausgabe

    var id: String { rawValue }

    var bezeichnung: String {
        switch self {
        case .einnahme: "Einnahme"
        case .ausgabe: "Ausgabe"
        }
    }

    var symbol: String {
        switch self {
        case .einnahme: "arrow.down.circle.fill"
        case .ausgabe: "arrow.up.circle.fill"
        }
    }
}

/// Kategorien der Einnahmen-Ueberschuss-Rechnung, angelehnt an die Anlage EUER.
///
/// Die `euerZeile` ist ein Hinweis darauf, in welche Zeile der Anlage EUER die Summe gehoert.
/// Die Zeilennummern verschieben sich von Jahr zu Jahr leicht - sie sind als Orientierung
/// gedacht, nicht als amtliche Zuordnung.
enum Belegkategorie: String, CaseIterable, Codable, Identifiable, Sendable {

    // Betriebseinnahmen
    case umsatzerloese
    case sonstigeErloese
    case anlagenverkauf
    case privatentnahmeSachleistung

    // Betriebsausgaben
    case wareneinkauf
    case fremdleistungen
    case personalkosten
    case abschreibung
    case geringwertigeWirtschaftsgueter
    case raumkosten
    case arbeitszimmer
    case versicherungenBeitraege
    case kfzKosten
    case reisekosten
    case verpflegungsmehraufwand
    case bewirtung
    case werbung
    case telefonInternet
    case buerobedarf
    case fachliteraturFortbildung
    case portoVersand
    case rechtsUndSteuerberatung
    case bankgebuehren
    case zinsen
    case softwareAbos
    case sonstigeAusgaben

    var id: String { rawValue }

    var art: Belegart {
        switch self {
        case .umsatzerloese, .sonstigeErloese, .anlagenverkauf, .privatentnahmeSachleistung:
            .einnahme
        default:
            .ausgabe
        }
    }

    var bezeichnung: String {
        switch self {
        case .umsatzerloese: "Umsatzerloese"
        case .sonstigeErloese: "Sonstige betriebliche Einnahmen"
        case .anlagenverkauf: "Verkauf von Anlagevermoegen"
        case .privatentnahmeSachleistung: "Private Nutzung / Sachentnahme"
        case .wareneinkauf: "Wareneinkauf / Material"
        case .fremdleistungen: "Fremdleistungen"
        case .personalkosten: "Personalkosten"
        case .abschreibung: "Abschreibungen (AfA)"
        case .geringwertigeWirtschaftsgueter: "Geringwertige Wirtschaftsgueter"
        case .raumkosten: "Raumkosten (eigene Betriebsraeume)"
        case .arbeitszimmer: "Haeusliches Arbeitszimmer"
        case .versicherungenBeitraege: "Betriebliche Versicherungen und Beitraege"
        case .kfzKosten: "Fahrzeugkosten"
        case .reisekosten: "Reisekosten"
        case .verpflegungsmehraufwand: "Verpflegungsmehraufwand"
        case .bewirtung: "Bewirtung"
        case .werbung: "Werbung und Marketing"
        case .telefonInternet: "Telefon und Internet"
        case .buerobedarf: "Buerobedarf"
        case .fachliteraturFortbildung: "Fachliteratur und Fortbildung"
        case .portoVersand: "Porto und Versand"
        case .rechtsUndSteuerberatung: "Rechts- und Steuerberatung"
        case .bankgebuehren: "Kontofuehrung und Gebuehren"
        case .zinsen: "Zinsen fuer betriebliche Darlehen"
        case .softwareAbos: "Software und Abonnements"
        case .sonstigeAusgaben: "Uebrige Betriebsausgaben"
        }
    }

    var symbol: String {
        switch self {
        case .umsatzerloese: "eurosign.circle"
        case .sonstigeErloese: "plus.circle"
        case .anlagenverkauf: "shippingbox"
        case .privatentnahmeSachleistung: "house"
        case .wareneinkauf: "cart"
        case .fremdleistungen: "person.2"
        case .personalkosten: "person.3"
        case .abschreibung: "chart.line.downtrend.xyaxis"
        case .geringwertigeWirtschaftsgueter: "wrench.and.screwdriver"
        case .raumkosten: "building.2"
        case .arbeitszimmer: "lamp.desk"
        case .versicherungenBeitraege: "shield"
        case .kfzKosten: "car"
        case .reisekosten: "airplane"
        case .verpflegungsmehraufwand: "fork.knife"
        case .bewirtung: "wineglass"
        case .werbung: "megaphone"
        case .telefonInternet: "wifi"
        case .buerobedarf: "paperclip"
        case .fachliteraturFortbildung: "book"
        case .portoVersand: "envelope"
        case .rechtsUndSteuerberatung: "briefcase"
        case .bankgebuehren: "banknote"
        case .zinsen: "percent"
        case .softwareAbos: "laptopcomputer"
        case .sonstigeAusgaben: "ellipsis.circle"
        }
    }

    /// Anteil der Netto-Ausgabe, der als Betriebsausgabe abziehbar ist.
    ///
    /// Bewirtungskosten sind nach § 4 Abs. 5 Satz 1 Nr. 2 EStG nur zu 70 % abziehbar.
    /// Die Vorsteuer bleibt davon unberuehrt und ist zu 100 % abziehbar - genau so
    /// rechnet `EinnahmenUeberschussRechnung`.
    var abzugsfaehigerAnteil: Decimal {
        switch self {
        case .bewirtung: Decimal(7) / 10
        default: 1
        }
    }

    /// Hinweis auf die Zeile der Anlage EUER (Orientierungswert, hier fuer 2024/2025).
    var euerZeile: Int? {
        switch self {
        case .umsatzerloese: 14
        case .sonstigeErloese: 17
        case .anlagenverkauf: 18
        case .privatentnahmeSachleistung: 19
        case .wareneinkauf: 26
        case .fremdleistungen: 27
        case .personalkosten: 28
        case .abschreibung: 32
        case .geringwertigeWirtschaftsgueter: 35
        case .raumkosten: 47
        case .arbeitszimmer: 48
        case .versicherungenBeitraege: 50
        case .kfzKosten: 61
        case .reisekosten: 66
        case .verpflegungsmehraufwand: 67
        case .bewirtung: 68
        case .werbung: 69
        case .zinsen: 55
        case .rechtsUndSteuerberatung: 59
        case .telefonInternet, .buerobedarf, .fachliteraturFortbildung,
             .portoVersand, .bankgebuehren, .softwareAbos, .sonstigeAusgaben: 71
        }
    }

    /// Kurzer Hinweis, der in der Belegmaske unter dem Kategoriefeld erscheint.
    var hinweis: String? {
        switch self {
        case .bewirtung:
            "Nur 70 % sind abziehbar. Bewirtungsbeleg mit Anlass und Teilnehmern aufbewahren."
        case .verpflegungsmehraufwand:
            "Nur Pauschbetraege ansetzen, keine Einzelbelege. Ohne Vorsteuerabzug."
        case .arbeitszimmer:
            "Nur bei Mittelpunkt der Taetigkeit voll abziehbar, sonst Jahrespauschale pruefen."
        case .kfzKosten:
            "Bei gemischter Nutzung den betrieblichen Anteil eintragen oder Fahrtenbuch fuehren."
        case .geringwertigeWirtschaftsgueter:
            "Bis 800 Euro netto sofort abziehbar, darueber ueber die Nutzungsdauer abschreiben."
        case .privatentnahmeSachleistung:
            "Private Nutzung betrieblicher Gueter erhoeht den Gewinn."
        default:
            nil
        }
    }

    static var einnahmekategorien: [Belegkategorie] { allCases.filter { $0.art == .einnahme } }
    static var ausgabekategorien: [Belegkategorie] { allCases.filter { $0.art == .ausgabe } }
}
