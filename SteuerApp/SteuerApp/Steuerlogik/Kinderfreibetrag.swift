import Foundation

/// Kinderfreibetraege und Guenstigerpruefung nach §§ 31, 32 Abs. 6 EStG.
///
/// Der Staat entlastet Familien auf zwei Wegen, die einander ausschliessen: entweder ueber
/// das monatlich ausgezahlte Kindergeld oder ueber die Freibetraege bei der Steuer. Das
/// Finanzamt rechnet beides durch und setzt automatisch an, was guenstiger ist. Bei kleinen
/// und mittleren Einkommen gewinnt fast immer das Kindergeld, bei hohen die Freibetraege.
///
/// Unabhaengig vom Ausgang dieser Pruefung werden Solidaritaetszuschlag und Kirchensteuer
/// **immer** aus der Steuer mit Kinderfreibetraegen berechnet (§ 51a Abs. 2 EStG). Wer Kinder
/// hat, zahlt also auch dann weniger Zuschlagsteuern, wenn das Kindergeld guenstiger war.
struct Kinderfreibetrag {

    struct Ergebnis: Equatable {
        let anzahlKinder: Int
        /// Summe der Kinderfreibetraege einschliesslich Betreuungsanteil.
        let freibetrag: Decimal
        /// Einkommensteuer ohne Beruecksichtigung der Freibetraege.
        let steuerOhneFreibetrag: Decimal
        /// Einkommensteuer unter Beruecksichtigung der Freibetraege.
        let steuerMitFreibetrag: Decimal
        /// Kindergeldanspruch des Jahres - Vergleichsgroesse der Guenstigerpruefung.
        let kindergeldanspruch: Decimal
        /// `true`, wenn die Freibetraege angesetzt werden und das Kindergeld hinzugerechnet wird.
        let freibetraegeAngesetzt: Bool

        /// Steuerentlastung durch die Freibetraege, vor dem Vergleich mit dem Kindergeld.
        var entlastung: Decimal { (steuerOhneFreibetrag - steuerMitFreibetrag).nichtNegativ }

        /// Tarifliche Einkommensteuer nach der Guenstigerpruefung.
        ///
        /// Werden die Freibetraege angesetzt, ist das Kindergeld hinzuzurechnen - sonst
        /// bekaeme man beide Verguenstigungen (§ 31 Satz 4 EStG).
        var tariflicheEinkommensteuer: Decimal {
            freibetraegeAngesetzt ? steuerMitFreibetrag + kindergeldanspruch : steuerOhneFreibetrag
        }

        /// Bemessungsgrundlage fuer Solidaritaetszuschlag und Kirchensteuer (§ 51a EStG).
        var bemessungZuschlagsteuern: Decimal { steuerMitFreibetrag }

        static func ohneKinder(steuer: Decimal) -> Ergebnis {
            Ergebnis(
                anzahlKinder: 0,
                freibetrag: 0,
                steuerOhneFreibetrag: steuer,
                steuerMitFreibetrag: steuer,
                kindergeldanspruch: 0,
                freibetraegeAngesetzt: false
            )
        }
    }

    /// Anteil, mit dem Freibetrag und Kindergeld angesetzt werden.
    ///
    /// Bei Zusammenveranlagung steht Eltern der volle Betrag zu. Bei Einzelveranlagung jeweils
    /// die Haelfte - es sei denn, der Anteil des anderen Elternteils wurde uebertragen.
    static func anteil(splitting: Bool, vollerFreibetrag: Bool) -> Decimal {
        splitting || vollerFreibetrag ? 1 : Decimal(1) / 2
    }

    static func pruefen(
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
            // Die Freibetraege lohnen sich erst, wenn sie mehr bringen als das Kindergeld.
            freibetraegeAngesetzt: (steuerOhne - steuerMit) > kindergeld
        )
    }
}
