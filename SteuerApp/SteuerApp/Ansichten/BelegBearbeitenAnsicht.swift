import SwiftUI
import SwiftData

/// Beleg erfassen oder bearbeiten.
///
/// Gearbeitet wird auf einem Entwurf statt direkt auf dem Datenbankobjekt: so laesst sich
/// ein neuer Beleg verwerfen, ohne dass halbfertige Daten in der Datenbank landen.
struct BelegBearbeitenAnsicht: View {

    /// `nil` legt einen neuen Beleg an.
    let beleg: Beleg?
    let vorgabeJahr: Int

    @Environment(\.modelContext) private var kontext
    @Environment(\.dismiss) private var schliessen

    @State private var entwurf = Entwurf()
    @State private var geladen = false
    @State private var scannerOffen = false
    @State private var erkennungLaeuft = false
    @State private var neuesBild: UIImage?
    @State private var meldung: String?

    private var istNeu: Bool { beleg == nil }

    struct Entwurf {
        var datum = Date()
        var bezeichnung = ""
        var bruttoBetrag: Decimal = 0
        var kategorie: Belegkategorie = .sonstigeAusgaben
        var umsatzsteuersatz: Umsatzsteuersatz = .regel
        var betrieblicherAnteil: Double = 1.0
        var notiz = ""
        var belegbildDatei: String?
    }

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
            BelegScanner { bild in
                scannerOffen = false
                if let bild { bildUebernehmen(bild) }
            }
            .ignoresSafeArea()
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
            if !istNeu { loeschenAbschnitt }
        }
        .navigationTitle(istNeu ? "Neuer Beleg" : "Beleg")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if istNeu {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { verwerfen() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { sichern() }
                        .disabled(entwurf.bruttoBetrag <= 0)
                }
            } else {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { sichern() }
                        .disabled(entwurf.bruttoBetrag <= 0)
                }
            }
        }
    }

    private var belegbildAbschnitt: some View {
        Section {
            if let bild = angezeigtesBild {
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
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

            if erkennungLaeuft {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Beleg wird ausgelesen ...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("Belege sind zehn Jahre aufzubewahren. Das Foto bleibt auf dem Geraet und wird mit dem Geraete-Backup gesichert.")
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
                    unterzeile: "netto, vor gesetzlichen Kuerzungen"
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

    private var loeschenAbschnitt: some View {
        Section {
            Button("Beleg loeschen", role: .destructive) {
                if let beleg {
                    if let datei = beleg.belegbildDatei { Belegarchiv.loeschen(datei) }
                    kontext.delete(beleg)
                }
                schliessen()
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
            entwurf = Entwurf(
                datum: beleg.datum,
                bezeichnung: beleg.bezeichnung,
                bruttoBetrag: beleg.bruttoBetrag,
                kategorie: beleg.kategorie,
                umsatzsteuersatz: beleg.umsatzsteuersatz,
                betrieblicherAnteil: beleg.betrieblicherAnteil,
                notiz: beleg.notiz,
                belegbildDatei: beleg.belegbildDatei
            )
        } else {
            // Neue Belege bekommen ein Datum im gerade betrachteten Jahr - sonst legt man
            // im Februar versehentlich Belege im laufenden statt im bearbeiteten Jahr an.
            let heute = Date()
            let aktuellesJahr = Calendar.kalender.component(.year, from: heute)
            entwurf.datum = vorgabeJahr == aktuellesJahr
                ? heute
                : Calendar.kalender.date(from: DateComponents(
                    year: vorgabeJahr, month: 12, day: 31, hour: 12)) ?? heute
        }
    }

    private func bildUebernehmen(_ bild: UIImage) {
        neuesBild = bild
        erkennungLaeuft = true

        Task {
            let vorschlag = await BelegTexterkennung.auswerten(bild: bild)
            await MainActor.run {
                // Erkannte Werte nur dort einsetzen, wo noch nichts eingegeben wurde -
                // eine Korrektur von Hand darf die Texterkennung nicht ueberschreiben.
                if entwurf.bruttoBetrag == 0, let betrag = vorschlag.bruttoBetrag {
                    entwurf.bruttoBetrag = betrag
                }
                if let datum = vorschlag.datum,
                   Calendar.kalender.component(.year, from: datum) == vorgabeJahr {
                    entwurf.datum = datum
                }
                erkennungLaeuft = false
            }
        }
    }

    private func bildEntfernen() {
        neuesBild = nil
        if let datei = entwurf.belegbildDatei {
            Belegarchiv.loeschen(datei)
            entwurf.belegbildDatei = nil
        }
    }

    private func sichern() {
        var dateiname = entwurf.belegbildDatei
        if let neuesBild {
            do {
                // Das alte Foto erst entfernen, wenn das neue sicher geschrieben ist.
                let neuerName = try Belegarchiv.speichern(neuesBild)
                if let alt = dateiname { Belegarchiv.loeschen(alt) }
                dateiname = neuerName
            } catch {
                meldung = error.localizedDescription
                return
            }
        }

        let ziel = beleg ?? Beleg()
        ziel.datum = entwurf.datum
        ziel.bezeichnung = entwurf.bezeichnung
        ziel.bruttoBetrag = entwurf.bruttoBetrag
        ziel.kategorie = entwurf.kategorie
        ziel.umsatzsteuersatz = entwurf.umsatzsteuersatz
        ziel.betrieblicherAnteil = entwurf.betrieblicherAnteil
        ziel.notiz = entwurf.notiz
        ziel.belegbildDatei = dateiname

        if beleg == nil { kontext.insert(ziel) }
        neuesBild = nil
        schliessen()
    }

    private func verwerfen() {
        neuesBild = nil
        schliessen()
    }
}

#Preview {
    BelegBearbeitenAnsicht(
        beleg: nil,
        vorgabeJahr: Calendar.kalender.component(.year, from: Date())
    )
    .modelContainer(Datenbank.vorschauContainer())
}
