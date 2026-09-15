import SwiftUI
import SwiftData

/// Das Anlagenverzeichnis: alles, was über mehrere Jahre abgeschrieben wird.
///
/// Anschaffungen oberhalb der Grenze für geringwertige Wirtschaftsgüter gehören hierher
/// und nicht in die Belegliste - sonst würde der volle Betrag im Anschaffungsjahr als
/// Betriebsausgabe erscheinen, was das Finanzamt nicht anerkennt.
struct AnlagenAnsicht: View {

    let jahr: Int

    @Environment(\.modelContext) private var kontext
    @Query(sort: \Wirtschaftsgut.anschaffungsdatum, order: .reverse)
    private var wirtschaftsgüter: [Wirtschaftsgut]

    @State private var neuesGut = false

    private var abschreibungDesJahres: Decimal {
        wirtschaftsgüter.map { $0.abschreibung(fuerJahr: jahr) }.summe
    }

    var body: some View {
        List {
            if wirtschaftsgüter.isEmpty {
                ContentUnavailableView(
                    "Kein Anlagevermögen",
                    systemImage: "shippingbox",
                    description: Text("Anschaffungen über 800 Euro netto werden hier erfasst und über ihre Nutzungsdauer abgeschrieben.")
                )
            } else {
                Section {
                    ZeileMitBetrag(
                        bezeichnung: "Abschreibung \(String(jahr))",
                        betrag: abschreibungDesJahres,
                        unterzeile: "fließt als Betriebsausgabe in die EÜR ein",
                        hervorgehoben: true
                    )
                }

                Section("Wirtschaftsgüter") {
                    ForEach(wirtschaftsgüter) { gut in
                        NavigationLink {
                            WirtschaftsgutBearbeitenAnsicht(wirtschaftsgut: gut)
                        } label: {
                            zeile(fuer: gut)
                        }
                    }
                    .onDelete(perform: löschen)
                }
            }
        }
        .alsListe()
        .navigationTitle("Anlagevermögen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    neuesGut = true
                } label: {
                    Label("Wirtschaftsgut erfassen", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $neuesGut) {
            WirtschaftsgutBearbeitenAnsicht(wirtschaftsgut: nil)
        }
    }

    private func zeile(fuer gut: Wirtschaftsgut) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(gut.bezeichnung.isEmpty ? "Ohne Bezeichnung" : gut.bezeichnung)
                Spacer()
                Text(Formatierung.euro(gut.abschreibung(fuerJahr: jahr)))
                    .monospacedDigit()
            }
            Text(untertitel(fuer: gut))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func untertitel(fuer gut: Wirtschaftsgut) -> String {
        let angeschafft = Formatierung.datum(gut.anschaffungsdatum)
        let kosten = Formatierung.euro(gut.anschaffungskostenNetto, mitCent: false)
        let rest = Formatierung.euro(gut.restbuchwert(endeJahr: jahr), mitCent: false)
        return "\(angeschafft) \u{2013} \(kosten) über \(gut.nutzungsdauerJahre) Jahre \u{2013} Restwert \(rest)"
    }

    private func löschen(_ indizes: IndexSet) {
        indizes.map { wirtschaftsgüter[$0] }.forEach(kontext.delete)
    }
}

/// Wirtschaftsgut anlegen oder bearbeiten.
struct WirtschaftsgutBearbeitenAnsicht: View {

    let wirtschaftsgut: Wirtschaftsgut?

    @Environment(\.modelContext) private var kontext
    @Environment(\.dismiss) private var schließen

    @State private var bezeichnung = ""
    @State private var anschaffungsdatum = Date()
    @State private var kosten: Decimal = 0
    @State private var nutzungsdauer = 3
    @State private var notiz = ""
    @State private var geladen = false

    private var istNeu: Bool { wirtschaftsgut == nil }

    /// Vorschau der Abschreibung über die gesamte Nutzungsdauer - macht sofort sichtbar,
    /// wie lange die Anschaffung steuerlich nachwirkt.
    private var vorschau: [(jahr: Int, betrag: Decimal)] {
        let entwurf = Wirtschaftsgut(
            anschaffungsdatum: anschaffungsdatum,
            anschaffungskostenNetto: kosten,
            nutzungsdauerJahre: nutzungsdauer
        )
        guard kosten > 0, nutzungsdauer > 0 else { return [] }
        return (entwurf.anschaffungsjahr...entwurf.letztesAbschreibungsjahr)
            .map { (jahr: $0, betrag: entwurf.abschreibung(fuerJahr: $0)) }
            .filter { $0.betrag > 0 }
    }

    var body: some View {
        Group {
            if istNeu {
                NavigationStack { formular }
            } else {
                formular
            }
        }
        .onAppear(perform: laden)
    }

    private var formular: some View {
        Form {
            Section("Wirtschaftsgut") {
                TextField("Bezeichnung", text: $bezeichnung)
                DatePicker("Angeschafft am", selection: $anschaffungsdatum,
                           displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "de_DE"))
                BetragsFeld(titel: "Anschaffungskosten", betrag: $kosten,
                            hinweis: "netto, ohne Umsatzsteuer")
            }

            Section {
                Stepper("Nutzungsdauer: \(nutzungsdauer) Jahre",
                        value: $nutzungsdauer, in: 1...50)

                Picker("Vorlage", selection: Binding(
                    get: { Nutzungsdauervorlage.allCases.first { $0.jahre == nutzungsdauer } },
                    set: { if let vorlage = $0 { nutzungsdauer = vorlage.jahre } }
                )) {
                    Text("Eigene Angabe").tag(Nutzungsdauervorlage?.none)
                    ForEach(Nutzungsdauervorlage.allCases) { vorlage in
                        Text("\(vorlage.bezeichnung) \u{2013} \(vorlage.jahre) Jahre")
                            .tag(Nutzungsdauervorlage?.some(vorlage))
                    }
                }
            } header: {
                Text("Abschreibungsdauer")
            } footer: {
                Text("Maßgeblich ist die betriebsgewöhnliche Nutzungsdauer nach der amtlichen AfA-Tabelle. Im Anschaffungsjahr wird nur zeitanteilig ab dem Anschaffungsmonat abgeschrieben.")
            }

            if !vorschau.isEmpty {
                Section("Abschreibung je Jahr") {
                    ForEach(vorschau, id: \.jahr) { eintrag in
                        ZeileMitBetrag(bezeichnung: String(eintrag.jahr), betrag: eintrag.betrag)
                    }
                }
            }

            Section("Notiz") {
                TextField("Rechnungsnummer, Standort ...", text: $notiz, axis: .vertical)
                    .lineLimit(2...5)
            }

            if !istNeu {
                Section {
                    Button("Wirtschaftsgut löschen", role: .destructive) {
                        if let wirtschaftsgut { kontext.delete(wirtschaftsgut) }
                        schließen()
                    }
                }
            }
        }
        .alsListe()
        .navigationTitle(istNeu ? "Neues Wirtschaftsgut" : "Wirtschaftsgut")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if istNeu {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schließen() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Sichern") { sichern() }
                    .disabled(kosten <= 0)
            }
        }
    }

    private func laden() {
        guard !geladen, let wirtschaftsgut else { geladen = true; return }
        geladen = true
        bezeichnung = wirtschaftsgut.bezeichnung
        anschaffungsdatum = wirtschaftsgut.anschaffungsdatum
        kosten = wirtschaftsgut.anschaffungskostenNetto
        nutzungsdauer = wirtschaftsgut.nutzungsdauerJahre
        notiz = wirtschaftsgut.notiz
    }

    private func sichern() {
        let ziel = wirtschaftsgut ?? Wirtschaftsgut()
        ziel.bezeichnung = bezeichnung
        ziel.anschaffungsdatum = anschaffungsdatum
        ziel.anschaffungskostenNetto = kosten
        ziel.nutzungsdauerJahre = nutzungsdauer
        ziel.notiz = notiz
        if wirtschaftsgut == nil { kontext.insert(ziel) }
        schließen()
    }
}

#Preview {
    NavigationStack {
        AnlagenAnsicht(jahr: Calendar.kalender.component(.year, from: Date()))
    }
    .modelContainer(Datenbank.vorschauContainer())
}
