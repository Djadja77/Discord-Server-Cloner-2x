import Foundation

/// Gewinnermittlung durch Einnahmen-Ueberschuss-Rechnung nach § 4 Abs. 3 EStG.
///
/// ## Netto- statt Bruttomethode
/// Die App rechnet mit Nettobetraegen: vereinnahmte Umsatzsteuer und gezahlte Vorsteuer
/// bleiben aussen vor, weil sie wirtschaftlich nur durchlaufende Posten sind. Das Ergebnis
/// entspricht dem der Bruttomethode, ist aber unterjaehrig aussagekraeftiger, weil es nicht
/// vom Rhythmus der Voranmeldungen abhaengt. In der Anlage EUER ist die Bruttomethode
/// vorgesehen - beim Uebertragen also Umsatzsteuer und Vorsteuer wieder ergaenzen.
///
/// Kleinunternehmer nach § 19 UStG rechnen ohnehin brutto: sie weisen keine Umsatzsteuer aus
/// und duerfen keine Vorsteuer abziehen.
struct EinnahmenUeberschussRechnung {

    struct Posten: Identifiable, Equatable {
        let kategorie: Belegkategorie
        /// Betrag, der in die Gewinnermittlung eingeht (bereits um betrieblichen Anteil und
        /// gesetzliche Abzugsbeschraenkungen gekuerzt).
        let betrag: Decimal
        /// Ungekuerzter betrieblicher Betrag - zeigt, was die Beschraenkung gekostet hat.
        let betragVorKuerzung: Decimal
        let anzahlBelege: Int

        var id: String { kategorie.rawValue }
        var wurdeGekuerzt: Bool { betrag != betragVorKuerzung }
    }

    struct Ergebnis: Equatable {
        let jahr: Int
        let einnahmen: [Posten]
        let ausgaben: [Posten]

        var summeEinnahmen: Decimal { einnahmen.map(\.betrag).summe }
        var summeAusgaben: Decimal { ausgaben.map(\.betrag).summe }
        var gewinn: Decimal { summeEinnahmen - summeAusgaben }
        var anzahlBelege: Int {
            einnahmen.map(\.anzahlBelege).reduce(0, +) + ausgaben.map(\.anzahlBelege).reduce(0, +)
        }

        static func leer(jahr: Int) -> Ergebnis {
            Ergebnis(jahr: jahr, einnahmen: [], ausgaben: [])
        }
    }

    /// - Parameters:
    ///   - belege: alle Belege; es werden nur die des angegebenen Jahres beruecksichtigt.
    ///   - kleinunternehmer: `true` rechnet brutto (§ 19 UStG).
    static func berechnen(belege: [Beleg], jahr: Int, kleinunternehmer: Bool) -> Ergebnis {
        let belegeDesJahres = belege.filter { $0.jahr == jahr }

        func posten(fuer art: Belegart) -> [Posten] {
            let gruppiert = Dictionary(grouping: belegeDesJahres.filter { $0.art == art }) {
                $0.kategorie
            }
            return gruppiert.map { kategorie, belege in
                let roh = belege
                    .map { kleinunternehmer ? $0.betrieblichesBrutto : $0.betrieblichesNetto }
                    .summe
                return Posten(
                    kategorie: kategorie,
                    betrag: (roh * kategorie.abzugsfaehigerAnteil).gerundet(),
                    betragVorKuerzung: roh,
                    anzahlBelege: belege.count
                )
            }
            .sorted { $0.betrag > $1.betrag }
        }

        return Ergebnis(
            jahr: jahr,
            einnahmen: posten(fuer: .einnahme),
            ausgaben: posten(fuer: .ausgabe)
        )
    }
}
