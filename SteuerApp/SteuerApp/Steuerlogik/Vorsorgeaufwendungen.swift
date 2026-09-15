import Foundation

/// Abzug der Vorsorgeaufwendungen als Sonderausgaben (§ 10 EStG).
///
/// Für Selbständige ist das oft der größte Abzugsposten überhaupt, weil sie Kranken- und
/// Altersvorsorge vollständig allein tragen.
///
/// - **Altersvorsorge** (gesetzliche Rentenversicherung, Rürup-/Basisrente, berufsständische
///   Versorgungswerke): seit 2023 zu 100 % abziehbar, begrenzt auf den Höchstbetrag.
/// - **Basisabsicherung Kranken- und Pflegeversicherung**: unbegrenzt abziehbar, allerdings nur
///   der Anteil, der auf das Basisniveau entfällt (Wahlleistungen und Krankengeldanteil zählen
///   nicht mit - deshalb fragt die App gezielt nach dem Basisbeitrag).
/// - **Sonstige Vorsorge** (Haftpflicht, Unfall, Arbeitslosenversicherung): nur im Rahmen eines
///   kleinen Höchstbetrags, der durch die Basis-KV/PV praktisch immer bereits aufgebraucht ist.
struct Vorsorgeaufwendungen: Equatable {

    /// Beiträge zur gesetzlichen Rente, zum Versorgungswerk oder zur Basisrente.
    var altersvorsorge: Decimal = 0
    /// Basisbeitrag zur Kranken- und Pflegeversicherung.
    var krankenUndPflegeBasis: Decimal = 0
    /// Übrige Versicherungen (Haftpflicht, Unfall, Berufsunfähigkeit, ...).
    var sonstigeVersicherungen: Decimal = 0

    struct Ergebnis: Equatable {
        let abziehbareAltersvorsorge: Decimal
        let abziehbareKrankenUndPflege: Decimal
        let abziehbareSonstige: Decimal
        var summe: Decimal {
            abziehbareAltersvorsorge + abziehbareKrankenUndPflege + abziehbareSonstige
        }
    }

    func abziehbar(steuerjahr: Steuerjahr, splitting: Bool) -> Ergebnis {
        let faktor: Decimal = splitting ? 2 : 1

        let alter = min(altersvorsorge.nichtNegativ, steuerjahr.höchstbetragAltersvorsorge * faktor)
        let basis = krankenUndPflegeBasis.nichtNegativ

        // Der Höchstbetrag für sonstige Vorsorgeaufwendungen gilt für Basis-KV/PV und
        // sonstige Versicherungen gemeinsam. Was die Basisabsicherung übersteigt, wird
        // ohnehin voll abgezogen; nur ein danach verbleibender Rest kommt den sonstigen
        // Versicherungen zugute.
        let höchstbetragSonstige = steuerjahr.höchstbetragSonstigeVorsorge * faktor
        let restvolumen = (höchstbetragSonstige - basis).nichtNegativ
        let sonstige = min(sonstigeVersicherungen.nichtNegativ, restvolumen)

        return Ergebnis(
            abziehbareAltersvorsorge: alter,
            abziehbareKrankenUndPflege: basis,
            abziehbareSonstige: sonstige
        )
    }
}
