import SwiftUI
import SwiftData
import PhotosUI

/// Beleg erfassen oder bearbeiten.
///
/// Gearbeitet wird auf einem `Belegentwurf` statt direkt auf dem Datenbankobjekt: so lässt
/// sich ein neuer Beleg verwerfen, ohne dass halbfertige Daten in der Datenbank landen.
struct BelegBearbeitenAnsicht: View {

    /// `nil` legt einen neuen Beleg an.
    let beleg: Beleg?
    let vorgabeJahr: Int

    @Environment(\.modelContext) private var kontext
    @Environment(\.dismiss) private var schließen

    @State private var entwurf = Belegentwurf()
    @State private var geladen = false
    @State private var scannerOffen = false
    @State private var großansichtOffen = false
    @State private var erkennungLäuft = false
    @State private var neuesBild: UIImage?
    @State private var fotoauswahl: PhotosPickerItem?
    @State private var meldung: String?

    private var istNeu: Bool { beleg == nil }

    var body: some View {
        Group {
            if istNeu {
                NavigationStack { formular }
            } else {
                formular
            }
        }
        .onAppear(perform: entwurfLaden)
        .sheet(isPresented: $scannerOffen) {
            BelegScanner { bilder in
                scannerOffen = false
                // In der Einzelmaske zählt nur die erste Seite. Wer einen Stapel scannen
                // will, nimmt die Stapelerfassung - darauf weist die Belegliste hin.
                if let erstes = bilder.first { bildUebernehmen(erstes) }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $großansichtOffen) {
            if let bild = angezeigtesBild {
                BelegbildAnsicht(bild: bild)
            }
        }
        .onChange(of: fotoauswahl) {
            guard let fotoauswahl else { return }
            Task {
                let bilder = await FotoImport.bilderLaden(aus: [fotoauswahl])
                if let erstes = bilder.first { bildUebernehmen(erstes) }
                self.fotoauswahl = nil
            }
        }
        .alert("Hinweis", isPresented: Binding(
            get: { meldung != nil },
            set: { if !$0 { meldung = nil } }
        )) {
            Button("OK") { meldung = nil }
        } message: {
            Text(meldung ?? "")
        }
    }

    // MARK: - Formular

    private var formular: some View {
        Form {
            belegbildAbschnitt
            eckdatenAbschnitt
            steuerAbschnitt
            aufteilungAbschnitt
            notizAbschnitt
            if !istNeu { löschenAbschnitt }
        }
        .navigationTitle(istNeu ? "Neuer Beleg" : "Beleg")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if istNeu {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { verwerfen() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Sichern") { sichern() }
                    .disabled(!entwurf.istVollständig)
            }
        }
    }

    private var belegbildAbschnitt: some View {
        Section {
            if let bild = angezeigtesBild {
                Button {
                    großansichtOffen = true
                } label: {
                    Image(uiImage: bild)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .overlay(alignment: .topTrailing) {
                    Button {
                        bildEntfernen()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                    .padding(8)
                }
                .listRowInsets(EdgeInsets())
            }

            Button {
                scannerOffen = true
            } label: {
                Label(
                    angezeigtesBild == nil ? "Beleg fotografieren" : "Neu fotografieren",
                    systemImage: "doc.viewfinder"
                )
            }

            PhotosPicker(selection: $fotoauswahl, matching: .images) {
                Label("Aus Fotomediathek", systemImage: "photo.on.rectangle")
            }

            if erkennungLäuft {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Beleg wird ausgelesen ...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("Belege sind zehn Jahre aufzubewahren. Das Foto bleibt auf dem Gerät und wird mit dem Geräte-Backup gesichert.")
        }
    }

    private var eckdatenAbschnitt: some View {
        Section("Eckdaten") {
            TextField("Bezeichnung", text: $entwurf.bezeichnung)

            DatePicker("Datum", selection: $entwurf.datum, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "de_DE"))

            BetragsFeld(titel: "Bruttobetrag", betrag: $entwurf.bruttoBetrag)

            Picker("Kategorie", selection: $entwurf.kategorie) {
                Section("Einnahmen") {
                    ForEach(Belegkategorie.einnahmekategorien) { kategorie in
                        Label(kategorie.bezeichnung, systemImage: kategorie.symbol)
                            .tag(kategorie)
                    }
                }
                Section("Ausgaben") {
                    ForEach(Belegkategorie.ausgabekategorien) { kategorie in
                        Label(kategorie.bezeichnung, systemImage: kategorie.symbol)
                            .tag(kategorie)
                    }
                }
            }

            if let hinweis = entwurf.kategorie.hinweis {
                Label(hinweis, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var steuerAbschnitt: some View {
        Section {
            Picker("Umsatzsteuer", selection: $entwurf.umsatzsteuersatz) {
                ForEach(Umsatzsteuersatz.allCases) { satz in
                    Text(satz.bezeichnung).tag(satz)
                }
            }
            .pickerStyle(.segmented)

            ZeileMitBetrag(
                bezeichnung: "Netto",
                betrag: entwurf.umsatzsteuersatz.netto(ausBrutto: entwurf.bruttoBetrag)
            )
            ZeileMitBetrag(
                bezeichnung: entwurf.kategorie.art == .einnahme
                    ? "Enthaltene Umsatzsteuer" : "Abziehbare Vorsteuer",
                betrag: entwurf.umsatzsteuersatz.steueranteil(ausBrutto: entwurf.bruttoBetrag)
            )
        } header: {
            Text("Umsatzsteuer")
        } footer: {
            if entwurf.kategorie == .bewirtung {
                Text("Bei Bewirtung sind nur 70 % der Netto-Kosten Betriebsausgabe, die Vorsteuer bleibt zu 100 % abziehbar.")
            }
        }
    }

    private var aufteilungAbschnitt: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Betrieblicher Anteil")
                    Spacer()
                    Text(Formatierung.prozent(entwurf.betrieblicherAnteil, nachkommastellen: 0))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $entwurf.betrieblicherAnteil, in: 0...1, step: 0.05)
            }

            if entwurf.betrieblicherAnteil < 1 {
                ZeileMitBetrag(
                    bezeichnung: "Wirkt sich aus mit",
                    betrag: (entwurf.umsatzsteuersatz.netto(ausBrutto: entwurf.bruttoBetrag)
                             * Beleg.anteilsfaktor(aus: entwurf.betrieblicherAnteil)).gerundet(),
                    unterzeile: "netto, vor gesetzlichen Kürzungen"
                )
            }
        } header: {
            Text("Aufteilung")
        } footer: {
            Text("Bei gemischt genutzten Kosten wie Telefon oder Fahrzeug nur den betrieblichen Anteil ansetzen.")
        }
    }

    private var notizAbschnitt: some View {
        Section("Notiz") {
            TextField("Anlass, Teilnehmer, Projekt ...", text: $entwurf.notiz, axis: .vertical)
                .lineLimit(2...6)
        }
    }

    private var löschenAbschnitt: some View {
        Section {
            Button("Beleg löschen", role: .destructive) {
                if let beleg {
                    if let datei = beleg.belegbildDatei { Belegarchiv.löschen(datei) }
                    kontext.delete(beleg)
                }
                schließen()
            }
        }
    }

    // MARK: - Verhalten

    private var angezeigtesBild: UIImage? {
        if let neuesBild { return neuesBild }
        if let datei = entwurf.belegbildDatei { return Belegarchiv.laden(datei) }
        return nil
    }

    private func entwurfLaden() {
        guard !geladen else { return }
        geladen = true

        if let beleg {
            entwurf = Belegentwurf(beleg: beleg)
        } else {
            entwurf.datum = Belegentwurf.vorgabedatum(fuerJahr: vorgabeJahr)
        }
    }

    private func bildUebernehmen(_ bild: UIImage) {
        neuesBild = bild
        erkennungLäuft = true

        Task {
            let vorschlag = await BelegTexterkennung.auswerten(bild: bild)
            entwurf.übernehmen(vorschlag, steuerjahr: vorgabeJahr)
            erkennungLäuft = false
        }
    }

    private func bildEntfernen() {
        neuesBild = nil
        if let datei = entwurf.belegbildDatei {
            Belegarchiv.löschen(datei)
            entwurf.belegbildDatei = nil
        }
    }

    private func sichern() {
        if let neuesBild {
            do {
                // Das alte Foto erst entfernen, wenn das neue sicher geschrieben ist.
                let neuerName = try Belegarchiv.speichern(neuesBild)
                if let alt = entwurf.belegbildDatei { Belegarchiv.löschen(alt) }
                entwurf.belegbildDatei = neuerName
            } catch {
                meldung = error.localizedDescription
                return
            }
        }

        let ziel = beleg ?? Beleg()
        entwurf.anwenden(auf: ziel)
        if beleg == nil { kontext.insert(ziel) }
        neuesBild = nil
        schließen()
    }

    private func verwerfen() {
        neuesBild = nil
        schließen()
    }
}

#Preview {
    BelegBearbeitenAnsicht(
        beleg: nil,
        vorgabeJahr: Calendar.kalender.component(.year, from: Date())
    )
    .modelContainer(Datenbank.vorschauContainer())
}
