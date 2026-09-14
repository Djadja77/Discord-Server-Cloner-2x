import SwiftUI
import SwiftData

/// Das Steuerprofil.
///
/// Oben stehen die Angaben, die jahrelang gleich bleiben, darunter die des gewaehlten
/// Jahres. Diese Trennung ist wichtig: Beitraege, Vorauszahlungen und Kinder aendern sich
/// jaehrlich, die Rechtsform praktisch nie.
///
/// Die Qualitaet der Schaetzung haengt fast vollstaendig an diesen Angaben. Deshalb erklaert
/// jede Zeile, wofuer sie gebraucht wird, statt nur ein Feld anzubieten.
struct EinstellungenAnsicht: View {

    @Binding var jahr: Int
    @Environment(\.modelContext) private var kontext
    @Query private var profile: [Steuerprofil]
    @Query private var alleJahresangaben: [Jahresangaben]

    /// Faellt nur in dem Moment auf leere Objekte zurueck, in dem die echten noch nicht
    /// angelegt sind - `stammdatenSicherstellen` holt das beim Erscheinen sofort nach.
    private var profil: Steuerprofil { profile.first ?? Steuerprofil() }
    private var angaben: Jahresangaben {
        alleJahresangaben.first { $0.jahr == jahr } ?? Jahresangaben(jahr: jahr)
    }
    private var steuerjahr: Steuerjahr { Steuerjahr.fuer(jahr) }

    var body: some View {
        NavigationStack {
            Form {
                taetigkeitAbschnitt
                umsatzsteuerAbschnitt
                veranlagungAbschnitt

                jahresangabenKopf
                einkuenfteAbschnitt
                vorsorgeAbschnitt
                kinderAbschnitt
                weitereAbzuegeAbschnitt
                verlustvortragAbschnitt
                vorauszahlungAbschnitt

                hinterlegteJahre
            }
            .navigationTitle("Profil")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { JahresWaehler(jahr: $jahr) }
            }
            .onAppear(perform: stammdatenSicherstellen)
        }
    }

    private func stammdatenSicherstellen() {
        Datenbank.profilSicherstellen(in: kontext)
        Datenbank.jahresangabenSicherstellen(fuer: jahr, in: kontext)
    }

    // MARK: - Jahresuebergreifend

    private var taetigkeitAbschnitt: some View {
        Section {
            Picker("Taetigkeit", selection: Binding(
                get: { profil.taetigkeitsart },
                set: { profil.taetigkeitsart = $0 }
            )) {
                ForEach(Taetigkeitsart.allCases) { Text($0.bezeichnung).tag($0) }
            }

            if profil.taetigkeitsart == .gewerblich {
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
            Text("Taetigkeit")
        } footer: {
            Text(profil.taetigkeitsart == .freiberuflich
                 ? "Freiberufler zahlen keine Gewerbesteuer."
                 : "Gewerbesteuer faellt erst ab einem Gewinn von 24.500 Euro an.")
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
            Text("Als Kleinunternehmer weist du keine Umsatzsteuer aus und darfst keine Vorsteuer abziehen. Die App rechnet dann durchgehend mit Bruttobetraegen.")
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

    // MARK: - Jahresabhaengig

    private var jahresangabenKopf: some View {
        Section {
            EmptyView()
        } header: {
            Text("Angaben fuer \(String(jahr))")
                .font(.headline)
                .textCase(nil)
        } footer: {
            Text("Diese Werte gelten nur fuer \(String(jahr)). Ein Wechsel des Jahres oben links oeffnet einen eigenen Satz Angaben.")
        }
    }

    private var einkuenfteAbschnitt: some View {
        Section {
            BetragsFeld(
                titel: "Weitere Einkuenfte",
                betrag: jahresbindung(\.weitereEinkuenfte),
                hinweis: "Arbeitslohn, Vermietung, Rente"
            )
        } footer: {
            Text("Weitere Einkuenfte erhoehen den Steuersatz auf den Gewinn.")
        }
    }

    private var vorsorgeAbschnitt: some View {
        Section {
            BetragsFeld(
                titel: "Altersvorsorge",
                betrag: jahresbindung(\.beitragAltersvorsorge),
                hinweis: "Rentenversicherung, Versorgungswerk, Ruerup"
            )
            BetragsFeld(
                titel: "Kranken- und Pflegeversicherung",
                betrag: jahresbindung(\.beitragKrankenPflegeBasis),
                hinweis: "nur der Basisbeitrag, ohne Wahlleistungen"
            )
            BetragsFeld(
                titel: "Sonstige Versicherungen",
                betrag: jahresbindung(\.beitragSonstigeVersicherungen),
                hinweis: "Haftpflicht, Unfall, Berufsunfaehigkeit"
            )
        } header: {
            Text("Vorsorgeaufwendungen")
        } footer: {
            Text("Fuer Selbstaendige ist das meist der groesste Abzugsposten. Ohne diese Angaben schaetzt die App die Steuer deutlich zu hoch.")
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
                    unterzeile: "Vergleichsgroesse der Guenstigerpruefung"
                )
            }
        } header: {
            Text("Kinder")
        } footer: {
            Text("Das Finanzamt rechnet Kindergeld und Freibetraege gegeneinander und setzt automatisch das Guenstigere an. Solidaritaetszuschlag und Kirchensteuer werden immer mit Freibetraegen berechnet.")
        }
    }

    private var kinderanteil: Decimal {
        Kinderfreibetrag.anteil(
            splitting: profil.veranlagungsart.splitting,
            vollerFreibetrag: angaben.vollerKinderfreibetrag
        )
    }

    private var weitereAbzuegeAbschnitt: some View {
        Section {
            BetragsFeld(
                titel: "Uebrige Sonderausgaben",
                betrag: jahresbindung(\.weitereSonderausgaben),
                hinweis: "Spenden, Kirchensteuer des Vorjahres, Unterhalt"
            )
            BetragsFeld(
                titel: "Aussergewoehnliche Belastungen",
                betrag: jahresbindung(\.aussergewoehnlicheBelastungen),
                hinweis: "nach Abzug der zumutbaren Belastung"
            )
        } header: {
            Text("Weitere Abzuege")
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
            Text("Verluste frueherer Jahre mindern das zu versteuernde Einkommen (§ 10d EStG). Massgeblich ist der gesondert festgestellte Betrag aus dem letzten Bescheid.")
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
            Text("Vorauszahlungen sind jeweils am 10. Maerz, 10. Juni, 10. September und 10. Dezember faellig.")
        }
    }

    private var hinterlegteJahre: some View {
        Section {
            ForEach(Steuerjahr.alle) { eintrag in
                HStack {
                    Text(String(eintrag.jahr))
                    Spacer()
                    Label(
                        eintrag.amtlichGeprueft ? "geprueft" : "ungeprueft",
                        systemImage: eintrag.amtlichGeprueft
                            ? "checkmark.circle" : "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(eintrag.amtlichGeprueft ? Color.green : Color.orange)
                }
            }
        } header: {
            Text("Hinterlegte Steuerjahre")
        } footer: {
            Text("Die App rechnet nach den Vorschriften fuer Einkommensteuer, Solidaritaetszuschlag, Kirchensteuer und Gewerbesteuer. Sie ersetzt keine Steuerberatung.")
        }
    }

    // MARK: - Hilfsmittel

    /// Bindung an ein Geldfeld der Jahresangaben.
    ///
    /// Spart pro Feld vier Zeilen `Binding(get:set:)` und macht damit sichtbar, worum es in
    /// den Abschnitten oben tatsaechlich geht.
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
