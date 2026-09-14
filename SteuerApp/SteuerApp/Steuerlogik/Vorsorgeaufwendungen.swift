import Foundation

/// Abzug der Vorsorgeaufwendungen als Sonderausgaben (§ 10 EStG).
///
/// Fuer Selbstaendige ist das oft der groesste Abzugsposten ueberhaupt, weil sie Kranken- und
/// Altersvorsorge vollstaendig allein tragen.
///
/// - **Altersvorsorge** (gesetzliche Rentenversicherung, Ruerup-/Basisrente, berufsstaendische
///   Versorgungswerke): seit 2023 zu 100 % abziehbar, begrenzt auf den Hoechstbetrag.
/// - **Basisabsicherung Kranken- und Pflegeversicherung**: unbegrenzt abziehbar, allerdings nur
///   der Anteil, der auf das Basisniveau entfaellt (Wahlleistungen und Krankengeldanteil zaehlen
///   nicht mit - deshalb fragt die App gezielt nach dem Basisbeitrag).
/// - **Sonstige Vorsorge** (Haftpflicht, Unfall, Arbeitslosenversicherung): nur im Rahmen eines
///   kleinen Hoechstbetrags, der durch die Basis-KV/PV praktisch immer bereits aufgebraucht ist.
struct Vorsorgeaufwendungen: Equatable {

    /// Beitraege zur gesetzlichen Rente, zum Versorgungswerk oder zur Basisrente.
    var altersvorsorge: Decimal = 0
    /// Basisbeitrag zur Kranken- und Pflegeversicherung.
    var krankenUndPflegeBasis: Decimal = 0
    /// Uebrige Versicherungen (Haftpflicht, Unfall, Berufsunfaehigkeit, ...).
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

        let alter = min(altersvorsorge.nichtNegativ, steuerjahr.hoechstbetragAltersvorsorge * faktor)
        let basis = krankenUndPflegeBasis.nichtNegativ

        // Der Hoechstbetrag fuer sonstige Vorsorgeaufwendungen gilt fuer Basis-KV/PV und
        // sonstige Versicherungen gemeinsam. Was die Basisabsicherung uebersteigt, wird
        // ohnehin voll abgezogen; nur ein danach verbleibender Rest kommt den sonstigen
        // Versicherungen zugute.
        let hoechstbetragSonstige = steuerjahr.hoechstbetragSonstigeVorsorge * faktor
        let restvolumen = (hoechstbetragSonstige - basis).nichtNegativ
        let sonstige = min(sonstigeVersicherungen.nichtNegativ, restvolumen)

        return Ergebnis(
            abziehbareAltersvorsorge: alter,
            abziehbareKrankenUndPflege: basis,
            abziehbareSonstige: sonstige
        )
    }
}
