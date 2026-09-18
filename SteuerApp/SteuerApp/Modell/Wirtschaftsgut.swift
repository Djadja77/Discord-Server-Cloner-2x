import Foundation
import SwiftData

/// Ein abnutzbares Wirtschaftsgut des Anlagevermögens.
///
/// Anschaffungen oberhalb der Grenze für geringwertige Wirtschaftsgüter dürfen nicht
/// sofort abgezogen, sondern müssen über die betriebsgewöhnliche Nutzungsdauer verteilt
/// werden (§ 7 EStG). Die App rechnet die jährliche Abschreibung selbst aus, statt sie
/// Jahr für Jahr von Hand als Beleg zu verlangen.
@Model
final class Wirtschaftsgut {

    var bezeichnung: String = ""
    var anschaffungsdatum: Date = Date()

    /// Anschaffungskosten **ohne** Umsatzsteuer. Die Vorsteuer ist im Anschaffungsjahr
    /// in voller Höhe abziehbar und wird deshalb als eigener Beleg erfasst.
    var anschaffungskostenNetto: Decimal = Decimal(0)

    /// Betriebsgewöhnliche Nutzungsdauer in Jahren laut AfA-Tabelle.
    var nutzungsdauerJahre: Int = 3

    var notiz: String = ""

    init(
        bezeichnung: String = "",
        anschaffungsdatum: Date = Date(),
        anschaffungskostenNetto: Decimal = 0,
        nutzungsdauerJahre: Int = 3,
        notiz: String = ""
    ) {
        self.bezeichnung = bezeichnung
        self.anschaffungsdatum = anschaffungsdatum
        self.anschaffungskostenNetto = anschaffungskostenNetto
        self.nutzungsdauerJahre = nutzungsdauerJahre
        self.notiz = notiz
    }

    var anschaffungsjahr: Int {
        Calendar.kalender.component(.year, from: anschaffungsdatum)
    }

    /// Lineare Abschreibung des angegebenen Jahres (§ 7 Abs. 1 EStG).
    ///
    /// Im Anschaffungsjahr nur zeitanteilig ab dem Anschaffungsmonat. Im letzten Jahr wird
    /// der Restbuchwert angesetzt statt des rechnerischen Jahresbetrags - sonst bliebe durch
    /// die Rundung auf Cent ein Rest stehen, und das Wirtschaftsgut wäre nie ganz
    /// abgeschrieben.
    func abschreibung(fuerJahr jahr: Int) -> Decimal {
        guard nutzungsdauerJahre > 0, anschaffungskostenNetto > 0,
              jahr >= anschaffungsjahr, jahr <= letztesAbschreibungsjahr else { return 0 }

        if jahr < letztesAbschreibungsjahr { return reguläreAbschreibung(jahr) }

        let bisher = (anschaffungsjahr..<letztesAbschreibungsjahr)
            .map(reguläreAbschreibung).summe
        return (anschaffungskostenNetto - bisher).nichtNegativ
    }

    /// Rechnerischer Jahresbetrag, im Anschaffungsjahr zeitanteilig gekürzt.
    private func reguläreAbschreibung(_ jahr: Int) -> Decimal {
        let jahresbetrag = (anschaffungskostenNetto / Decimal(nutzungsdauerJahre)).gerundet()
        guard jahr == anschaffungsjahr else { return jahresbetrag }
        let monat = Calendar.kalender.component(.month, from: anschaffungsdatum)
        return (jahresbetrag * Decimal(13 - monat) / 12).gerundet()
    }

    /// Restbuchwert am Ende des angegebenen Jahres.
    func restbuchwert(endeJahr jahr: Int) -> Decimal {
        guard jahr >= anschaffungsjahr else { return anschaffungskostenNetto }
        let bisher = (anschaffungsjahr...jahr).map { abschreibung(fuerJahr: $0) }.summe
        return (anschaffungskostenNetto - bisher).nichtNegativ
    }

    /// Letztes Jahr, in dem noch abgeschrieben wird.
    var letztesAbschreibungsjahr: Int {
        guard nutzungsdauerJahre > 0 else { return anschaffungsjahr }
        let anschaffungsmonat = Calendar.kalender.component(.month, from: anschaffungsdatum)
        // Wird unterjährig angeschafft, reicht die Abschreibung ein Jahr länger.
        return anschaffungsjahr + nutzungsdauerJahre - (anschaffungsmonat == 1 ? 1 : 0)
    }
}

/// Uebliche Nutzungsdauern aus der amtlichen AfA-Tabelle - als Startpunkt in der Eingabemaske.
enum Nutzungsdauervorlage: String, CaseIterable, Identifiable {
    case computer
    case smartphone
    case software
    case büromöbel
    case fahrzeug
    case maschine

    var id: String { rawValue }

    var bezeichnung: String {
        switch self {
        case .computer: "Computer, Notebook, Peripherie"
        case .smartphone: "Smartphone, Tablet"
        case .software: "Software"
        case .büromöbel: "Büromöbel"
        case .fahrzeug: "Personenkraftwagen"
        case .maschine: "Maschinen, Werkstattausstattung"
        }
    }

    var jahre: Int {
        switch self {
        case .computer: 1
        case .smartphone: 5
        case .software: 3
        case .büromöbel: 13
        case .fahrzeug: 6
        case .maschine: 8
        }
    }
}
