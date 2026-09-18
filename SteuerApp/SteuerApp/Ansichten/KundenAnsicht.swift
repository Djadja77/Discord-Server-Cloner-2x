import SwiftUI
import SwiftData

/// Die Rechnungsempfänger.
struct KundenAnsicht: View {

    @Environment(\.modelContext) private var kontext
    @Query(sort: \Kunde.name) private var kunden: [Kunde]

    @State private var inBearbeitung: Kunde?
    @State private var zuLöschen: Kunde?

    var body: some View {
        List {
            if kunden.isEmpty {
                Section {
                    Text("Noch kein Kunde erfasst. Wer eine Rechnung bekommt, wird hier einmal angelegt "
                         + "und steht danach zur Auswahl.")
                        .font(.system(size: 14))
                        .foregroundStyle(Stil.schriftGedämpft)
                }
            }

            ForEach(kunden) { kunde in
                Button {
                    inBearbeitung = kunde
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(kunde.name.isEmpty ? "Ohne Namen" : kunde.name)
                            .foregroundStyle(Stil.schrift)
                        Text(kunde.anschriftszeilen.dropFirst().joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(Stil.schriftGedämpft)
                        if !kunde.istVollständig {
                            Label("Anschrift unvollständig", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(Stil.warnung)
                        }
                    }
                }
                .swipeActions {
                    Button("Löschen", role: .destructive) { zuLöschen = kunde }
                }
            }
        }
        .alsListe()
        .navigationTitle("Kunden")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Neu", systemImage: "plus") { neuAnlegen() }
            }
        }
        .sheet(item: $inBearbeitung) { kunde in
            KundeBearbeitenAnsicht(kunde: kunde)
        }
        .confirmationDialog(
            "Kunde löschen?",
            isPresented: Binding(get: { zuLöschen != nil }, set: { if !$0 { zuLöschen = nil } }),
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) { löschenBestätigt() }
            Button("Abbrechen", role: .cancel) { zuLöschen = nil }
        } message: {
            Text("Bereits gestellte Rechnungen behalten die Anschrift, die beim Stellen galt - sie ändern "
                 + "sich dadurch nicht.")
        }
    }

    private func neuAnlegen() {
        let kunde = Kunde()
        kontext.insert(kunde)
        inBearbeitung = kunde
    }

    private func löschenBestätigt() {
        guard let kunde = zuLöschen else { return }
        kontext.delete(kunde)
        zuLöschen = nil
    }
}

/// Stammdaten eines Kunden.
struct KundeBearbeitenAnsicht: View {

    @Bindable var kunde: Kunde
    @Environment(\.dismiss) private var schließen

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Firma oder Name", text: $kunde.name)
                        .tastaturFertig()
                    TextField("Zusatz (z. Hd., Abteilung)", text: $kunde.zusatz)
                        .tastaturFertig()
                } header: {
                    Text("Empfänger")
                }

                Section {
                    TextField("Straße und Hausnummer", text: $kunde.strasse)
                        .tastaturFertig()
                    TextField("PLZ", text: $kunde.plz).keyboardType(.numbersAndPunctuation)
                        .tastaturFertig()
                    TextField("Ort", text: $kunde.ort)
                        .tastaturFertig()
                    TextField("Land (nur wenn nicht Deutschland)", text: $kunde.land)
                        .tastaturFertig()
                } header: {
                    Text("Anschrift")
                } footer: {
                    Text("Name und vollständige Anschrift des Empfängers sind Pflichtangaben "
                         + "(§ 14 Abs. 4 Nr. 1 UStG).")
                }

                Section {
                    TextField("USt-IdNr.", text: $kunde.ustIdNr)
                        .textInputAutocapitalization(.characters)
                        .tastaturFertig()
                    Stepper("Zahlungsziel: \(kunde.zahlungszielTage) Tage",
                            value: $kunde.zahlungszielTage, in: 0...90, step: 7)
                } header: {
                    Text("Abrechnung")
                }

                Section {
                    TextField("Leitweg-ID", text: $kunde.leitwegId)
                        .tastaturFertig()
                } header: {
                    Text("Öffentlicher Auftraggeber")
                } footer: {
                    Text("Nur für Behörden und Ämter. Ohne diese Kennung nehmen sie keine elektronische "
                         + "Rechnung an. Bei allen anderen Kunden bleibt das Feld leer.")
                }

                Section {
                    TextField("Notiz", text: $kunde.notiz, axis: .vertical).lineLimit(2...5)
                        .tastaturFertig()
                }
            }
            .alsListe()
            .navigationTitle(kunde.name.isEmpty ? "Neuer Kunde" : kunde.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schließen() }
                }
            }
        }
    }
}
