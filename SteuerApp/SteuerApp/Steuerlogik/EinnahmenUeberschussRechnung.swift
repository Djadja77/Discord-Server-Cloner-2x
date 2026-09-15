import Foundation

/// Gewinnermittlung durch Einnahmen-Überschuss-Rechnung nach § 4 Abs. 3 EStG.
///
/// ## Netto- statt Bruttomethode
/// Die App rechnet mit Nettobeträgen: vereinnahmte Umsatzsteuer und gezahlte Vorsteuer
/// bleiben außen vor, weil sie wirtschaftlich nur durchlaufende Posten sind. Das Ergebnis
/// entspricht dem der Bruttomethode, ist aber unterjährig aussagekräftiger, weil es nicht
/// vom Rhythmus der Voranmeldungen abhängt. In der Anlage EUER ist die Bruttomethode
/// vorgesehen - beim Übertragen also Umsatzsteuer und Vorsteuer wieder ergaenzen.
///
/// Kleinunternehmer nach § 19 UStG rechnen ohnehin brutto: sie weisen keine Umsatzsteuer aus
/// und dürfen keine Vorsteuer abziehen.
struct EinnahmenÜberschussRechnung {

    struct Posten: Identifiable, Equatable {
        let kategorie: Belegkategorie
        /// Betrag, der in die Gewinnermittlung eingeht (bereits um betrieblichen Anteil und
        /// gesetzliche Abzugsbeschränkungen gekürzt).
        let betrag: Decimal
        /// Ungekürzter betrieblicher Betrag - zeigt, was die Beschränkung gekostet hat.
        let betragVorKürzung: Decimal
        let anzahlBelege: Int

        var id: String { kategorie.rawValue }
        var wurdeGekürzt: Bool { betrag != betragVorKürzung }
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
    ///   - wirtschaftsgüter: Anlagevermögen, dessen Abschreibung als Betriebsausgabe
    ///     hinzukommt. Sie wird berechnet, nicht als Beleg erfasst.
    ///   - kleinunternehmer: `true` rechnet brutto (§ 19 UStG).
    static func berechnen(
        belege: [Beleg],
        wirtschaftsgüter: [Wirtschaftsgut] = [],
        jahr: Int,
        kleinunternehmer: Bool
    ) -> Ergebnis {
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
                    betragVorKürzung: roh,
                    anzahlBelege: belege.count
                )
            }
            .sorted { $0.betrag > $1.betrag }
        }

        return Ergebnis(
            jahr: jahr,
            einnahmen: posten(fuer: .einnahme),
            ausgaben: mitAbschreibung(
                posten(fuer: .ausgabe),
                wirtschaftsgüter: wirtschaftsgüter,
                jahr: jahr
            )
        )
    }

    /// Fügt die berechnete Abschreibung in den Posten "Abschreibungen (AfA)" ein.
    ///
    /// Erfasst jemand die Abschreibung zusätzlich von Hand als Beleg, werden beide Beträge
    /// zusammengefasst statt zu konkurrieren - der Posten zeigt dann die Summe und die Anzahl
    /// der beteiligten Wirtschaftsgüter.
    private static func mitAbschreibung(
        _ ausgaben: [Posten],
        wirtschaftsgüter: [Wirtschaftsgut],
        jahr: Int
    ) -> [Posten] {
        let betroffene = wirtschaftsgüter.filter { $0.abschreibung(fuerJahr: jahr) > 0 }
        let afa = betroffene.map { $0.abschreibung(fuerJahr: jahr) }.summe
        guard afa > 0 else { return ausgaben }

        var ergebnis = ausgaben
        let vorhanden = ergebnis.firstIndex { $0.kategorie == .abschreibung }

        if let index = vorhanden {
            let alt = ergebnis[index]
            ergebnis[index] = Posten(
                kategorie: .abschreibung,
                betrag: alt.betrag + afa,
                betragVorKürzung: alt.betragVorKürzung + afa,
                anzahlBelege: alt.anzahlBelege + betroffene.count
            )
        } else {
            ergebnis.append(Posten(
                kategorie: .abschreibung,
                betrag: afa,
                betragVorKürzung: afa,
                anzahlBelege: betroffene.count
            ))
        }
        return ergebnis.sorted { $0.betrag > $1.betrag }
    }
}
