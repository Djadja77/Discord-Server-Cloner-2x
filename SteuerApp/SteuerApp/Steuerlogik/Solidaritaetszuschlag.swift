import Foundation

/// Solidaritaetszuschlag nach dem Solidaritaetszuschlaggesetz (SolZG).
///
/// Seit 2021 zahlt ihn nur noch, wer die Freigrenze ueberschreitet. Direkt oberhalb der
/// Freigrenze greift eine Milderungszone: dort betraegt der Zuschlag 11,9 % des die
/// Freigrenze uebersteigenden Betrags, hoechstens aber die regulaeren 5,5 % der Steuer.
enum Solidaritaetszuschlag {

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
