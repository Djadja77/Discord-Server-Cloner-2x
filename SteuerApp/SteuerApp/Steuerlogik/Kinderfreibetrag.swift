import Foundation

/// Kinderfreibeträge und Günstigerprüfung nach §§ 31, 32 Abs. 6 EStG.
///
/// Der Staat entlastet Familien auf zwei Wegen, die einander ausschließen: entweder über
/// das monatlich ausgezahlte Kindergeld oder über die Freibeträge bei der Steuer. Das
/// Finanzamt rechnet beides durch und setzt automatisch an, was günstiger ist. Bei kleinen
/// und mittleren Einkommen gewinnt fast immer das Kindergeld, bei hohen die Freibeträge.
///
/// Unabhängig vom Ausgang dieser Prüfung werden Solidaritätszuschlag und Kirchensteuer
/// **immer** aus der Steuer mit Kinderfreibeträgen berechnet (§ 51a Abs. 2 EStG). Wer Kinder
/// hat, zahlt also auch dann weniger Zuschlagsteuern, wenn das Kindergeld günstiger war.
struct Kinderfreibetrag {

    struct Ergebnis: Equatable {
        let anzahlKinder: Int
        /// Summe der Kinderfreibeträge einschließlich Betreuungsanteil.
        let freibetrag: Decimal
        /// Einkommensteuer ohne Beruecksichtigung der Freibeträge.
        let steuerOhneFreibetrag: Decimal
        /// Einkommensteuer unter Beruecksichtigung der Freibeträge.
        let steuerMitFreibetrag: Decimal
        /// Kindergeldanspruch des Jahres - Vergleichsgröße der Günstigerprüfung.
        let kindergeldanspruch: Decimal
        /// `true`, wenn die Freibeträge angesetzt werden und das Kindergeld hinzugerechnet wird.
        let freibeträgeAngesetzt: Bool

        /// Steuerentlastung durch die Freibeträge, vor dem Vergleich mit dem Kindergeld.
        var entlastung: Decimal { (steuerOhneFreibetrag - steuerMitFreibetrag).nichtNegativ }

        /// Tarifliche Einkommensteuer nach der Günstigerprüfung.
        ///
        /// Werden die Freibeträge angesetzt, ist das Kindergeld hinzuzurechnen - sonst
        /// bekäme man beide Vergünstigungen (§ 31 Satz 4 EStG).
        var tariflicheEinkommensteuer: Decimal {
            freibeträgeAngesetzt ? steuerMitFreibetrag + kindergeldanspruch : steuerOhneFreibetrag
        }

        /// Bemessungsgrundlage für Solidaritätszuschlag und Kirchensteuer (§ 51a EStG).
        var bemessungZuschlagsteuern: Decimal { steuerMitFreibetrag }

        static func ohneKinder(steuer: Decimal) -> Ergebnis {
            Ergebnis(
                anzahlKinder: 0,
                freibetrag: 0,
                steuerOhneFreibetrag: steuer,
                steuerMitFreibetrag: steuer,
                kindergeldanspruch: 0,
                freibeträgeAngesetzt: false
            )
        }
    }

    /// Anteil, mit dem Freibetrag und Kindergeld angesetzt werden.
    ///
    /// Bei Zusammenveranlagung steht Eltern der volle Betrag zu. Bei Einzelveranlagung jeweils
    /// die Hälfte - es sei denn, der Anteil des anderen Elternteils wurde übertragen.
    static func anteil(splitting: Bool, vollerFreibetrag: Bool) -> Decimal {
        splitting || vollerFreibetrag ? 1 : Decimal(1) / 2
    }

    static func prüfen(
        zuVersteuerndesEinkommen zve: Decimal,
        anzahlKinder: Int,
        vollerFreibetrag: Bool,
        steuerjahr: Steuerjahr,
        splitting: Bool
    ) -> Ergebnis {
        let tarif = Einkommensteuertarif(steuerjahr: steuerjahr)
        let steuerOhne = tarif.einkommensteuer(
            zuVersteuerndesEinkommen: zve, splitting: splitting
        )

        guard anzahlKinder > 0 else { return .ohneKinder(steuer: steuerOhne) }

        let anteilsfaktor = anteil(splitting: splitting, vollerFreibetrag: vollerFreibetrag)
        let kinder = Decimal(anzahlKinder)
        let freibetrag = (steuerjahr.kinderfreibetragGesamt * kinder * anteilsfaktor).gerundet()
        let kindergeld = (steuerjahr.kindergeldProJahr * kinder * anteilsfaktor).gerundet()

        let steuerMit = tarif.einkommensteuer(
            zuVersteuerndesEinkommen: (zve - freibetrag).nichtNegativ, splitting: splitting
        )

        return Ergebnis(
            anzahlKinder: anzahlKinder,
            freibetrag: freibetrag,
            steuerOhneFreibetrag: steuerOhne,
            steuerMitFreibetrag: steuerMit,
            kindergeldanspruch: kindergeld,
            // Die Freibeträge lohnen sich erst, wenn sie mehr bringen als das Kindergeld.
            freibeträgeAngesetzt: (steuerOhne - steuerMit) > kindergeld
        )
    }
}
