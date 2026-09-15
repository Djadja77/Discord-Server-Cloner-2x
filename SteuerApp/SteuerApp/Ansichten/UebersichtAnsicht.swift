import SwiftUI
import SwiftData

/// Die Startseite: Wie laeuft das Jahr, und wie viel Geld gehoert dem Finanzamt?
struct UebersichtAnsicht: View {

    @Binding var jahr: Int
    @Query(sort: \Beleg.datum, order: .reverse) private var belege: [Beleg]
    @Query private var profile: [Steuerprofil]
    @Query private var alleJahresangaben: [Jahresangaben]
    @Query private var wirtschaftsgueter: [Wirtschaftsgut]

    private var profil: Steuerprofil { profile.first ?? Steuerprofil() }
    private var angaben: Jahresangaben {
        alleJahresangaben.first { $0.jahr == jahr } ?? Jahresangaben(jahr: jahr)
    }
    private var steuerjahr: Steuerjahr { Steuerjahr.fuer(jahr) }

    private var euer: EinnahmenUeberschussRechnung.Ergebnis {
        EinnahmenUeberschussRechnung.berechnen(
            belege: belege, wirtschaftsgueter: wirtschaftsgueter,
            jahr: jahr, kleinunternehmer: profil.kleinunternehmer
        )
    }

    private var schaetzung: Steuerschaetzung.Ergebnis {
        Steuerschaetzung.berechnen(Steuerschaetzung.Eingaben(
            profil: profil, jahresangaben: angaben,
            gewinn: euer.gewinn, steuerjahr: steuerjahr
        ))
    }

    private var letzteBelege: [Beleg] {
        Array(belege.filter { $0.jahr == jahr }.prefix(5))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    kennzahlen
                    ruecklage
                    if !letzteBelege.isEmpty { letzteBewegungen }
                    if euer.anzahlBelege == 0 { leererZustand }
                    hinweisWennJahrUngeprueft
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Uebersicht \(String(jahr))")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { JahresWaehler(jahr: $jahr) }
                ToolbarItem(placement: .topBarTrailing) {
                    BelegErfassenSchaltflaeche(jahr: jahr)
                }
            }
        }
    }

    // MARK: - Bausteine

    private var kennzahlen: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                KennzahlKachel(
                    titel: "Betriebseinnahmen",
                    wert: Formatierung.euro(euer.summeEinnahmen, mitCent: false),
                    hinweis: profil.kleinunternehmer ? "brutto" : "netto",
                    symbol: "arrow.down.circle"
                )
                KennzahlKachel(
                    titel: "Betriebsausgaben",
                    wert: Formatierung.euro(euer.summeAusgaben, mitCent: false),
                    hinweis: "\(euer.anzahlBelege) Belege",
                    symbol: "arrow.up.circle"
                )
            }
            HStack(spacing: 12) {
                KennzahlKachel(
                    titel: "Gewinn",
                    wert: Formatierung.euro(euer.gewinn, mitCent: false),
                    hinweis: "vor Steuern",
                    farbe: euer.gewinn < 0 ? .red : .primary,
                    symbol: "chart.line.uptrend.xyaxis"
                )
                KennzahlKachel(
                    titel: "Geschaetzte Steuer",
                    wert: Formatierung.euro(schaetzung.gesamtbelastung, mitCent: false),
                    hinweis: "Durchschnittssatz \(Formatierung.prozent(schaetzung.durchschnittssteuersatz))",
                    farbe: .orange,
                    symbol: "building.columns"
                )
            }
        }
    }

    /// Bewusst kein NavigationLink: die Schaetzung hat einen eigenen Tab. Ein zweiter Weg
    /// dorthin wuerde nur eine zweite Navigationsleiste erzeugen.
    /// Bewusst kein NavigationLink: die Schaetzung hat einen eigenen Tab. Ein zweiter Weg
    /// dorthin wuerde nur eine zweite Navigationsleiste erzeugen.
    private var ruecklage: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                schaetzung.istErstattung ? "Voraussichtliche Erstattung" : "Noch zurueckzulegen",
                systemImage: schaetzung.istErstattung ? "arrow.down.circle.fill" : "banknote.fill"
            )
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)

            Text(Formatierung.euro(abs(schaetzung.offenerBetrag)))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(schaetzung.istErstattung ? Color.green : Color.orange)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(begruendung)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if euer.gewinn > 0 {
                ProgressView(value: min(schaetzung.ruecklagenquote, 1))
                    .tint(.orange)
                Text("\(Formatierung.prozent(schaetzung.ruecklagenquote, nachkommastellen: 0)) des Gewinns gehoeren dem Finanzamt")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
    }

    private var begruendung: String {
        let vorauszahlung = schaetzung.geleisteteVorauszahlungen
        if vorauszahlung > 0 {
            return "Steuerlast \(Formatierung.euro(schaetzung.gesamtbelastung, mitCent: false)) "
                + "abzueglich bereits geleisteter Vorauszahlungen von "
                + "\(Formatierung.euro(vorauszahlung, mitCent: false))."
        }
        return "Geschaetzt auf Basis der erfassten Belege. Vorauszahlungen im Profil eintragen, "
            + "damit die Zahl stimmt."
    }

    private var letzteBewegungen: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Zuletzt erfasst")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(letzteBelege) { beleg in
                    NavigationLink {
                        BelegBearbeitenAnsicht(beleg: beleg, vorgabeJahr: jahr)
                    } label: {
                        BelegZeile(beleg: beleg)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if beleg.id != letzteBelege.last?.id {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var leererZustand: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.viewfinder")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Noch keine Belege fuer \(String(jahr))")
                .font(.headline)
            Text("Belege abfotografieren \u{2013} Haendler, Betrag, Datum und Steuersatz werden vorgeschlagen. Auch ein ganzer Stapel auf einmal.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            BelegErfassenSchaltflaeche(jahr: jahr, kompakt: false)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var hinweisWennJahrUngeprueft: some View {
        if !steuerjahr.amtlichGeprueft {
            Label(
                "Die Tarifwerte fuer \(String(steuerjahr.jahr)) sind noch nicht gegen die amtliche Tabelle geprueft.",
                systemImage: "exclamationmark.triangle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// Eine Belegzeile, wie sie in Uebersicht und Belegliste erscheint.
struct BelegZeile: View {

    let beleg: Beleg

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: beleg.kategorie.symbol)
                .font(.system(size: 15))
                .frame(width: 32, height: 32)
                .background(
                    (beleg.art == .einnahme ? Color.green : Color.orange).opacity(0.15),
                    in: Circle()
                )
                .foregroundStyle(beleg.art == .einnahme ? Color.green : Color.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(beleg.bezeichnung.isEmpty ? beleg.kategorie.bezeichnung : beleg.bezeichnung)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(Formatierung.datum(beleg.datum))
                    Text("-")
                    Text(beleg.kategorie.bezeichnung).lineLimit(1)
                    if beleg.belegbildDatei != nil {
                        Image(systemName: "paperclip")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(Formatierung.euro(beleg.bruttoBetrag))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(beleg.art == .einnahme ? Color.green : .primary)
        }
    }
}

#Preview {
    UebersichtAnsicht(jahr: .constant(Calendar.kalender.component(.year, from: Date())))
        .modelContainer(Datenbank.vorschauContainer())
}
