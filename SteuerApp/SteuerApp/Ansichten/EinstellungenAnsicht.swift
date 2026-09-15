import SwiftUI
import SwiftData

/// Das Steuerprofil.
///
/// Oben stehen die Angaben, die jahrelang gleich bleiben, darunter die des gewählten
/// Jahres. Diese Trennung ist wichtig: Beiträge, Vorauszahlungen und Kinder ändern sich
/// jährlich, die Rechtsform praktisch nie.
///
/// Die Qualität der Schätzung hängt fast vollständig an diesen Angaben. Deshalb erklärt
/// jede Zeile, wofür sie gebraucht wird, statt nur ein Feld anzubieten.
struct EinstellungenAnsicht: View {

    @Binding var jahr: Int
    @Environment(\.modelContext) private var kontext
    @Query private var profile: [Steuerprofil]
    @Query private var alleJahresangaben: [Jahresangaben]

    /// Fällt nur in dem Moment auf leere Objekte zurück, in dem die echten noch nicht
    /// angelegt sind - `stammdatenSicherstellen` holt das beim Erscheinen sofort nach.
    private var profil: Steuerprofil { profile.first ?? Steuerprofil() }
    private var angaben: Jahresangaben {
        alleJahresangaben.first { $0.jahr == jahr } ?? Jahresangaben(jahr: jahr)
    }
    private var steuerjahr: Steuerjahr { Steuerjahr.fuer(jahr) }

    var body: some View {
        NavigationStack {
            Form {
                tätigkeitAbschnitt
                umsatzsteuerAbschnitt
                veranlagungAbschnitt

                jahresangabenKopf
                einkünfteAbschnitt
                vorsorgeAbschnitt
                kinderAbschnitt
                weitereAbzügeAbschnitt
                verlustvortragAbschnitt
                vorauszahlungAbschnitt

                hinterlegteJahre
            }
            .alsListe()
            .navigationTitle("Profil")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { JahresWähler(jahr: $jahr) }
            }
            .onAppear(perform: stammdatenSicherstellen)
        }
    }

    private func stammdatenSicherstellen() {
        Datenbank.profilSicherstellen(in: kontext)
        Datenbank.jahresangabenSicherstellen(fuer: jahr, in: kontext)
    }

    // MARK: - Jahresübergreifend

    private var tätigkeitAbschnitt: some View {
        Section {
            Picker("Tätigkeit", selection: Binding(
                get: { profil.tätigkeitsart },
                set: { profil.tätigkeitsart = $0 }
            )) {
                ForEach(Tätigkeitsart.allCases) { Text($0.bezeichnung).tag($0) }
            }

            if profil.tätigkeitsart == .gewerblich {
                BetragsFeld(
                    titel: "Hebesatz in Prozent",
                    betrag: Binding(
                        get: { profil.gewerbesteuerHebesatz },
                        set: { profil.gewerbesteuerHebesatz = $0 }
                    ),
                    hinweis: "Steht im Gewerbesteuerbescheid der Gemeinde"
                )
            }
        } header: {
            Text("Tätigkeit")
        } footer: {
            Text(profil.tätigkeitsart == .freiberuflich
                 ? "Freiberufler zahlen keine Gewerbesteuer."
                 : "Gewerbesteuer fällt erst ab einem Gewinn von 24.500 Euro an.")
        }
    }

    private var umsatzsteuerAbschnitt: some View {
        Section {
            Toggle("Kleinunternehmer (§ 19 UStG)", isOn: Binding(
                get: { profil.kleinunternehmer },
                set: { profil.kleinunternehmer = $0 }
            ))
        } header: {
            Text("Umsatzsteuer")
        } footer: {
            Text("Als Kleinunternehmer weist du keine Umsatzsteuer aus und darfst keine Vorsteuer abziehen. Die App rechnet dann durchgehend mit Bruttobeträgen.")
        }
    }

    private var veranlagungAbschnitt: some View {
        Section {
            Picker("Veranlagung", selection: Binding(
                get: { profil.veranlagungsart },
                set: { profil.veranlagungsart = $0 }
            )) {
                ForEach(Veranlagungsart.allCases) { Text($0.bezeichnung).tag($0) }
            }

            Picker("Kirchensteuer", selection: Binding(
                get: { profil.kirchensteuersatz },
                set: { profil.kirchensteuersatz = $0 }
            )) {
                ForEach(Kirchensteuersatz.allCases) { Text($0.bezeichnung).tag($0) }
            }
        } header: {
            Text("Veranlagung")
        } footer: {
            Text("Bei Zusammenveranlagung gilt der Splittingtarif.")
        }
    }

    // MARK: - Jahresabhängig

    private var jahresangabenKopf: some View {
        Section {
            EmptyView()
        } header: {
            Text("Angaben für \(String(jahr))")
                .font(.headline)
                .textCase(nil)
        } footer: {
            Text("Diese Werte gelten nur für \(String(jahr)). Ein Wechsel des Jahres oben links öffnet einen eigenen Satz Angaben.")
        }
    }

    private var einkünfteAbschnitt: some View {
        Section {
            BetragsFeld(
                titel: "Weitere Einkünfte",
                betrag: jahresbindung(\.weitereEinkuenfte),
                hinweis: "Arbeitslohn, Vermietung, Rente"
            )
        } footer: {
            Text("Weitere Einkünfte erhöhen den Steuersatz auf den Gewinn.")
        }
    }

    private var vorsorgeAbschnitt: some View {
        Section {
            BetragsFeld(
                titel: "Altersvorsorge",
                betrag: jahresbindung(\.beitragAltersvorsorge),
                hinweis: "Rentenversicherung, Versorgungswerk, Rürup"
            )
            BetragsFeld(
                titel: "Kranken- und Pflegeversicherung",
                betrag: jahresbindung(\.beitragKrankenPflegeBasis),
                hinweis: "nur der Basisbeitrag, ohne Wahlleistungen"
            )
            BetragsFeld(
                titel: "Sonstige Versicherungen",
                betrag: jahresbindung(\.beitragSonstigeVersicherungen),
                hinweis: "Haftpflicht, Unfall, Berufsunfähigkeit"
            )
        } header: {
            Text("Vorsorgeaufwendungen")
        } footer: {
            Text("Für Selbständige ist das meist der größte Abzugsposten. Ohne diese Angaben schätzt die App die Steuer deutlich zu hoch.")
        }
    }

    private var kinderAbschnitt: some View {
        Section {
            Stepper(
                "Kinder: \(angaben.anzahlKinder)",
                value: Binding(
                    get: { angaben.anzahlKinder },
                    set: { angaben.anzahlKinder = max(0, $0) }
                ),
                in: 0...12
            )

            if angaben.anzahlKinder > 0 {
                if profil.veranlagungsart == .einzel {
                    Toggle("Voller Kinderfreibetrag", isOn: Binding(
                        get: { angaben.vollerKinderfreibetrag },
                        set: { angaben.vollerKinderfreibetrag = $0 }
                    ))
                }

                ZeileMitBetrag(
                    bezeichnung: "Freibetrag je Kind",
                    betrag: (steuerjahr.kinderfreibetragGesamt * kinderanteil).gerundet(),
                    unterzeile: "Kinderfreibetrag und Betreuungsfreibetrag"
                )
                ZeileMitBetrag(
                    bezeichnung: "Kindergeld je Kind",
                    betrag: (steuerjahr.kindergeldProJahr * kinderanteil).gerundet(),
                    unterzeile: "Vergleichsgröße der Günstigerprüfung"
                )
            }
        } header: {
            Text("Kinder")
        } footer: {
            Text("Das Finanzamt rechnet Kindergeld und Freibeträge gegeneinander und setzt automatisch das Günstigere an. Solidaritätszuschlag und Kirchensteuer werden immer mit Freibeträgen berechnet.")
        }
    }

    private var kinderanteil: Decimal {
        Kinderfreibetrag.anteil(
            splitting: profil.veranlagungsart.splitting,
            vollerFreibetrag: angaben.vollerKinderfreibetrag
        )
    }

    private var weitereAbzügeAbschnitt: some View {
        Section {
            BetragsFeld(
                titel: "Übrige Sonderausgaben",
                betrag: jahresbindung(\.weitereSonderausgaben),
                hinweis: "Spenden, Kirchensteuer des Vorjahres, Unterhalt"
            )
            BetragsFeld(
                titel: "Außergewöhnliche Belastungen",
                betrag: jahresbindung(\.aussergewoehnlicheBelastungen),
                hinweis: "nach Abzug der zumutbaren Belastung"
            )
        } header: {
            Text("Weitere Abzüge")
        }
    }

    private var verlustvortragAbschnitt: some View {
        Section {
            BetragsFeld(
                titel: "Verlustvortrag aus Vorjahren",
                betrag: jahresbindung(\.verlustvortragAusVorjahren),
                hinweis: "Stand laut Feststellungsbescheid"
            )
        } header: {
            Text("Verlustvortrag")
        } footer: {
            Text("Verluste früherer Jahre mindern das zu versteuernde Einkommen (§ 10d EStG). Maßgeblich ist der gesondert festgestellte Betrag aus dem letzten Bescheid.")
        }
    }

    private var vorauszahlungAbschnitt: some View {
        Section {
            BetragsFeld(
                titel: "Geleistete Vorauszahlungen",
                betrag: jahresbindung(\.geleisteteVorauszahlungen),
                hinweis: "Summe der Quartalszahlungen in \(String(jahr))"
            )
        } header: {
            Text("Einkommensteuer-Vorauszahlungen")
        } footer: {
            Text("Vorauszahlungen sind jeweils am 10. März, 10. Juni, 10. September und 10. Dezember fällig.")
        }
    }

    private var hinterlegteJahre: some View {
        Section {
            ForEach(Steuerjahr.alle) { eintrag in
                HStack {
                    Text(String(eintrag.jahr))
                    Spacer()
                    Label(
                        eintrag.amtlichGeprüft ? "geprüft" : "ungeprüft",
                        systemImage: eintrag.amtlichGeprüft
                            ? "checkmark.circle" : "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(eintrag.amtlichGeprüft ? Color.green : Color.orange)
                }
            }
        } header: {
            Text("Hinterlegte Steuerjahre")
        } footer: {
            Text("Die App rechnet nach den Vorschriften für Einkommensteuer, Solidaritätszuschlag, Kirchensteuer und Gewerbesteuer. Sie ersetzt keine Steuerberatung.")
        }
    }

    // MARK: - Hilfsmittel

    /// Bindung an ein Geldfeld der Jahresangaben.
    ///
    /// Spart pro Feld vier Zeilen `Binding(get:set:)` und macht damit sichtbar, worum es in
    /// den Abschnitten oben tatsächlich geht.
    private func jahresbindung(
        _ pfad: ReferenceWritableKeyPath<Jahresangaben, Decimal>
    ) -> Binding<Decimal> {
        Binding(
            get: { angaben[keyPath: pfad] },
            set: { angaben[keyPath: pfad] = $0 }
        )
    }
}

#Preview {
    EinstellungenAnsicht(jahr: .constant(Calendar.kalender.component(.year, from: Date())))
        .modelContainer(Datenbank.vorschauContainer())
}
