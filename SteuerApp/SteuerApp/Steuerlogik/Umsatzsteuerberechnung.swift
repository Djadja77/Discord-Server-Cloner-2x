import Foundation

/// Umsatzsteuer-Voranmeldung: geschuldete Umsatzsteuer abzueglich abziehbarer Vorsteuer.
///
/// Zugrunde liegt die Ist-Versteuerung (§ 20 UStG) - massgeblich ist also das Datum der
/// Zahlung, nicht das Rechnungsdatum. Wer nach vereinbarten Entgelten versteuert
/// (Soll-Versteuerung), sollte bei den Belegen das Rechnungsdatum eintragen.
struct Umsatzsteuerberechnung {

    enum Rhythmus: String, CaseIterable, Identifiable, Sendable {
        case monatlich
        case vierteljaehrlich

        var id: String { rawValue }

        var bezeichnung: String {
            switch self {
            case .monatlich: "Monatlich"
            case .vierteljaehrlich: "Vierteljaehrlich"
            }
        }
    }

    struct Zeitraum: Identifiable, Equatable {
        let bezeichnung: String
        let umsatzsteuer: Decimal
        let vorsteuer: Decimal

        var id: String { bezeichnung }
        /// Positiv = ans Finanzamt zu zahlen, negativ = Erstattung.
        var zahllast: Decimal { umsatzsteuer - vorsteuer }
    }

    struct Ergebnis: Equatable {
        let jahr: Int
        let zeitraeume: [Zeitraum]
        /// `true`, wenn wegen § 19 UStG gar keine Umsatzsteuer anfaellt.
        let kleinunternehmer: Bool

        var umsatzsteuerGesamt: Decimal { zeitraeume.map(\.umsatzsteuer).summe }
        var vorsteuerGesamt: Decimal { zeitraeume.map(\.vorsteuer).summe }
        var zahllastGesamt: Decimal { umsatzsteuerGesamt - vorsteuerGesamt }
    }

    static func berechnen(
        belege: [Beleg],
        jahr: Int,
        rhythmus: Rhythmus,
        kleinunternehmer: Bool
    ) -> Ergebnis {
        guard !kleinunternehmer else {
            return Ergebnis(jahr: jahr, zeitraeume: [], kleinunternehmer: true)
        }

        let belegeDesJahres = belege.filter { $0.jahr == jahr }
        let anzahl = rhythmus == .monatlich ? 12 : 4

        let zeitraeume = (1...anzahl).map { index -> Zeitraum in
            let imZeitraum = belegeDesJahres.filter {
                rhythmus == .monatlich ? $0.monat == index : $0.quartal == index
            }
            return Zeitraum(
                bezeichnung: bezeichnung(index: index, rhythmus: rhythmus),
                // Die Vorsteuer wird nicht um gesetzliche Abzugsbeschraenkungen gekuerzt:
                // bei Bewirtungskosten etwa sind 100 % der Vorsteuer abziehbar, obwohl
                // ertragsteuerlich nur 70 % der Kosten anerkannt werden.
                umsatzsteuer: imZeitraum.filter { $0.art == .einnahme }
                    .map(\.betrieblicheUmsatzsteuer).summe,
                vorsteuer: imZeitraum.filter { $0.art == .ausgabe }
                    .map(\.betrieblicheUmsatzsteuer).summe
            )
        }

        return Ergebnis(jahr: jahr, zeitraeume: zeitraeume, kleinunternehmer: false)
    }

    private static func bezeichnung(index: Int, rhythmus: Rhythmus) -> String {
        switch rhythmus {
        case .vierteljaehrlich:
            return "\(index). Quartal"
        case .monatlich:
            let namen = ["Januar", "Februar", "Maerz", "April", "Mai", "Juni",
                         "Juli", "August", "September", "Oktober", "November", "Dezember"]
            return namen[index - 1]
        }
    }
}
