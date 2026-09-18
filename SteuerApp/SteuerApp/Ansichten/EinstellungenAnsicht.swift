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
    @Query private var alleBelege: [Beleg]
    @Query private var wirtschaftsgüter: [Wirtschaftsgut]

    @State private var löschenGefragt = false

    /// Fällt nur in dem Moment auf leere Objekte zurück, in dem die echten noch nicht
    /// angelegt sind - `stammdatenSicherstellen` holt das beim Erscheinen sofort nach.
    private var profil: Steuerprofil { profile.first ?? Steuerprofil() }
    private var angaben: Jahresangaben {
        alleJahresangaben.first { $0.jahr == jahr } ?? Jahresangaben(jahr: jahr)
    }
    private var steuerjahr: Steuerjahr { Steuerjahr.fuer(jahr) }

    @AppStorage("glasstaerke") private var glasstärke = Stil.Glasstärke.mittel.rawValue

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

                rechnungsAbschnitt
                bankAbschnitt

                hinterlegteJahre
                darstellungAbschnitt
                zurücksetzenAbschnitt
            }
            .alsListe()
            .navigationTitle("Mehr")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { JahresWähler(jahr: $jahr) }
            }
            .onAppear(perform: stammdatenSicherstellen)
            .confirmationDialog(
                "Wirklich alles löschen?",
                isPresented: $löschenGefragt,
                titleVisibility: .visible
            ) {
                Button("Alles löschen", role: .destructive, action: allesLöschen)
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text(löschumfang)
            }
        }
    }

    private func stammdatenSicherstellen() {
        Datenbank.profilSicherstellen(in: kontext)
        Datenbank.jahresangabenSicherstellen(fuer: jahr, in: kontext)
    }

    // MARK: - Darstellung

    /// Wie stark das Glas tönt - dasselbe, was iOS 27 unter "Anzeige & Helligkeit >
    /// Liquid Glass" anbietet, nur für diese App.
    ///
    /// Klares Glas sieht über ruhigem Hintergrund am besten aus, wird über einem
    /// bunten Belegfoto aber schwer lesbar. Wer "Transparenz reduzieren" oder
    /// "Kontrast erhöhen" in den Bedienungshilfen gesetzt hat, bekommt ohnehin die
    /// deckende Darstellung - dieser Regler ist für alle dazwischen.
    private var darstellungAbschnitt: some View {
        Section {
            Picker("Glas", selection: $glasstärke) {
                ForEach(Stil.Glasstärke.allCases) { stärke in
                    Text(stärke.bezeichnung).tag(stärke.rawValue)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Darstellung")
        } footer: {
            Text("Klar zeigt am meisten vom Hintergrund, Getönt macht Text am besten lesbar. "
                 + "Bei eingeschaltetem „Transparenz reduzieren\" in den Bedienungshilfen "
                 + "sind die Flächen unabhängig davon deckend.")
        }
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

    // MARK: - Rechnungen

    /// Was auf jeder ausgehenden Rechnung steht.
    ///
    /// Name, Anschrift und Steuernummer sind Pflichtangaben (§ 14 Abs. 4 Nr. 1 und 2
    /// UStG). Ohne sie darf der Empfänger die Vorsteuer nicht ziehen - und die Rechnung
    /// kommt zurück.
    private var rechnungsAbschnitt: some View {
        Section {
            TextField("Dein Name oder deine Firma", text: profiltext(\.absenderName))
            TextField("Straße und Hausnummer", text: profiltext(\.absenderStrasse))
            TextField("PLZ", text: profiltext(\.absenderPlz)).keyboardType(.numbersAndPunctuation)
            TextField("Ort", text: profiltext(\.absenderOrt))
            TextField("Steuernummer", text: profiltext(\.steuernummer))
                .keyboardType(.numbersAndPunctuation)
            TextField("USt-IdNr. (falls vorhanden)", text: profiltext(\.ustIdNr))
                .textInputAutocapitalization(.characters)

            NavigationLink("Kunden") { KundenAnsicht() }
        } header: {
            Text("Rechnungen")
        } footer: {
            Text("Diese Angaben werden beim Stellen in jede Rechnung kopiert. Änderst du sie später, "
                 + "bleiben bereits gestellte Rechnungen so, wie der Kunde sie bekommen hat.")
        }
    }

    private var bankAbschnitt: some View {
        Section {
            TextField("Bank", text: profiltext(\.bankName))
            TextField("IBAN", text: profiltext(\.iban)).textInputAutocapitalization(.characters)
            TextField("BIC", text: profiltext(\.bic)).textInputAutocapitalization(.characters)
            Stepper("Zahlungsziel: \(profil.zahlungszielTage) Tage",
                    value: profilzahl(\.zahlungszielTage), in: 0...90, step: 7)
            TextField("Fußtext auf der Rechnung", text: profiltext(\.rechnungsfusstext), axis: .vertical)
                .lineLimit(2...5)
        } header: {
            Text("Zahlung")
        } footer: {
            Text("Der Fußtext steht unter den Positionen - etwa ein Dank, ein Hinweis auf Skonto oder "
                 + "der Bezug zum Auftrag.")
        }
    }

    // MARK: - Zurücksetzen

    /// Der einzige Weg, die App zu leeren, ohne sie zu löschen.
    ///
    /// Steht ganz unten und nirgendwo sonst: ein Knopf, der alles entfernt, gehört an
    /// das Ende einer Liste, an der man vorbeiscrollen muss - nicht neben etwas, das
    /// man täglich antippt.
    private var zurücksetzenAbschnitt: some View {
        Section {
            Button("Alle Daten löschen", role: .destructive) { löschenGefragt = true }
        } header: {
            Text("Zurücksetzen")
        } footer: {
            Text("Entfernt alle Belege samt Fotos, alle Anlagen, alle Jahresangaben "
                 + "und das Profil. Danach steht die App wie frisch installiert da.")
        }
    }

    /// Sagt im Bestätigungsdialog, was konkret verschwindet.
    ///
    /// "Alle Daten" ist keine Angabe - wer drei Probebelege gescannt hat und wer ein
    /// Jahr erfasst hat, sollen an derselben Stelle Unterschiedliches lesen.
    private var löschumfang: String {
        var teile: [String] = []
        if !alleBelege.isEmpty {
            teile.append(alleBelege.count == 1 ? "1 Beleg" : "\(alleBelege.count) Belege")
        }
        if !wirtschaftsgüter.isEmpty {
            teile.append(wirtschaftsgüter.count == 1
                         ? "1 Anlage" : "\(wirtschaftsgüter.count) Anlagen")
        }
        let jahre = Set(alleJahresangaben.map(\.jahr)).count
        if jahre > 0 {
            teile.append(jahre == 1 ? "die Angaben für 1 Jahr"
                                    : "die Angaben für \(jahre) Jahre")
        }

        guard !teile.isEmpty else {
            return "Es ist noch nichts erfasst - es geht nichts verloren."
        }
        return "Dabei verschwinden " + teile.formatted(.list(type: .and))
            + ". Das lässt sich nicht rückgängig machen."
    }

    private func allesLöschen() {
        Datenbank.allesLöschen(in: kontext)
        // Profil und Jahresangaben sofort wieder anlegen - ohne sie stünde die App
        // ohne Stammdaten da, und jede Ansicht müsste mit leeren Rückfällen rechnen.
        stammdatenSicherstellen()
    }

    // MARK: - Hilfsmittel

    /// Bindung an ein Textfeld des Profils.
    ///
    /// `profil` ist eine berechnete Eigenschaft über die Abfrage, kein `@Bindable` -
    /// deshalb gibt es kein `$profil`. Diese beiden Hilfen sparen pro Feld vier Zeilen
    /// `Binding(get:set:)`.
    private func profiltext(_ pfad: ReferenceWritableKeyPath<Steuerprofil, String>) -> Binding<String> {
        Binding(get: { profil[keyPath: pfad] }, set: { profil[keyPath: pfad] = $0 })
    }

    private func profilzahl(_ pfad: ReferenceWritableKeyPath<Steuerprofil, Int>) -> Binding<Int> {
        Binding(get: { profil[keyPath: pfad] }, set: { profil[keyPath: pfad] = $0 })
    }

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
