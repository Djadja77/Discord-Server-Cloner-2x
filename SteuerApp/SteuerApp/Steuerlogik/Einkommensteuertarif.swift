import Foundation

/// Der Einkommensteuertarif nach § 32a EStG.
///
/// Der Tarif besteht aus fünf Zonen:
/// 1. Grundfreibetrag - keine Steuer
/// 2. erste Progressionszone - Grenzsteuersatz steigt linear von 14 % auf 23,97 %
/// 3. zweite Progressionszone - Grenzsteuersatz steigt linear von 23,97 % auf 42 %
/// 4. Proportionalzone - 42 %
/// 5. Spitzenzone ("Reichensteuer") - 45 %
///
/// Das Gesetz rechnet mit dem auf volle Euro abgerundeten zu versteuernden Einkommen und
/// rundet auch das Ergebnis auf volle Euro ab. Genau das bildet `grundtarif(_:)` nach.
struct Einkommensteuertarif {

    let steuerjahr: Steuerjahr

    init(steuerjahr: Steuerjahr) {
        self.steuerjahr = steuerjahr
    }

    /// Tarifliche Einkommensteuer für ein zu versteuerndes Einkommen.
    /// - Parameter splitting: `true` wendet das Ehegattensplitting nach § 32a Abs. 5 EStG an.
    func einkommensteuer(zuVersteuerndesEinkommen zve: Decimal, splitting: Bool) -> Decimal {
        guard zve > 0 else { return 0 }
        if splitting {
            // Splittingverfahren: halbes zvE versteuern, Ergebnis verdoppeln.
            return grundtarif(zve / 2) * 2
        }
        return grundtarif(zve)
    }

    /// Grundtarif für einen einzelnen Steuerpflichtigen.
    func grundtarif(_ zve: Decimal) -> Decimal {
        let t = steuerjahr.tarif
        let x = zve.aufVolleEuroAbgerundet.alsDouble
        guard x > t.grundfreibetrag.alsDouble else { return 0 }

        let steuer: Double
        if x <= t.endeZone2.alsDouble {
            let y = (x - t.grundfreibetrag.alsDouble) / 10_000
            steuer = (t.faktorZone2 * y + 1_400) * y
        } else if x <= t.endeZone3.alsDouble {
            let z = (x - t.endeZone2.alsDouble) / 10_000
            steuer = (t.faktorZone3 * z + 2_397) * z + t.sockelZone3
        } else if x <= t.endeZone4.alsDouble {
            steuer = 0.42 * x - t.abzugZone4
        } else {
            steuer = 0.45 * x - t.abzugZone5
        }

        // Über Int statt direkt aus Double: Decimal(Double) kann Rundungsreste
        // erzeugen, und das Ergebnis ist nach § 32a EStG ohnehin ein voller Euro-Betrag.
        let volleEuro = min(max(steuer.rounded(.down), 0), 1e15)
        return Decimal(Int(volleEuro))
    }

    /// Durchschnittssteuersatz - was tatsächlich vom Einkommen abgeht.
    func durchschnittssteuersatz(zuVersteuerndesEinkommen zve: Decimal, splitting: Bool) -> Double {
        guard zve > 0 else { return 0 }
        let steuer = einkommensteuer(zuVersteuerndesEinkommen: zve, splitting: splitting)
        return steuer.alsDouble / zve.alsDouble
    }

    /// Grenzsteuersatz - was der nächste verdiente Euro kostet.
    ///
    /// Bewusst als Differenzenquotient über 100 Euro berechnet: das ist genau die Frage,
    /// die sich Selbständige beim Verschieben von Einnahmen ins nächste Jahr stellen.
    func grenzsteuersatz(zuVersteuerndesEinkommen zve: Decimal, splitting: Bool) -> Double {
        let schrittweite: Decimal = 100
        let unten = einkommensteuer(zuVersteuerndesEinkommen: zve, splitting: splitting)
        let oben = einkommensteuer(zuVersteuerndesEinkommen: zve + schrittweite, splitting: splitting)
        return (oben - unten).alsDouble / schrittweite.alsDouble
    }
}
