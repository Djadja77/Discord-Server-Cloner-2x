import SwiftUI
import SwiftData

/// Jahresauswertung: Einnahmen-Überschuss-Rechnung, Umsatzsteuer und Export.
///
/// Diese Ansicht ist die Übergabe an den Steuerberater oder an ELSTER: die Zahlen stehen
/// hier in derselben Gliederung wie in der Anlage EUER.
struct EuerAnsicht: View {

    @Binding var jahr: Int
    @Query private var belege: [Beleg]
    @Query private var profile: [Steuerprofil]
    @Query private var wirtschaftsgüter: [Wirtschaftsgut]

    @AppStorage("umsatzsteuerRhythmus") private var rhythmusCode: String =
        Umsatzsteuerberechnung.Rhythmus.vierteljährlich.rawValue

    @State private var exportDateien: [URL] = []
    @State private var exportOffen = false
    @State private var exportLäuft = false
    @State private var fehler: String?

    private var profil: Steuerprofil { profile.first ?? Steuerprofil() }

    private var rhythmus: Umsatzsteuerberechnung.Rhythmus {
        get { Umsatzsteuerberechnung.Rhythmus(rawValue: rhythmusCode) ?? .vierteljährlich }
        nonmutating set { rhythmusCode = newValue.rawValue }
    }

    private var euer: EinnahmenÜberschussRechnung.Ergebnis {
        EinnahmenÜberschussRechnung.berechnen(
            belege: belege, wirtschaftsgüter: wirtschaftsgüter,
            jahr: jahr, kleinunternehmer: profil.kleinunternehmer
        )
    }

    private var umsatzsteuer: Umsatzsteuerberechnung.Ergebnis {
        Umsatzsteuerberechnung.berechnen(
            belege: belege, jahr: jahr, rhythmus: rhythmus,
            kleinunternehmer: profil.kleinunternehmer
        )
    }

    var body: some View {
        NavigationStack {
            List {
                if euer.anzahlBelege == 0 {
                    ContentUnavailableView(
                        "Keine Daten für \(String(jahr))",
                        systemImage: "tablecells",
                        description: Text("Erfasse Belege, dann erscheint hier die Auswertung.")
                    )
                    anlagenAbschnitt
                } else {
                    einnahmenAbschnitt
                    ausgabenAbschnitt
                    ergebnisAbschnitt
                    umsatzsteuerAbschnitt
                    anlagenAbschnitt
                    exportAbschnitt
                }
            }
            .navigationTitle("Auswertung")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { JahresWähler(jahr: $jahr) }
            }
            .sheet(isPresented: $exportOffen) {
                TeilenAnsicht(dateien: exportDateien)
            }
            .alert("Export fehlgeschlagen", isPresented: Binding(
                get: { fehler != nil },
                set: { if !$0 { fehler = nil } }
            )) {
                Button("OK") { fehler = nil }
            } message: {
                Text(fehler ?? "")
            }
        }
    }

    // MARK: - Abschnitte

    private var einnahmenAbschnitt: some View {
        Section {
            ForEach(euer.einnahmen) { posten in
                ZeileMitBetrag(
                    bezeichnung: posten.kategorie.bezeichnung,
                    betrag: posten.betrag,
                    unterzeile: unterzeile(posten)
                )
            }
            ZeileMitBetrag(bezeichnung: "Summe Betriebseinnahmen",
                           betrag: euer.summeEinnahmen, hervorgehoben: true)
        } header: {
            Text("Betriebseinnahmen")
        } footer: {
            Text(profil.kleinunternehmer
                 ? "Als Kleinunternehmer nach § 19 UStG werden Bruttobeträge angesetzt."
                 : "Nettobeträge ohne Umsatzsteuer.")
        }
    }

    private var ausgabenAbschnitt: some View {
        Section {
            ForEach(euer.ausgaben) { posten in
                ZeileMitBetrag(
                    bezeichnung: posten.kategorie.bezeichnung,
                    betrag: posten.betrag,
                    unterzeile: unterzeile(posten)
                )
            }
            ZeileMitBetrag(bezeichnung: "Summe Betriebsausgaben",
                           betrag: euer.summeAusgaben, hervorgehoben: true)
        } header: {
            Text("Betriebsausgaben")
        }
    }

    private func unterzeile(_ posten: EinnahmenÜberschussRechnung.Posten) -> String {
        var teile: [String] = []
        if let zeile = posten.kategorie.euerZeile { teile.append("EÜR Zeile \(zeile)") }
        teile.append("\(posten.anzahlBelege) Belege")
        if posten.wurdeGekürzt {
            teile.append("von \(Formatierung.euro(posten.betragVorKürzung, mitCent: false)) gekürzt")
        }
        return teile.joined(separator: " \u{2013} ")
    }

    private var ergebnisAbschnitt: some View {
        Section("Ergebnis") {
            ZeileMitBetrag(
                bezeichnung: euer.gewinn < 0 ? "Verlust" : "Gewinn",
                betrag: euer.gewinn,
                unterzeile: "Einnahmen-Überschuss-Rechnung nach § 4 Abs. 3 EStG",
                hervorgehoben: true,
                mitVorzeichen: true
            )
        }
    }

    @ViewBuilder
    private var umsatzsteuerAbschnitt: some View {
        if umsatzsteuer.kleinunternehmer {
            Section("Umsatzsteuer") {
                Label("Kleinunternehmer nach § 19 UStG \u{2013} keine Umsatzsteuer, kein Vorsteuerabzug.",
                      systemImage: "checkmark.seal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            Section {
                Picker("Rhythmus", selection: Binding(
                    get: { rhythmus },
                    set: { rhythmus = $0 }
                )) {
                    ForEach(Umsatzsteuerberechnung.Rhythmus.allCases) {
                        Text($0.bezeichnung).tag($0)
                    }
                }
                .pickerStyle(.segmented)

                ForEach(umsatzsteuer.zeiträume.filter {
                    $0.umsatzsteuer != 0 || $0.vorsteuer != 0
                }) { zeitraum in
                    ZeileMitBetrag(
                        bezeichnung: zeitraum.bezeichnung,
                        betrag: zeitraum.zahllast,
                        unterzeile: "USt \(Formatierung.euro(zeitraum.umsatzsteuer)) \u{2013} VSt \(Formatierung.euro(zeitraum.vorsteuer))",
                        mitVorzeichen: true
                    )
                }

                ZeileMitBetrag(bezeichnung: "Zahllast gesamt",
                               betrag: umsatzsteuer.zahllastGesamt,
                               hervorgehoben: true, mitVorzeichen: true)
            } header: {
                Text("Umsatzsteuer-Voranmeldung")
            } footer: {
                Text("Positiv = an das Finanzamt zu zahlen, negativ = Erstattung. Grundlage ist das erfasste Belegdatum (Ist-Versteuerung).")
            }
        }
    }

    private var anlagenAbschnitt: some View {
        Section {
            NavigationLink {
                AnlagenAnsicht(jahr: jahr)
            } label: {
                Label("Anlagevermögen und Abschreibung", systemImage: "shippingbox")
            }
        } footer: {
            Text("Anschaffungen über 800 Euro netto werden nicht sofort abgezogen, sondern über ihre Nutzungsdauer verteilt.")
        }
    }

    private var exportAbschnitt: some View {
        Section {
            Button {
                archivExportieren()
            } label: {
                HStack {
                    Label("Vollständige Unterlagen", systemImage: "doc.zipper")
                    if exportLäuft {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(exportLäuft)

            Button {
                nurZahlenExportieren()
            } label: {
                Label("Nur Auswertung als CSV", systemImage: "tablecells")
            }
            .disabled(exportLäuft)
        } header: {
            Text("Export")
        } footer: {
            Text("Die vollständigen Unterlagen enthalten beide Auswertungen und sämtliche Belegfotos als ZIP-Archiv \u{2013} das ist der Stand, den die Steuerberatung braucht. Die Belegliste nennt zu jeder Zeile die zugehörige Bilddatei.")
        }
    }

    /// Archiv mit Belegfotos - kann bei vielen Belegen einen Moment dauern.
    ///
    /// Der Bauplan wird auf dem Hauptstrang aus der Datenbank gelesen, das Schreiben der
    /// Dateien laeuft danach nebenher. SwiftData-Objekte dürfen den Hauptstrang nie
    /// verlassen, ein blockierter Hauptstrang friert aber die Fortschrittsanzeige ein -
    /// diese Trennung löst beides.
    @MainActor
    private func archivExportieren() {
        exportLäuft = true
        let bauplan = Unterlagenexport.bauplan(belege: belege, euer: euer, jahr: jahr)

        Task {
            do {
                // Nur das Schreiben der Dateien wandert vom Hauptstrang herunter. Der
                // umgebende Task bleibt dort, deshalb brauchen die Zuweisungen danach
                // keinen Sprung zurück.
                let archiv = try await Task.detached(priority: .userInitiated) {
                    try Unterlagenexport.archivErstellen(bauplan)
                }.value
                exportDateien = [archiv]
                exportLäuft = false
                exportOffen = true
            } catch {
                fehler = error.localizedDescription
                exportLäuft = false
            }
        }
    }

    private func nurZahlenExportieren() {
        do {
            let belegdatei = try CSVExport.datei(
                inhalt: CSVExport.belege(belege, jahr: jahr),
                name: "Belege-\(jahr).csv"
            )
            let euerdatei = try CSVExport.datei(
                inhalt: CSVExport.euer(euer),
                name: "EUER-\(jahr).csv"
            )
            exportDateien = [belegdatei, euerdatei]
            exportOffen = true
        } catch {
            fehler = error.localizedDescription
        }
    }
}

#Preview {
    EuerAnsicht(jahr: .constant(Calendar.kalender.component(.year, from: Date())))
        .modelContainer(Datenbank.vorschauContainer())
}
