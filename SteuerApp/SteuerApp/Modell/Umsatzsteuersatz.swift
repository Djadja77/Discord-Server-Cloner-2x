import Foundation

/// Die in Deutschland relevanten Umsatzsteuersätze.
enum Umsatzsteuersatz: String, CaseIterable, Codable, Identifiable, Sendable {
    /// 0 % - steuerfreie Umsaetze, Kleinunternehmer, Auslandsleistungen mit Reverse Charge.
    case ohne
    /// 7 % - ermäßigter Satz (§ 12 Abs. 2 UStG), z. B. Bücher, Lebensmittel, Personenbeförderung.
    case ermaessigt
    /// 19 % - Regelsteuersatz (§ 12 Abs. 1 UStG).
    case regel

    var id: String { rawValue }

    var satz: Decimal {
        switch self {
        case .ohne: 0
        case .ermaessigt: Decimal(7) / 100
        case .regel: Decimal(19) / 100
        }
    }

    var bezeichnung: String {
        switch self {
        case .ohne: "0 %"
        case .ermaessigt: "7 %"
        case .regel: "19 %"
        }
    }

    /// Nettobetrag zu einem gegebenen Bruttobetrag.
    func netto(ausBrutto brutto: Decimal) -> Decimal {
        (brutto / (1 + satz)).gerundet()
    }

    /// Im Bruttobetrag enthaltene Umsatzsteuer.
    func steueranteil(ausBrutto brutto: Decimal) -> Decimal {
        (brutto - netto(ausBrutto: brutto)).gerundet()
    }
}
