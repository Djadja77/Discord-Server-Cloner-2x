import Foundation

/// Verlustabzug nach § 10d Abs. 2 EStG.
///
/// Verluste aus Vorjahren mindern den Gesamtbetrag der Einkuenfte - aber nicht unbegrenzt.
/// Bis zum Sockelbetrag von einer Million Euro (doppelt bei Zusammenveranlagung) ist der
/// Abzug unbeschraenkt; vom darueber liegenden Teil des Gesamtbetrags der Einkuenfte duerfen
/// nur noch 70 Prozent verrechnet werden. Diese sogenannte Mindestbesteuerung stellt sicher,
/// dass auch in Jahren mit hohem Verlustvortrag Steuer anfaellt.
///
/// Fuer die meisten Selbstaendigen greift die Begrenzung nie - sie ist trotzdem umgesetzt,
/// weil ein falsch gerechnetes gutes Jahr teuer wird.
struct Verlustverrechnung {

    struct Ergebnis: Equatable {
        /// Vortrag, der zu Beginn des Jahres zur Verfuegung stand.
        let verfuegbarerVortrag: Decimal
        /// Hoechstbetrag, der in diesem Jahr abgezogen werden darf.
        let hoechstbetrag: Decimal
        /// Tatsaechlich abgezogener Betrag.
        let abgezogen: Decimal
        /// Rest, der ins Folgejahr weitergetragen wird.
        let verbleibenderVortrag: Decimal

        /// `true`, wenn die Mindestbesteuerung den Abzug begrenzt hat.
        var wurdeBegrenzt: Bool { abgezogen < verfuegbarerVortrag }

        static let keine = Ergebnis(
            verfuegbarerVortrag: 0, hoechstbetrag: 0, abgezogen: 0, verbleibenderVortrag: 0
        )
    }

    static func anwenden(
        gesamtbetragDerEinkuenfte: Decimal,
        verlustvortrag: Decimal,
        steuerjahr: Steuerjahr,
        splitting: Bool
    ) -> Ergebnis {
        let vortrag = verlustvortrag.nichtNegativ
        let einkuenfte = gesamtbetragDerEinkuenfte.nichtNegativ
        guard vortrag > 0, einkuenfte > 0 else {
            return Ergebnis(
                verfuegbarerVortrag: vortrag,
                hoechstbetrag: 0,
                abgezogen: 0,
                verbleibenderVortrag: vortrag
            )
        }

        let sockel = steuerjahr.verlustvortragSockelbetrag * (splitting ? 2 : 1)
        let ueberSockel = (einkuenfte - sockel).nichtNegativ
        let hoechstbetrag = min(einkuenfte, sockel)
            + (ueberSockel * steuerjahr.verlustvortragQuote).gerundet()

        let abgezogen = min(vortrag, hoechstbetrag)
        return Ergebnis(
            verfuegbarerVortrag: vortrag,
            hoechstbetrag: hoechstbetrag,
            abgezogen: abgezogen,
            verbleibenderVortrag: vortrag - abgezogen
        )
    }
}
