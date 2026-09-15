import SwiftUI
import SwiftData

/// Die Startseite: Wie läuft das Jahr, und wie viel Geld gehört dem Finanzamt?
struct UebersichtAnsicht: View {

    @Binding var jahr: Int
    @Query(sort: \Beleg.datum, order: .reverse) private var belege: [Beleg]
    @Query private var profile: [Steuerprofil]
    @Query private var alleJahresangaben: [Jahresangaben]
    @Query private var wirtschaftsgüter: [Wirtschaftsgut]

    private var profil: Steuerprofil { profile.first ?? Steuerprofil() }
    private var angaben: Jahresangaben {
        alleJahresangaben.first { $0.jahr == jahr } ?? Jahresangaben(jahr: jahr)
    }
    private var steuerjahr: Steuerjahr { Steuerjahr.fuer(jahr) }

    private var euer: EinnahmenÜberschussRechnung.Ergebnis { euerFuer(jahr) }

    private func euerFuer(_ welchesJahr: Int) -> EinnahmenÜberschussRechnung.Ergebnis {
        EinnahmenÜberschussRechnung.berechnen(
            belege: belege, wirtschaftsgüter: wirtschaftsgüter,
            jahr: welchesJahr, kleinunternehmer: profil.kleinunternehmer
        )
    }

    private var schätzung: Steuerschaetzung.Ergebnis {
        Steuerschaetzung.berechnen(Steuerschaetzung.Eingaben(
            profil: profil, jahresangaben: angaben,
            gewinn: euer.gewinn, steuerjahr: steuerjahr
        ))
    }

    /// Wie sich der Gewinn gegenüber dem Vorjahr entwickelt hat.
    ///
    /// Nur wenn im Vorjahr überhaupt etwas erfasst ist - sonst wäre die Zahl entweder
    /// unendlich oder schlicht erfunden.
    private var veränderungZumVorjahr: Double? {
        let vorher = euerFuer(jahr - 1).gewinn
        guard vorher > 0 else { return nil }
        return (euer.gewinn - vorher).alsDouble / vorher.alsDouble
    }

    private var desJahres: [Beleg] { belege.filter { $0.jahr == jahr } }

    private var monatswerte: [Decimal] {
        var werte = [Decimal](repeating: 0, count: 12)
        for beleg in desJahres where (1...12).contains(beleg.monat) {
            werte[beleg.monat - 1] += beleg.art == .einnahme ? beleg.bruttoBetrag
                                                             : -beleg.bruttoBetrag
        }
        return werte
    }

    private var letzteBelege: [Beleg] { Array(desJahres.prefix(5)) }

    // MARK: - Aufbau

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    kopfzeile
                    gewinnkarte

                    if euer.anzahlBelege == 0 {
                        leererZustand
                    } else {
                        kacheln
                        rücklagekarte
                        if !letzteBelege.isEmpty { letzteBewegungen }
                    }

                    hinweisWennJahrUngeprüft
                }
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .aufGrund()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Bausteine

    private var kopfzeile: some View {
        HStack {
            Text("Übersicht")
                .font(Stil.titel())
                .foregroundStyle(Stil.schrift)
            Spacer()
            Jahrespille(jahr: $jahr)
            BelegErfassenSchaltfläche(jahr: jahr)
        }
        .padding(.horizontal, Stil.rand)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    private var gewinnkarte: some View {
        VStack(alignment: .leading, spacing: 18) {
            Betragskopf(
                beschriftung: "Gewinn \(String(jahr))",
                betrag: euer.gewinn,
                mitVorzeichen: false,
                veränderung: veränderungZumVorjahr,
                beischrift: euer.anzahlBelege == 1
                    ? "aus 1 Beleg" : "aus \(euer.anzahlBelege) Belegen"
            )
            Monatsbalken(werte: monatswerte, hervorgehoben: desJahres.map(\.monat).max().map { $0 - 1 })
        }
        .alsKarte()
        .padding(.horizontal, Stil.rand)
    }

    private var kacheln: some View {
        HStack(spacing: 12) {
            Kachel(
                beschriftung: "Einnahmen",
                wert: Formatierung.euro(euer.summeEinnahmen, mitCent: false),
                beischrift: profil.kleinunternehmer ? "brutto" : "netto",
                farbe: Stil.haben,
                symbol: "arrow.down"
            )
            Kachel(
                beschriftung: "Ausgaben",
                wert: Formatierung.euro(euer.summeAusgaben, mitCent: false),
                beischrift: euer.anzahlBelege == 1 ? "1 Beleg" : "\(euer.anzahlBelege) Belege",
                symbol: "arrow.up"
            )
        }
        .padding(.horizontal, Stil.rand)
        .padding(.top, 12)
    }

    private var rücklagekarte: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text(schätzung.istErstattung ? "Voraussichtliche Erstattung" : "Noch zurückzulegen")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Stil.schriftGedämpft)
                Spacer()
                Statusmarke(
                    text: Formatierung.prozent(schätzung.durchschnittssteuersatz, nachkommastellen: 0)
                        + " Steuersatz",
                    farbe: Stil.schriftGedämpft
                )
            }

            Text(Formatierung.euro(abs(schätzung.offenerBetrag)))
                .font(Stil.hauptzahl(34))
                .foregroundStyle(schätzung.istErstattung ? Stil.haben : Stil.warnung)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if euer.gewinn > 0 {
                balkenAnteil(min(schätzung.ruecklagenquote, 1))
                Text("\(Formatierung.prozent(schätzung.ruecklagenquote, nachkommastellen: 0)) des Gewinns gehören dem Finanzamt")
                    .font(.system(size: 12))
                    .foregroundStyle(Stil.schriftLeise)
            }

            Hinweiszeile(text: begründung)
        }
        .alsKarte()
        .padding(.horizontal, Stil.rand)
        .padding(.top, 12)
    }

    private func balkenAnteil(_ anteil: Double) -> some View {
        GeometryReader { fläche in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                Capsule()
                    .fill(Stil.warnung)
                    .frame(width: max(fläche.size.width * anteil, 4))
            }
        }
        .frame(height: 7)
    }

    private var begründung: String {
        let vorauszahlung = schätzung.geleisteteVorauszahlungen
        if vorauszahlung > 0 {
            return "Steuerlast \(Formatierung.euro(schätzung.gesamtbelastung, mitCent: false)) "
                + "abzüglich bereits geleisteter Vorauszahlungen von "
                + "\(Formatierung.euro(vorauszahlung, mitCent: false))."
        }
        return "Geschätzt auf Basis der erfassten Belege. Vorauszahlungen im Profil eintragen, "
            + "damit die Zahl stimmt."
    }

    private var letzteBewegungen: some View {
        VStack(alignment: .leading, spacing: 0) {
            Abschnittskopf(text: "Zuletzt erfasst")
                .padding(.horizontal, Stil.rand + 4)

            VStack(spacing: 0) {
                ForEach(Array(letzteBelege.enumerated()), id: \.element.id) { stelle, beleg in
                    NavigationLink {
                        BelegBearbeitenAnsicht(beleg: beleg, vorgabeJahr: jahr)
                    } label: {
                        BelegZeile(beleg: beleg)
                    }
                    .buttonStyle(.plain)

                    if stelle < letzteBelege.count - 1 {
                        Trennzeile(einzug: Stil.symbolgröße + 13)
                    }
                }
            }
            .padding(.horizontal, 15)
            .alsGlas()
            .padding(.horizontal, Stil.rand)
        }
    }

    private var leererZustand: some View {
        VStack(spacing: 16) {
            LeerHinweis(
                symbol: "doc.text.viewfinder",
                titel: "Noch keine Belege für \(String(jahr))",
                text: "Belege abfotografieren – Händler, Betrag, Datum und Steuersatz werden vorgeschlagen. Auch ein ganzer Stapel auf einmal."
            )
            BelegErfassenSchaltfläche(jahr: jahr, kompakt: false)
                .padding(.horizontal, 24)
                .padding(.bottom, 22)
        }
        .alsKarte(polster: 0)
        .padding(.horizontal, Stil.rand)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var hinweisWennJahrUngeprüft: some View {
        if !steuerjahr.amtlichGeprüft {
            Hinweiszeile(
                text: "Die Tarifwerte für \(String(steuerjahr.jahr)) sind noch nicht gegen die amtliche Tabelle geprüft.",
                symbol: "exclamationmark.triangle",
                farbe: Stil.warnung
            )
            .alsKarte(polster: 14)
            .padding(.horizontal, Stil.rand)
            .padding(.top, 12)
        }
    }
}

/// Eine Belegzeile, wie sie in Übersicht und Belegliste erscheint.
struct BelegZeile: View {

    let beleg: Beleg

    var body: some View {
        Buchungszeile(
            kategorie: beleg.kategorie,
            bezeichnung: beleg.bezeichnung.isEmpty ? beleg.kategorie.bezeichnung
                                                   : beleg.bezeichnung,
            beischrift: "\(Formatierung.datum(beleg.datum)) · \(beleg.kategorie.bezeichnung)",
            betrag: beleg.bruttoBetrag,
            istEinnahme: beleg.art == .einnahme,
            mitBild: beleg.belegbildDatei != nil,
            unvollständig: beleg.bruttoBetrag == 0
        )
    }
}

#Preview {
    UebersichtAnsicht(jahr: .constant(Calendar.kalender.component(.year, from: Date())))
        .modelContainer(Datenbank.vorschauContainer())
}
