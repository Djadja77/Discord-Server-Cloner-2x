import SwiftUI
import SwiftData

/// Mehrere Belege auf einmal erfassen.
///
/// Der eigentliche Engpass beim Belegsammeln ist nicht das Fotografieren, sondern das
/// Abtippen danach. Diese Ansicht nimmt einen ganzen Scan-Stapel entgegen, liest jeden
/// Beleg aus und legt alles zur Kontrolle nebeneinander. In der Regel bleibt nur noch
/// übrig, eine Kategorie zu korrigieren und zu sichern.
struct StapelErfassungAnsicht: View {

    let bilder: [UIImage]
    let vorgabeJahr: Int

    @Environment(\.modelContext) private var kontext
    @Environment(\.dismiss) private var schließen

    @State private var posten: [Posten] = []
    @State private var erkennungLäuft = true
    @State private var großansicht: UIImage?
    @State private var fehler: String?

    struct Posten: Identifiable {
        let id = UUID()
        var entwurf: Belegentwurf
        let bild: UIImage
    }

    /// Wie viele Belege noch keinen Betrag haben - sie werden trotzdem gesichert.
    private var ohneBetrag: Int { posten.filter { !$0.entwurf.istVollständig }.count }

    var body: some View {
        NavigationStack {
            Group {
                if erkennungLäuft {
                    fortschritt
                } else if posten.isEmpty {
                    ContentUnavailableView(
                        "Nichts erfasst",
                        systemImage: "doc.viewfinder",
                        description: Text("Der Scan hat keine Seiten geliefert.")
                    )
                } else {
                    liste
                }
            }
            .alsListe()
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schließen() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { alleSichern() }
                        .disabled(posten.isEmpty || erkennungLäuft)
                }
            }
            .task { await auswerten() }
            .fullScreenCover(item: Binding(
                get: { großansicht.map(BildKennung.init) },
                set: { if $0 == nil { großansicht = nil } }
            )) { kennung in
                BelegbildAnsicht(bild: kennung.bild)
            }
            .alert("Sichern fehlgeschlagen", isPresented: Binding(
                get: { fehler != nil },
                set: { if !$0 { fehler = nil } }
            )) {
                Button("OK") { fehler = nil }
            } message: {
                Text(fehler ?? "")
            }
        }
    }

    private var titel: String {
        if erkennungLäuft { return "Belege werden gelesen" }
        return posten.count == 1 ? "1 Beleg" : "\(posten.count) Belege"
    }

    // MARK: - Bausteine

    private var fortschritt: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                Text(bilder.count == 1
                 ? "Beleg wird ausgelesen ..."
                 : "\(bilder.count) Belege werden ausgelesen ...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var liste: some View {
        List {
            hinweisAbschnitt

            ForEach($posten) { $eintrag in
                Section {
                    kopfzeile(fuer: eintrag)

                    TextField("Bezeichnung", text: $eintrag.entwurf.bezeichnung)
                        .tastaturFertig()

                    DatePicker("Datum", selection: $eintrag.entwurf.datum,
                               displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "de_DE"))

                    BetragsFeld(titel: "Bruttobetrag", betrag: $eintrag.entwurf.bruttoBetrag,
                               sofortÜbernehmen: true)

                    Picker("Kategorie", selection: $eintrag.entwurf.kategorie) {
                        Section("Ausgaben") {
                            ForEach(Belegkategorie.ausgabekategorien) { kategorie in
                                Text(kategorie.bezeichnung).tag(kategorie)
                            }
                        }
                        Section("Einnahmen") {
                            ForEach(Belegkategorie.einnahmekategorien) { kategorie in
                                Text(kategorie.bezeichnung).tag(kategorie)
                            }
                        }
                    }

                    Picker("Umsatzsteuer", selection: $eintrag.entwurf.umsatzsteuersatz) {
                        ForEach(Umsatzsteuersatz.allCases) { satz in
                            Text(satz.bezeichnung).tag(satz)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    if !eintrag.entwurf.istVollständig {
                        Label("Betrag nicht erkannt - wird mit 0,00 € gesichert und kann später nachgetragen werden.",
                              systemImage: "exclamationmark.triangle")
                            .font(.caption)
                    }
                }
            }
            .onDelete { posten.remove(atOffsets: $0) }
        }
    }

    private func kopfzeile(fuer eintrag: Posten) -> some View {
        HStack(spacing: 12) {
            Button {
                großansicht = eintrag.bild
            } label: {
                Image(uiImage: eintrag.bild)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(eintrag.entwurf.bezeichnung.isEmpty
                     ? "Nicht erkannt" : eintrag.entwurf.bezeichnung)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text("Zum Vergrößern auf das Foto tippen")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .listRowSeparator(.hidden)
    }

    private var hinweisAbschnitt: some View {
        Section {
            Label(
                "Die Werte stammen aus der Texterkennung und sind Vorschläge. Bitte kurz gegenlesen \u{2013} besonders Betrag und Kategorie.",
                systemImage: "info.circle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if ohneBetrag > 0 {
                Label(
                    ohneBetrag == 1
                        ? "Bei einem Beleg wurde kein Betrag erkannt. Er wird trotzdem gesichert."
                        : "Bei \(ohneBetrag) Belegen wurde kein Betrag erkannt. Sie werden trotzdem gesichert.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Verhalten

    /// Wie viele Belege gleichzeitig durch die Texterkennung laufen.
    ///
    /// Nicht alle auf einmal: jede Erkennung hält ein entzerrtes Vollbild im Speicher,
    /// und ein Stapel von zwanzig Quittungen würde zwanzig davon nebeneinander halten.
    /// Vier ausgelastete Läufe sind auf dem Gerät genauso schnell wie zwanzig sich
    /// gegenseitig behindernde - nur ohne die Speicherspitze.
    private static let gleichzeitigeErkennungen = 4

    /// Liest alle Belege aus, immer nur ein paar gleichzeitig.
    ///
    /// Sobald einer fertig ist, rückt genau einer nach. Damit bleibt die Auslastung
    /// konstant, statt am Anfang alles loszutreten und am Ende zu warten.
    private func vorschlaegeLesen() async -> [Int: BelegTexterkennung.Vorschlag] {
        await withTaskGroup(of: (Int, BelegTexterkennung.Vorschlag).self) { gruppe in
            var ergebnis: [Int: BelegTexterkennung.Vorschlag] = [:]
            var nächster = 0

            func nachschieben() {
                guard nächster < bilder.count else { return }
                let stelle = nächster
                let bild = bilder[stelle]
                gruppe.addTask { (stelle, await BelegTexterkennung.auswerten(bild: bild)) }
                nächster += 1
            }

            for _ in 0..<min(Self.gleichzeitigeErkennungen, bilder.count) { nachschieben() }

            for await (stelle, vorschlag) in gruppe {
                ergebnis[stelle] = vorschlag
                nachschieben()
            }
            return ergebnis
        }
    }

    private func auswerten() async {
        guard posten.isEmpty else { return }

        let vorschläge = await vorschlaegeLesen()

        var neue: [Posten] = []
        for (index, bild) in bilder.enumerated() {
            var entwurf = Belegentwurf()
            entwurf.datum = Belegentwurf.vorgabedatum(fuerJahr: vorgabeJahr)
            if let vorschlag = vorschläge[index] {
                entwurf.übernehmen(vorschlag, steuerjahr: vorgabeJahr)
            }
            neue.append(Posten(entwurf: entwurf, bild: bild))
        }

        posten = neue
        erkennungLäuft = false
    }

    /// Erst alle Fotos schreiben, dann alle Belege anlegen.
    ///
    /// Bewusst in zwei Schritten: scheitert das Speichern eines Fotos mittendrin, wären
    /// sonst die ersten Belege schon in der Datenbank und ein zweiter Versuch würde sie
    /// verdoppeln. So bleibt der Stapel entweder ganz oder gar nicht erfasst.
    ///
    /// Gesichert wird **jeder** gescannte Beleg, auch der ohne erkannten Betrag. Das Foto
    /// ist der aufbewahrungspflichtige Teil; ein Betrag lässt sich jederzeit nachtragen,
    /// ein weggeworfener Scan nicht. Vorher fielen unvollständige Belege stillschweigend
    /// heraus - wer einen einzelnen Bon scannte, dessen Betrag die Texterkennung nicht
    /// fand, stand vor einem abgeblendeten Sichern-Knopf ohne Erklärung.
    private func alleSichern() {
        var dateien: [UUID: String] = [:]
        do {
            for eintrag in posten {
                dateien[eintrag.id] = try Belegarchiv.speichern(eintrag.bild)
            }
        } catch {
            dateien.values.forEach(Belegarchiv.löschen)
            fehler = error.localizedDescription
            return
        }

        for eintrag in posten {
            var entwurf = eintrag.entwurf
            entwurf.belegbildDatei = dateien[eintrag.id]
            let beleg = Beleg()
            entwurf.anwenden(auf: beleg)
            kontext.insert(beleg)
        }
        schließen()
    }

    /// Hülle, damit ein `UIImage` als Kennung für `fullScreenCover(item:)` taugt.
    private struct BildKennung: Identifiable {
        let bild: UIImage
        var id: ObjectIdentifier { ObjectIdentifier(bild) }
    }
}
