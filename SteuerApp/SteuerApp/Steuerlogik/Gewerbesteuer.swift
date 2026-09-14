import Foundation

/// Gewerbesteuer und ihre Anrechnung auf die Einkommensteuer.
///
/// Freiberufler (§ 18 EStG) zahlen **keine** Gewerbesteuer - fuer sie bleibt dieses Modul
/// ungenutzt. Fuer Gewerbetreibende gilt:
///
/// 1. Gewerbeertrag = Gewinn, abgerundet auf volle 100 Euro (§ 11 Abs. 1 GewStG)
/// 2. abzueglich Freibetrag von 24.500 Euro fuer natuerliche Personen
/// 3. mal Steuermesszahl 3,5 % ergibt den Steuermessbetrag
/// 4. mal Hebesatz der Gemeinde ergibt die Gewerbesteuer
///
/// Die Gewerbesteuer wird nach § 35 EStG auf die Einkommensteuer angerechnet, und zwar mit
/// dem 3,8-fachen des Messbetrags, gedeckelt auf die tatsaechlich gezahlte Gewerbesteuer.
/// Ab einem Hebesatz von rund 380 % bleibt daher eine echte Restbelastung.
struct Gewerbesteuer {

    static let steuermesszahl: Decimal = 0.035
    static let anrechnungsfaktor: Decimal = 3.8

    struct Ergebnis: Equatable {
        let gewerbeertrag: Decimal
        let messbetrag: Decimal
        let gewerbesteuer: Decimal
        /// Hoechstbetrag der Anrechnung nach § 35 EStG, noch vor der Deckelung auf die
        /// tatsaechlich festgesetzte Einkommensteuer.
        let anrechnungsvolumen: Decimal
        /// Gewerbesteuer, die nach der Anrechnung tatsaechlich als Mehrbelastung bleibt.
        let restbelastung: Decimal

        static let keine = Ergebnis(
            gewerbeertrag: 0, messbetrag: 0, gewerbesteuer: 0,
            anrechnungsvolumen: 0, restbelastung: 0
        )
    }

    static func berechnen(
        gewinn: Decimal,
        hebesatzProzent: Decimal,
        steuerjahr: Steuerjahr
    ) -> Ergebnis {
        let ertrag = gewinn.nichtNegativ.aufVolle100EuroAbgerundet
        let bemessung = (ertrag - steuerjahr.gewerbesteuerFreibetrag).nichtNegativ
        guard bemessung > 0 else { return .keine }

        let messbetrag = (bemessung * steuermesszahl).gerundet()
        let steuer = (messbetrag * hebesatzProzent / 100).gerundet()
        let anrechnung = (messbetrag * anrechnungsfaktor).gerundet()

        return Ergebnis(
            gewerbeertrag: ertrag,
            messbetrag: messbetrag,
            gewerbesteuer: steuer,
            anrechnungsvolumen: min(anrechnung, steuer),
            restbelastung: (steuer - min(anrechnung, steuer)).nichtNegativ
        )
    }
}
