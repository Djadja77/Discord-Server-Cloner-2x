import SwiftUI
import SwiftData

/// Der Entwurf einer Rechnung.
///
/// Nur Entwürfe landen hier. Eine gestellte Rechnung lässt sich nicht mehr bearbeiten -
/// sie liegt beim Kunden, und was dort liegt, ändert man nicht nachträglich. Korrigiert
/// wird über einen Storno.
struct RechnungBearbeitenAnsicht: View {

    @Bindable var rechnung: Rechnung

    @Environment(\.modelContext) private var kontext
    @Environment(\.dismiss) private var schließen
    @Query(sort: \Kunde.name) private var kunden: [Kunde]
    @Query(sort: \Ordner.reihenfolge) private var ordner: [Ordner]
    @Query private var profile: [Steuerprofil]

    @State private var mitZeitraum = false
    @State private var kundeAnlegen = false
    @State private var vonHand = false

    private var profil: Steuerprofil { profile.first ?? Steuerprofil() }

    var body: some View {
        NavigationStack {
            Form {
                empfaengerAbschnitt
                positionenAbschnitt
                summenAbschnitt
                zeitraumAbschnitt
                ablageAbschnitt
                hindernisAbschnitt
            }
            .alsListe()
            .navigationTitle("Rechnung \(Rechnungsnummer.vorschau(fuer: jahr, in: profil.nummernkreis))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sichern") { schließen() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Stellen") { stellen() }
                        .disabled(!rechnung.hindernisse.isEmpty || !profil.rechnungsHindernisse.isEmpty)
                }
            }
            .onAppear {
                vonHand = rechnung.kunde == nil && !rechnung.empfaengerName.isEmpty
                mitZeitraum = rechnung.leistungBis != nil
                if rechnung.leistungVon == nil { rechnung.leistungVon = rechnung.datum }
            }
            .sheet(isPresented: $kundeAnlegen) {
                if let neuer = rechnung.kunde { KundeBearbeitenAnsicht(kunde: neuer) }
            }
        }
    }

    private var jahr: Int { Calendar.kalender.component(.year, from: rechnung.datum) }

    // MARK: - Abschnitte

    private var empfaengerAbschnitt: some View {
        Section {
            Picker("Woher", selection: $vonHand) {
                Text("Aus der Kundenliste").tag(false)
                Text("Von Hand").tag(true)
            }
            .pickerStyle(.segmented)

            if vonHand {
                TextField("Firma oder Name", text: $rechnung.empfaengerName)
                TextField("Anschrift (mehrzeilig)", text: $rechnung.empfaengerAnschrift, axis: .vertical)
                    .lineLimit(2...4)
                TextField("USt-IdNr. (falls vorhanden)", text: $rechnung.empfaengerUstIdNr)
                    .textInputAutocapitalization(.characters)
            } else {
                Picker("Kunde", selection: kundenbindung) {
                    Text("Bitte wählen").tag(nil as Kunde?)
                    ForEach(kunden) { kunde in
                        Text(kunde.name.isEmpty ? "Ohne Namen" : kunde.name).tag(kunde as Kunde?)
                    }
                }
                Button("Neuen Kunden anlegen", systemImage: "person.badge.plus") {
                    let kunde = Kunde()
                    kontext.insert(kunde)
                    rechnung.kunde = kunde
                    kundeAnlegen = true
                }
            }

            DatePicker("Rechnungsdatum", selection: $rechnung.datum, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "de_DE"))
            DatePicker("Zahlbar bis", selection: $rechnung.zahlbarBis, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "de_DE"))
        } header: {
            Text("Empfänger")
        } footer: {
            Text(vonHand
                 ? "Für den einmaligen Auftrag. Diese Anschrift steht nur auf dieser Rechnung und "
                   + "landet nicht in der Kundenliste."
                 : "Einmal angelegte Kunden stehen hier zur Auswahl - mit Anschrift, USt-IdNr. und "
                   + "Zahlungsziel.")
        }
        .onChange(of: vonHand) { _, jetztVonHand in
            // Beim Umschalten die andere Quelle loslassen, sonst gewinnt beim Stellen
            // die Abschrift aus dem Kunden und überschreibt das Getippte.
            if jetztVonHand { rechnung.kunde = nil }
            else { rechnung.empfaengerName = ""; rechnung.empfaengerAnschrift = "" }
        }
    }

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
        let offen = rechnung.hindernisse + profil.rechnungsHindernisse.map { "Im Profil fehlt: \($0)" }
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

    // MARK: - Bausteine

    private func zeile(_ bezeichnung: String, _ wert: String, fett: Bool = false) -> some View {
        HStack {
            Text(bezeichnung).fontWeight(fett ? .semibold : .regular)
            Spacer()
            Text(wert).fontWeight(fett ? .semibold : .regular).monospacedDigit()
        }
    }

    // MARK: - Bindungen

    private var kundenbindung: Binding<Kunde?> {
        Binding(get: { rechnung.kunde }, set: { neu in
            rechnung.kunde = neu
            if let neu, let ziel = Calendar.kalender.date(
                byAdding: .day, value: neu.zahlungszielTage, to: rechnung.datum) {
                rechnung.zahlbarBis = ziel
            }
        })
    }

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
