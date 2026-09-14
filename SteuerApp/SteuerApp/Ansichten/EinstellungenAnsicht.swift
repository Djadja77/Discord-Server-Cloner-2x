import SwiftUI
import SwiftData

/// Das Steuerprofil - einmal ausfuellen, danach nur noch bei Aenderungen anfassen.
///
/// Die Qualitaet der Schaetzung haengt fast vollstaendig an diesen Angaben. Deshalb erklaert
/// jede Zeile, wofuer sie gebraucht wird, statt nur ein Feld anzubieten.
struct EinstellungenAnsicht: View {

    @Environment(\.modelContext) private var kontext
    @Query private var profile: [Steuerprofil]

    /// Faellt nur in dem Moment auf ein leeres Profil zurueck, in dem das echte noch nicht
    /// angelegt ist - `profilSicherstellen` holt das beim Erscheinen sofort nach.
    private var profil: Steuerprofil { profile.first ?? Steuerprofil() }

    var body: some View {
        NavigationStack {
            Form {
                taetigkeitAbschnitt
                umsatzsteuerAbschnitt
                veranlagungAbschnitt
                vorsorgeAbschnitt
                weitereAbzuegeAbschnitt
                vorauszahlungAbschnitt
                ueberDieApp
            }
            .navigationTitle("Profil")
            .onAppear { Datenbank.profilSicherstellen(in: kontext) }
        }
    }

    // MARK: - Abschnitte

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

            BetragsFeld(
                titel: "Weitere Einkuenfte",
                betrag: Binding(
                    get: { profil.weitereEinkuenfte },
                    set: { profil.weitereEinkuenfte = $0 }
                ),
                hinweis: "Arbeitslohn, Vermietung, Rente - pro Jahr"
            )
        } header: {
            Text("Veranlagung")
        } footer: {
            Text("Bei Zusammenveranlagung gilt der Splittingtarif. Weitere Einkuenfte erhoehen den Steuersatz auf den Gewinn.")
        }
    }

    private var vorsorgeAbschnitt: some View {
        Section {
            BetragsFeld(
                titel: "Altersvorsorge",
                betrag: Binding(
                    get: { profil.beitragAltersvorsorge },
                    set: { profil.beitragAltersvorsorge = $0 }
                ),
                hinweis: "Rentenversicherung, Versorgungswerk, Ruerup"
            )
            BetragsFeld(
                titel: "Kranken- und Pflegeversicherung",
                betrag: Binding(
                    get: { profil.beitragKrankenPflegeBasis },
                    set: { profil.beitragKrankenPflegeBasis = $0 }
                ),
                hinweis: "nur der Basisbeitrag, ohne Wahlleistungen"
            )
            BetragsFeld(
                titel: "Sonstige Versicherungen",
                betrag: Binding(
                    get: { profil.beitragSonstigeVersicherungen },
                    set: { profil.beitragSonstigeVersicherungen = $0 }
                ),
                hinweis: "Haftpflicht, Unfall, Berufsunfaehigkeit"
            )
        } header: {
            Text("Vorsorgeaufwendungen pro Jahr")
        } footer: {
            Text("Fuer Selbstaendige ist das meist der groesste Abzugsposten. Ohne diese Angaben schaetzt die App die Steuer deutlich zu hoch.")
        }
    }

    private var weitereAbzuegeAbschnitt: some View {
        Section {
            BetragsFeld(
                titel: "Uebrige Sonderausgaben",
                betrag: Binding(
                    get: { profil.weitereSonderausgaben },
                    set: { profil.weitereSonderausgaben = $0 }
                ),
                hinweis: "Spenden, Kirchensteuer des Vorjahres, Unterhalt"
            )
            BetragsFeld(
                titel: "Aussergewoehnliche Belastungen",
                betrag: Binding(
                    get: { profil.aussergewoehnlicheBelastungen },
                    set: { profil.aussergewoehnlicheBelastungen = $0 }
                ),
                hinweis: "nach Abzug der zumutbaren Belastung"
            )
        } header: {
            Text("Weitere Abzuege")
        }
    }

    private var vorauszahlungAbschnitt: some View {
        Section {
            BetragsFeld(
                titel: "Geleistete Vorauszahlungen",
                betrag: Binding(
                    get: { profil.geleisteteVorauszahlungen },
                    set: { profil.geleisteteVorauszahlungen = $0 }
                ),
                hinweis: "Summe der Quartalszahlungen dieses Jahres"
            )
        } header: {
            Text("Einkommensteuer-Vorauszahlungen")
        } footer: {
            Text("Vorauszahlungen sind jeweils am 10. Maerz, 10. Juni, 10. September und 10. Dezember faellig.")
        }
    }

    private var ueberDieApp: some View {
        Section {
            ForEach(Steuerjahr.alle) { jahr in
                HStack {
                    Text(String(jahr.jahr))
                    Spacer()
                    Label(
                        jahr.amtlichGeprueft ? "geprueft" : "ungeprueft",
                        systemImage: jahr.amtlichGeprueft ? "checkmark.circle" : "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(jahr.amtlichGeprueft ? Color.green : Color.orange)
                }
            }
        } header: {
            Text("Hinterlegte Steuerjahre")
        } footer: {
            Text("Die App rechnet nach den Vorschriften fuer Einkommensteuer, Solidaritaetszuschlag, Kirchensteuer und Gewerbesteuer. Sie ersetzt keine Steuerberatung.")
        }
    }
}

#Preview {
    EinstellungenAnsicht()
        .modelContainer(Datenbank.vorschauContainer())
}
