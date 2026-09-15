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

/// Kategorien der Einnahmen-Überschuss-Rechnung, angelehnt an die Anlage EUER.
///
/// Die `euerZeile` ist ein Hinweis darauf, in welche Zeile der Anlage EUER die Summe gehört.
/// Die Zeilennummern verschieben sich von Jahr zu Jahr leicht - sie sind als Orientierung
/// gedacht, nicht als amtliche Zuordnung.
enum Belegkategorie: String, CaseIterable, Codable, Identifiable, Sendable {

    // Betriebseinnahmen
    case umsatzerlöse
    case sonstigeErlöse
    case anlagenverkauf
    case privatentnahmeSachleistung

    // Betriebsausgaben
    case wareneinkauf
    case fremdleistungen
    case personalkosten
    case abschreibung
    case geringwertigeWirtschaftsgüter
    case raumkosten
    case arbeitszimmer
    case versicherungenBeiträge
    case kfzKosten
    case reisekosten
    case verpflegungsmehraufwand
    case bewirtung
    case werbung
    case telefonInternet
    case bürobedarf
    case fachliteraturFortbildung
    case portoVersand
    case rechtsUndSteuerberatung
    case bankgebühren
    case zinsen
    case softwareAbos
    case sonstigeAusgaben

    var id: String { rawValue }

    var art: Belegart {
        switch self {
        case .umsatzerlöse, .sonstigeErlöse, .anlagenverkauf, .privatentnahmeSachleistung:
            .einnahme
        default:
            .ausgabe
        }
    }

    var bezeichnung: String {
        switch self {
        case .umsatzerlöse: "Umsatzerlöse"
        case .sonstigeErlöse: "Sonstige betriebliche Einnahmen"
        case .anlagenverkauf: "Verkauf von Anlagevermögen"
        case .privatentnahmeSachleistung: "Private Nutzung / Sachentnahme"
        case .wareneinkauf: "Wareneinkauf / Material"
        case .fremdleistungen: "Fremdleistungen"
        case .personalkosten: "Personalkosten"
        case .abschreibung: "Abschreibungen (AfA)"
        case .geringwertigeWirtschaftsgüter: "Geringwertige Wirtschaftsgüter"
        case .raumkosten: "Raumkosten (eigene Betriebsräume)"
        case .arbeitszimmer: "Häusliches Arbeitszimmer"
        case .versicherungenBeiträge: "Betriebliche Versicherungen und Beiträge"
        case .kfzKosten: "Fahrzeugkosten"
        case .reisekosten: "Reisekosten"
        case .verpflegungsmehraufwand: "Verpflegungsmehraufwand"
        case .bewirtung: "Bewirtung"
        case .werbung: "Werbung und Marketing"
        case .telefonInternet: "Telefon und Internet"
        case .bürobedarf: "Bürobedarf"
        case .fachliteraturFortbildung: "Fachliteratur und Fortbildung"
        case .portoVersand: "Porto und Versand"
        case .rechtsUndSteuerberatung: "Rechts- und Steuerberatung"
        case .bankgebühren: "Kontoführung und Gebühren"
        case .zinsen: "Zinsen für betriebliche Darlehen"
        case .softwareAbos: "Software und Abonnements"
        case .sonstigeAusgaben: "Übrige Betriebsausgaben"
        }
    }

    var symbol: String {
        switch self {
        case .umsatzerlöse: "eurosign.circle"
        case .sonstigeErlöse: "plus.circle"
        case .anlagenverkauf: "shippingbox"
        case .privatentnahmeSachleistung: "house"
        case .wareneinkauf: "cart"
        case .fremdleistungen: "person.2"
        case .personalkosten: "person.3"
        case .abschreibung: "chart.line.downtrend.xyaxis"
        case .geringwertigeWirtschaftsgüter: "wrench.and.screwdriver"
        case .raumkosten: "building.2"
        case .arbeitszimmer: "lamp.desk"
        case .versicherungenBeiträge: "shield"
        case .kfzKosten: "car"
        case .reisekosten: "airplane"
        case .verpflegungsmehraufwand: "fork.knife"
        case .bewirtung: "wineglass"
        case .werbung: "megaphone"
        case .telefonInternet: "wifi"
        case .bürobedarf: "paperclip"
        case .fachliteraturFortbildung: "book"
        case .portoVersand: "envelope"
        case .rechtsUndSteuerberatung: "briefcase"
        case .bankgebühren: "banknote"
        case .zinsen: "percent"
        case .softwareAbos: "laptopcomputer"
        case .sonstigeAusgaben: "ellipsis.circle"
        }
    }

    /// Anteil der Netto-Ausgabe, der als Betriebsausgabe abziehbar ist.
    ///
    /// Bewirtungskosten sind nach § 4 Abs. 5 Satz 1 Nr. 2 EStG nur zu 70 % abziehbar.
    /// Die Vorsteuer bleibt davon unberuehrt und ist zu 100 % abziehbar - genau so
    /// rechnet `EinnahmenÜberschussRechnung`.
    var abzugsfaehigerAnteil: Decimal {
        switch self {
        case .bewirtung: Decimal(7) / 10
        default: 1
        }
    }

    /// Hinweis auf die Zeile der Anlage EUER (Orientierungswert, hier für 2024/2025).
    var euerZeile: Int? {
        switch self {
        case .umsatzerlöse: 14
        case .sonstigeErlöse: 17
        case .anlagenverkauf: 18
        case .privatentnahmeSachleistung: 19
        case .wareneinkauf: 26
        case .fremdleistungen: 27
        case .personalkosten: 28
        case .abschreibung: 32
        case .geringwertigeWirtschaftsgüter: 35
        case .raumkosten: 47
        case .arbeitszimmer: 48
        case .versicherungenBeiträge: 50
        case .kfzKosten: 61
        case .reisekosten: 66
        case .verpflegungsmehraufwand: 67
        case .bewirtung: 68
        case .werbung: 69
        case .zinsen: 55
        case .rechtsUndSteuerberatung: 59
        case .telefonInternet, .bürobedarf, .fachliteraturFortbildung,
             .portoVersand, .bankgebühren, .softwareAbos, .sonstigeAusgaben: 71
        }
    }

    /// Kurzer Hinweis, der in der Belegmaske unter dem Kategoriefeld erscheint.
    var hinweis: String? {
        switch self {
        case .bewirtung:
            "Nur 70 % sind abziehbar. Bewirtungsbeleg mit Anlass und Teilnehmern aufbewahren."
        case .verpflegungsmehraufwand:
            "Nur Pauschbeträge ansetzen, keine Einzelbelege. Ohne Vorsteuerabzug."
        case .arbeitszimmer:
            "Nur bei Mittelpunkt der Tätigkeit voll abziehbar, sonst Jahrespauschale prüfen."
        case .kfzKosten:
            "Bei gemischter Nutzung den betrieblichen Anteil eintragen oder Fahrtenbuch führen."
        case .geringwertigeWirtschaftsgüter:
            "Bis 800 Euro netto sofort abziehbar, darüber über die Nutzungsdauer abschreiben."
        case .privatentnahmeSachleistung:
            "Private Nutzung betrieblicher Güter erhöht den Gewinn."
        default:
            nil
        }
    }

    static var einnahmekategorien: [Belegkategorie] { allCases.filter { $0.art == .einnahme } }
    static var ausgabekategorien: [Belegkategorie] { allCases.filter { $0.art == .ausgabe } }
}
