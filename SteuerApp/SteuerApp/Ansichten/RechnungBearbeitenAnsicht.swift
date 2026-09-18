import SwiftUI
import SwiftData

/// Der Entwurf einer Rechnung.
///
/// Nur Entwürfe landen hier. Eine gestellte Rechnung lässt sich nicht mehr bearbeiten -
/// sie liegt beim Kunden, und was dort liegt, ändert man nicht nachträglich. Korrigiert
/// wird über einen Storno.
///
/// Der Empfänger steht in Einzelfeldern, auch wenn er aus der Kundenliste kommt. Ein
/// Kunde füllt sie nur aus; danach gehören sie dieser Rechnung. So lässt sich für einen
/// einzelnen Auftrag eine abweichende Anschrift eintragen, ohne den Kunden anzufassen -
/// und ein Kunde, der umzieht, ändert keine alte Rechnung.
struct RechnungBearbeitenAnsicht: View {

    @Bindable var rechnung: Rechnung

    @Environment(\.modelContext) private var kontext
    @Environment(\.dismiss) private var schließen
    @Query(sort: \Kunde.name) private var kunden: [Kunde]
    @Query(sort: \Ordner.reihenfolge) private var ordner: [Ordner]
    @Query private var profile: [Steuerprofil]
    @Query private var alleRechnungen: [Rechnung]

    @State private var mitZeitraum = false

    private var profil: Steuerprofil { profile.first ?? Steuerprofil() }
    private var jahr: Int { Calendar.kalender.component(.year, from: rechnung.datum) }

    var body: some View {
        NavigationStack {
            Form {
                nummerAbschnitt
                empfaengerAbschnitt
                positionenAbschnitt
                summenAbschnitt
                zeitraumAbschnitt
                zahlungAbschnitt
                ablageAbschnitt
                hindernisAbschnitt
            }
            .alsListe()
            .navigationTitle(rechnung.nummerVonHand && !rechnung.nummer.isEmpty
                             ? "Rechnung \(rechnung.nummer)" : "Neue Rechnung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sichern") { schließen() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Stellen") { stellen() }
                        .disabled(!stellbar)
                }
            }
            .onAppear {
                mitZeitraum = rechnung.leistungBis != nil
                if rechnung.leistungVon == nil { rechnung.leistungVon = rechnung.datum }
            }
        }
    }

    // MARK: - Nummer

    private var nummerAbschnitt: some View {
        Section {
            Toggle("Nummer selbst vergeben", isOn: $rechnung.nummerVonHand)
                .onChange(of: rechnung.nummerVonHand) { _, vonHand in
                    if !vonHand { rechnung.nummer = "" }
                }

            if rechnung.nummerVonHand {
                TextField("z. B. 2026-0042 oder RE-1043", text: $rechnung.nummer)
                    .autocorrectionDisabled()
                if nummerDoppelt {
                    Label("Diese Nummer gibt es schon", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 13))
                        .foregroundStyle(Stil.gefahr)
                }
            } else {
                HStack {
                    Text("Nummer")
                    Spacer()
                    Text(Rechnungsnummer.vorschau(fuer: jahr, in: profil.nummernkreis))
                        .foregroundStyle(Stil.schriftGedämpft)
                        .monospacedDigit()
                }
            }

            DatePicker("Rechnungsdatum", selection: $rechnung.datum, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "de_DE"))
        } header: {
            Text("Rechnung")
        } footer: {
            Text(rechnung.nummerVonHand
                 ? "Der Zähler der App bleibt dabei stehen. Achte selbst darauf, dass keine Nummer "
                   + "zweimal vorkommt - sie muss fortlaufend und einmalig sein (§ 14 Abs. 4 Nr. 4 UStG)."
                 : "Wird erst beim Stellen vergeben. Ein verworfener Entwurf reißt so keine Lücke "
                   + "in den Nummernkreis.")
        }
    }

    private var nummerDoppelt: Bool {
        let nummer = rechnung.nummer.trimmingCharacters(in: .whitespaces)
        guard !nummer.isEmpty else { return false }
        return alleRechnungen.contains {
            $0.persistentModelID != rechnung.persistentModelID
                && $0.nummer.trimmingCharacters(in: .whitespaces) == nummer
        }
    }

    // MARK: - Empfänger

    private var empfaengerAbschnitt: some View {
        Section {
            Menu {
                ForEach(kunden) { kunde in
                    Button(kunde.name.isEmpty ? "Ohne Namen" : kunde.name) { übernehmen(kunde) }
                }
                if kunden.isEmpty { Text("Noch kein Kunde gespeichert") }
            } label: {
                HStack {
                    Label("Aus Kundenliste übernehmen", systemImage: "person.crop.circle")
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Stil.schriftLeise)
                }
            }

            TextField("Firma oder Name", text: $rechnung.empfaengerName)
            TextField("Zusatz (z. Hd., Abteilung)", text: $rechnung.empfaengerZusatz)
            TextField("Straße und Hausnummer", text: $rechnung.empfaengerStrasse)
            HStack(spacing: 12) {
                TextField("PLZ", text: $rechnung.empfaengerPlz)
                    .keyboardType(.numbersAndPunctuation)
                    .frame(maxWidth: 88)
                TextField("Ort", text: $rechnung.empfaengerOrt)
            }
            TextField("Land (nur wenn nicht Deutschland)", text: $rechnung.empfaengerLand)
            TextField("USt-IdNr. des Kunden", text: $rechnung.empfaengerUstIdNr)
                .textInputAutocapitalization(.characters)

            if rechnung.kunde == nil && rechnung.empfaengerVollständig {
                Button("Als Kunden speichern", systemImage: "square.and.arrow.down") {
                    alsKundenSpeichern()
                }
            }
        } header: {
            Text("Empfänger")
        } footer: {
            Text("Name und vollständige Anschrift sind Pflichtangaben (§ 14 Abs. 4 Nr. 1 UStG). "
                 + "Änderungen hier gelten nur für diese Rechnung und ändern den gespeicherten "
                 + "Kunden nicht.")
        }
    }

    // MARK: - Positionen

    private var positionenAbschnitt: some View {
        Section {
            ForEach(rechnung.postenGeordnet) { posten in
                PostenZeile(posten: posten, mitUmsatzsteuer: !profil.kleinunternehmer)
            }
            .onDelete(perform: postenLöschen)

            Button("Position hinzufügen", systemImage: "plus") { postenAnlegen() }
        } header: {
            Text("Positionen")
        } footer: {
            Text("Menge und Art der Leistung gehören auf jede Rechnung (§ 14 Abs. 4 Nr. 5 UStG). "
                 + "Preise sind netto.")
        }
    }

    private var summenAbschnitt: some View {
        Section {
            if profil.kleinunternehmer {
                zeile("Gesamtbetrag", Formatierung.euro(rechnung.netto), fett: true)
                Text("Als Kleinunternehmer nach § 19 UStG weist du keine Umsatzsteuer aus. "
                     + "Der Hinweis kommt automatisch auf die Rechnung.")
                    .font(.caption)
                    .foregroundStyle(Stil.schriftGedämpft)
            } else {
                zeile("Netto", Formatierung.euro(rechnung.netto))
                ForEach(Array(rechnung.umsatzsteuerJeSatz.enumerated()), id: \.offset) { _, satz in
                    zeile("Umsatzsteuer \(satz.satz.bezeichnung)", Formatierung.euro(satz.steuer))
                }
                zeile("Gesamtbetrag", Formatierung.euro(rechnung.brutto), fett: true)
            }
        }
    }

    // MARK: - Zeitraum und Zahlung

    private var zeitraumAbschnitt: some View {
        Section {
            Toggle("Zeitraum statt einzelnem Tag", isOn: $mitZeitraum)
                .onChange(of: mitZeitraum) { _, an in
                    rechnung.leistungBis = an ? (rechnung.leistungBis ?? rechnung.datum) : nil
                }
            DatePicker(mitZeitraum ? "Leistung von" : "Leistungsdatum",
                       selection: leistungVonBindung, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "de_DE"))
            if mitZeitraum {
                DatePicker("Leistung bis", selection: leistungBisBindung, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "de_DE"))
            }
        } header: {
            Text("Leistungszeitpunkt")
        } footer: {
            Text("Wann geleistet wurde, ist eine Pflichtangabe (§ 14 Abs. 4 Nr. 6 UStG) - auch dann, "
                 + "wenn es derselbe Monat wie das Rechnungsdatum ist.")
        }
    }

    private var zahlungAbschnitt: some View {
        Section {
            Toggle("Zahlungsziel angeben", isOn: $rechnung.zahlungszielZeigen)

            if rechnung.zahlungszielZeigen {
                DatePicker("Zahlbar bis", selection: $rechnung.zahlbarBis, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "de_DE"))
                TextField("Eigener Wortlaut (leer = Standardsatz)",
                          text: $rechnung.zahlungshinweis, axis: .vertical)
                    .lineLimit(1...4)
            }
        } header: {
            Text("Zahlung")
        } footer: {
            Text(rechnung.zahlungszielZeigen
                 ? "Ohne eigenen Wortlaut steht auf der Rechnung: Zahlbar ohne Abzug bis zum "
                   + "\(Formatierung.datum(rechnung.zahlbarBis)). Wer Skonto gewährt oder per "
                   + "Lastschrift einzieht, schreibt hier hin, was tatsächlich gilt."
                 : "Auf der Rechnung steht dann gar nichts zur Zahlungsfrist - richtig bei Vorkasse, "
                   + "Lastschrift oder einer bereits bezahlten Leistung.")
        }
    }

    private var ablageAbschnitt: some View {
        Section {
            Picker("Ordner", selection: ordnerbindung) {
                Text("Keiner").tag(nil as Ordner?)
                ForEach(ordner) { mappe in
                    Text(mappe.name.isEmpty ? "Ohne Namen" : mappe.name).tag(mappe as Ordner?)
                }
            }
            TextField("Fußtext auf der Rechnung", text: $rechnung.fusstext, axis: .vertical)
                .lineLimit(2...5)
            TextField("Interne Notiz (nicht auf der Rechnung)", text: $rechnung.notiz, axis: .vertical)
                .lineLimit(1...4)
        } header: {
            Text("Ablage")
        }
    }

    @ViewBuilder
    private var hindernisAbschnitt: some View {
        let offen = rechnung.hindernisse
            + profil.rechnungsHindernisse.map { "Im Profil fehlt: \($0)" }
            + (nummerDoppelt ? ["Die Rechnungsnummer gibt es schon"] : [])
        if !offen.isEmpty {
            Section {
                ForEach(offen, id: \.self) { hindernis in
                    Label(hindernis, systemImage: "exclamationmark.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(Stil.warnung)
                }
            } header: {
                Text("Noch offen")
            } footer: {
                Text("Solange etwas davon fehlt, bleibt die Rechnung ein Entwurf.")
            }
        }
    }

    private var stellbar: Bool {
        rechnung.hindernisse.isEmpty && profil.rechnungsHindernisse.isEmpty && !nummerDoppelt
    }

    // MARK: - Bausteine

    private func zeile(_ bezeichnung: String, _ wert: String, fett: Bool = false) -> some View {
        HStack {
            Text(bezeichnung).fontWeight(fett ? .semibold : .regular)
            Spacer()
            Text(wert).fontWeight(fett ? .semibold : .regular).monospacedDigit()
        }
    }

    // MARK: - Bindungen

    private var ordnerbindung: Binding<Ordner?> {
        Binding(get: { rechnung.ordner }, set: { rechnung.ordner = $0 })
    }

    private var leistungVonBindung: Binding<Date> {
        Binding(get: { rechnung.leistungVon ?? rechnung.datum }, set: { rechnung.leistungVon = $0 })
    }

    private var leistungBisBindung: Binding<Date> {
        Binding(get: { rechnung.leistungBis ?? rechnung.datum }, set: { rechnung.leistungBis = $0 })
    }

    // MARK: - Vorgänge

    /// Füllt die Felder aus einem gespeicherten Kunden.
    private func übernehmen(_ kunde: Kunde) {
        rechnung.kunde = kunde
        rechnung.empfaengerName = kunde.name
        rechnung.empfaengerZusatz = kunde.zusatz
        rechnung.empfaengerStrasse = kunde.strasse
        rechnung.empfaengerPlz = kunde.plz
        rechnung.empfaengerOrt = kunde.ort
        rechnung.empfaengerLand = kunde.land
        rechnung.empfaengerUstIdNr = kunde.ustIdNr
        rechnung.empfaengerLeitwegId = kunde.leitwegId

        if let ziel = Calendar.kalender.date(
            byAdding: .day, value: kunde.zahlungszielTage, to: rechnung.datum) {
            rechnung.zahlbarBis = ziel
        }
    }

    /// Legt aus den getippten Feldern einen Kunden an - damit man ihn beim nächsten Mal
    /// nur noch auswählt.
    private func alsKundenSpeichern() {
        let kunde = Kunde(
            name: rechnung.empfaengerName,
            zusatz: rechnung.empfaengerZusatz,
            strasse: rechnung.empfaengerStrasse,
            plz: rechnung.empfaengerPlz,
            ort: rechnung.empfaengerOrt,
            land: rechnung.empfaengerLand,
            ustIdNr: rechnung.empfaengerUstIdNr,
            leitwegId: rechnung.empfaengerLeitwegId
        )
        kontext.insert(kunde)
        rechnung.kunde = kunde
    }

    private func postenAnlegen() {
        let posten = Rechnungsposten(
            reihenfolge: (rechnung.postenGeordnet.last?.reihenfolge ?? -1) + 1,
            umsatzsteuersatz: profil.kleinunternehmer ? .ohne : .regel
        )
        posten.rechnung = rechnung
        kontext.insert(posten)
    }

    private func postenLöschen(_ stellen: IndexSet) {
        let geordnet = rechnung.postenGeordnet
        for stelle in stellen where geordnet.indices.contains(stelle) {
            kontext.delete(geordnet[stelle])
        }
    }

    private func stellen() {
        if Rechnungsstellung.stellen(rechnung, profil: profil, in: kontext) { schließen() }
    }
}

/// Eine Position im Entwurf.
private struct PostenZeile: View {

    @Bindable var posten: Rechnungsposten
    let mitUmsatzsteuer: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Was wurde geleistet?", text: $posten.bezeichnung, axis: .vertical)
                .lineLimit(1...3)

            HStack(spacing: 10) {
                MengenFeld(titel: "Menge", wert: $posten.menge)
                TextField("Einheit", text: $posten.einheit)
                    .frame(maxWidth: 74)
                    .multilineTextAlignment(.center)
            }

            BetragsFeld(titel: "Einzelpreis netto", betrag: $posten.einzelpreis, sofortÜbernehmen: true)

            if mitUmsatzsteuer {
                Picker("Umsatzsteuer", selection: satzbindung) {
                    ForEach(Umsatzsteuersatz.allCases) { satz in
                        Text(satz.bezeichnung).tag(satz)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack {
                Spacer()
                Text(Formatierung.euro(posten.netto))
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }

    private var satzbindung: Binding<Umsatzsteuersatz> {
        Binding(get: { posten.umsatzsteuersatz }, set: { posten.umsatzsteuersatz = $0 })
    }
}

/// Zahlenfeld für Mengen - wie `BetragsFeld`, nur ohne Währung.
private struct MengenFeld: View {

    let titel: String
    @Binding var wert: Decimal

    @FocusState private var fokussiert: Bool
    @State private var text = ""

    var body: some View {
        TextField(titel, text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 88)
            .focused($fokussiert)
            .onAppear { text = Formatierung.menge(wert) }
            .onChange(of: text) { if fokussiert { wert = Formatierung.betragAusEingabe(text) } }
            .onChange(of: fokussiert) { _, amZug in
                if !amZug { text = Formatierung.menge(wert) }
            }
    }
}
