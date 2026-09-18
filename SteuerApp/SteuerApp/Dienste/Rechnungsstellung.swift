import Foundation
import SwiftData

/// Die Vorgänge, die eine Rechnung durchläuft: stellen, bezahlt setzen, stornieren.
///
/// Als eigener Ort und nicht in der Ansicht, weil hier die Regeln stehen, die man nicht
/// aus Versehen verletzen darf - eine gestellte Rechnung ändert sich nicht mehr, eine
/// Nummer wird nur einmal vergeben, und eine bezahlte Rechnung ist eine Einnahme in der
/// Einnahmen-Überschuss-Rechnung.
enum Rechnungsstellung {

    /// Macht aus einem Entwurf eine gestellte Rechnung.
    ///
    /// Hier passiert das, was sich später nicht mehr rückgängig machen lässt: die Nummer
    /// wird vergeben, und Anschriften, Steuernummer und Kleinunternehmer-Eigenschaft
    /// werden in die Rechnung kopiert. Ab jetzt ist das Dokument fest, auch wenn sich
    /// Profil oder Kunde später ändern.
    @discardableResult
    static func stellen(_ rechnung: Rechnung, profil: Steuerprofil, in kontext: ModelContext) -> Bool {
        guard rechnung.istEntwurf, rechnung.hindernisse.isEmpty else { return false }

        let jahr = Calendar.kalender.component(.year, from: rechnung.datum)
        let vergeben = Rechnungsnummer.vergeben(fuer: jahr, in: profil.nummernkreis)
        profil.nummernkreis = vergeben.kreis

        rechnung.nummer = vergeben.nummer
        rechnung.jahr = jahr
        rechnung.laufendeNummer = vergeben.laufend

        abschreiben(rechnung, profil: profil)
        rechnung.status = .offen

        try? kontext.save()
        return true
    }

    /// Kopiert Absender, Empfänger und Steuerstand in die Rechnung.
    static func abschreiben(_ rechnung: Rechnung, profil: Steuerprofil) {
        rechnung.absenderName = profil.absenderName
        rechnung.absenderAnschrift = profil.absenderzeilen.joined(separator: "\n")
        rechnung.absenderSteuernummer = profil.steuernummer
        rechnung.absenderUstIdNr = profil.ustIdNr
        rechnung.absenderBank = profil.bankzeile
        rechnung.kleinunternehmer = profil.kleinunternehmer

        if let kunde = rechnung.kunde {
            rechnung.empfaengerName = kunde.name
            rechnung.empfaengerAnschrift = kunde.anschrift
            rechnung.empfaengerUstIdNr = kunde.ustIdNr
            rechnung.empfaengerLeitwegId = kunde.leitwegId
        }
        if rechnung.fusstext.isEmpty { rechnung.fusstext = profil.rechnungsfusstext }
    }

    /// Setzt eine Rechnung auf bezahlt.
    ///
    /// Und sonst nichts. Die Rechnungen sind ein eigener Bereich und rechnen nicht in
    /// die Steuer hinein: aus einer bezahlten Rechnung entsteht keine Einnahme in der
    /// Einnahmen-Überschuss-Rechnung, der Gewinn ändert sich nicht, die Schätzung auch
    /// nicht. Wer den Zahlungseingang in der Steuer haben will, erfasst ihn unter
    /// "Belege" - dort und nur dort entscheidet sich, was gerechnet wird.
    ///
    /// Das ist bewusst so. Eine Rechnung ist gestellt, nicht vereinnahmt, und wer nach
    /// § 4 Abs. 3 EStG rechnet, zählt den Zufluss - nicht das Papier.
    static func bezahltSetzen(_ rechnung: Rechnung, am tag: Date, in kontext: ModelContext) {
        guard rechnung.status == .offen else { return }
        rechnung.status = .bezahlt
        rechnung.bezahltAm = tag
        try? kontext.save()
    }

    /// Nimmt das Bezahltsetzen zurück.
    static func zahlungZurücknehmen(_ rechnung: Rechnung, in kontext: ModelContext) {
        guard rechnung.status == .bezahlt else { return }
        rechnung.bezahltAm = nil
        rechnung.status = .offen
        try? kontext.save()
    }

    /// Hebt eine gestellte Rechnung durch eine Stornorechnung auf.
    ///
    /// Gelöscht wird nichts: beide Belege bleiben stehen, die Stornorechnung nennt die
    /// aufgehobene, und die aufgehobene nennt die Stornorechnung. Genau das verlangen
    /// die GoBD - eine verschwundene Rechnungsnummer ist in einer Prüfung ein Befund.
    @discardableResult
    static func stornieren(
        _ rechnung: Rechnung, profil: Steuerprofil, in kontext: ModelContext
    ) -> Rechnung? {
        guard rechnung.status == .offen || rechnung.status == .bezahlt else { return nil }

        if rechnung.status == .bezahlt { zahlungZurücknehmen(rechnung, in: kontext) }

        let jahr = Calendar.kalender.component(.year, from: Date())
        let vergeben = Rechnungsnummer.vergeben(fuer: jahr, in: profil.nummernkreis)
        profil.nummernkreis = vergeben.kreis

        let storno = Rechnung(
            nummer: vergeben.nummer,
            jahr: jahr,
            laufendeNummer: vergeben.laufend,
            datum: Date(),
            zahlbarBis: Date()
        )
        storno.kunde = rechnung.kunde
        storno.ordner = rechnung.ordner
        storno.leistungVon = rechnung.leistungVon
        storno.leistungBis = rechnung.leistungBis
        storno.stornoFuerNummer = rechnung.nummer
        storno.fusstext = "Diese Stornorechnung hebt die Rechnung \(rechnung.nummer) vollständig auf."
        kontext.insert(storno)

        // Dieselben Positionen mit umgekehrtem Vorzeichen - so hebt die Summe die
        // ursprüngliche exakt auf, auch bei mehreren Steuersätzen.
        for alt in rechnung.postenGeordnet {
            let neu = Rechnungsposten(
                reihenfolge: alt.reihenfolge,
                bezeichnung: alt.bezeichnung,
                menge: alt.menge,
                einheit: alt.einheit,
                einzelpreis: -alt.einzelpreis,
                umsatzsteuersatz: alt.umsatzsteuersatz
            )
            neu.rechnung = storno
            kontext.insert(neu)
        }

        abschreiben(storno, profil: profil)
        storno.status = .offen

        rechnung.status = .storniert
        rechnung.storniertDurchNummer = storno.nummer

        try? kontext.save()
        return storno
    }
}
