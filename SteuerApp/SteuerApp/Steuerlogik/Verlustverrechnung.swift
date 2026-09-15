import Foundation

/// Verlustabzug nach § 10d Abs. 2 EStG.
///
/// Verluste aus Vorjahren mindern den Gesamtbetrag der Einkünfte - aber nicht unbegrenzt.
/// Bis zum Sockelbetrag von einer Million Euro (doppelt bei Zusammenveranlagung) ist der
/// Abzug unbeschränkt; vom darüber liegenden Teil des Gesamtbetrags der Einkünfte dürfen
/// nur noch 70 Prozent verrechnet werden. Diese sogenannte Mindestbesteuerung stellt sicher,
/// dass auch in Jahren mit hohem Verlustvortrag Steuer anfällt.
///
/// Für die meisten Selbständigen greift die Begrenzung nie - sie ist trotzdem umgesetzt,
/// weil ein falsch gerechnetes gutes Jahr teuer wird.
struct Verlustverrechnung {

    struct Ergebnis: Equatable {
        /// Vortrag, der zu Beginn des Jahres zur Verfügung stand.
        let verfügbarerVortrag: Decimal
        /// Höchstbetrag, der in diesem Jahr abgezogen werden darf.
        let höchstbetrag: Decimal
        /// Tatsächlich abgezogener Betrag.
        let abgezogen: Decimal
        /// Rest, der ins Folgejahr weitergetragen wird.
        let verbleibenderVortrag: Decimal

        /// `true`, wenn die Mindestbesteuerung den Abzug begrenzt hat.
        var wurdeBegrenzt: Bool { abgezogen < verfügbarerVortrag }

        static let keine = Ergebnis(
            verfügbarerVortrag: 0, höchstbetrag: 0, abgezogen: 0, verbleibenderVortrag: 0
        )
    }

    static func anwenden(
        gesamtbetragDerEinkünfte: Decimal,
        verlustvortrag: Decimal,
        steuerjahr: Steuerjahr,
        splitting: Bool
    ) -> Ergebnis {
        let vortrag = verlustvortrag.nichtNegativ
        let einkünfte = gesamtbetragDerEinkünfte.nichtNegativ
        guard vortrag > 0, einkünfte > 0 else {
            return Ergebnis(
                verfügbarerVortrag: vortrag,
                höchstbetrag: 0,
                abgezogen: 0,
                verbleibenderVortrag: vortrag
            )
        }

        let sockel = steuerjahr.verlustvortragSockelbetrag * (splitting ? 2 : 1)
        let ueberSockel = (einkünfte - sockel).nichtNegativ
        let höchstbetrag = min(einkünfte, sockel)
            + (ueberSockel * steuerjahr.verlustvortragQuote).gerundet()

        let abgezogen = min(vortrag, höchstbetrag)
        return Ergebnis(
            verfügbarerVortrag: vortrag,
            höchstbetrag: höchstbetrag,
            abgezogen: abgezogen,
            verbleibenderVortrag: vortrag - abgezogen
        )
    }
}
