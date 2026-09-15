import Foundation

/// Solidaritätszuschlag nach dem Solidaritaetszuschlaggesetz (SolZG).
///
/// Seit 2021 zahlt ihn nur noch, wer die Freigrenze überschreitet. Direkt oberhalb der
/// Freigrenze greift eine Milderungszone: dort beträgt der Zuschlag 11,9 % des die
/// Freigrenze übersteigenden Betrags, höchstens aber die regulären 5,5 % der Steuer.
enum Solidaritätszuschlag {

    static let regelsatz = Decimal(55) / 1_000
    static let milderungssatz = Decimal(119) / 1_000

    static func betrag(
        einkommensteuer: Decimal,
        steuerjahr: Steuerjahr,
        splitting: Bool
    ) -> Decimal {
        let freigrenze = steuerjahr.soliFreigrenze * (splitting ? 2 : 1)
        guard einkommensteuer > freigrenze else { return 0 }

        let voll = einkommensteuer * regelsatz
        let gemildert = (einkommensteuer - freigrenze) * milderungssatz
        return min(voll, gemildert).gerundet()
    }
}
