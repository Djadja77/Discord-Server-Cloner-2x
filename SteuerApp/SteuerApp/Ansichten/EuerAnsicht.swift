import SwiftUI
import SwiftData

/// Jahresauswertung: Einnahmen-Ueberschuss-Rechnung, Umsatzsteuer und Export.
///
/// Diese Ansicht ist die Uebergabe an den Steuerberater oder an ELSTER: die Zahlen stehen
/// hier in derselben Gliederung wie in der Anlage EUER.
struct EuerAnsicht: View {

    @Binding var jahr: Int
    @Query private var belege: [Beleg]
    @Query private var profile: [Steuerprofil]

    @AppStorage("umsatzsteuerRhythmus") private var rhythmusCode: String =
        Umsatzsteuerberechnung.Rhythmus.vierteljaehrlich.rawValue

    @State private var exportDateien: [URL] = []
    @State private var exportOffen = false
    @State private var fehler: String?

    private var profil: Steuerprofil { profile.first ?? Steuerprofil() }

    private var rhythmus: Umsatzsteuerberechnung.Rhythmus {
        get { Umsatzsteuerberechnung.Rhythmus(rawValue: rhythmusCode) ?? .vierteljaehrlich }
        nonmutating set { rhythmusCode = newValue.rawValue }
    }

    private var euer: EinnahmenUeberschussRechnung.Ergebnis {
        EinnahmenUeberschussRechnung.berechnen(
            belege: belege, jahr: jahr, kleinunternehmer: profil.kleinunternehmer
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
                        "Keine Daten fuer \(String(jahr))",
                        systemImage: "tablecells",
                        description: Text("Erfasse Belege, dann erscheint hier die Auswertung.")
                    )
                } else {
                    einnahmenAbschnitt
                    ausgabenAbschnitt
                    ergebnisAbschnitt
                    umsatzsteuerAbschnitt
                    exportAbschnitt
                }
            }
            .navigationTitle("Auswertung")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { JahresWaehler(jahr: $jahr) }
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
                 ? "Als Kleinunternehmer nach § 19 UStG werden Bruttobetraege angesetzt."
                 : "Nettobetraege ohne Umsatzsteuer.")
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

    private func unterzeile(_ posten: EinnahmenUeberschussRechnung.Posten) -> String {
        var teile: [String] = []
        if let zeile = posten.kategorie.euerZeile { teile.append("EUER Zeile \(zeile)") }
        teile.append("\(posten.anzahlBelege) Belege")
        if posten.wurdeGekuerzt {
            teile.append("von \(Formatierung.euro(posten.betragVorKuerzung, mitCent: false)) gekuerzt")
        }
        return teile.joined(separator: " \u{2013} ")
    }

    private var ergebnisAbschnitt: some View {
        Section("Ergebnis") {
            ZeileMitBetrag(
                bezeichnung: euer.gewinn < 0 ? "Verlust" : "Gewinn",
                betrag: euer.gewinn,
                unterzeile: "Einnahmen-Ueberschuss-Rechnung nach § 4 Abs. 3 EStG",
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

                ForEach(umsatzsteuer.zeitraeume.filter {
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

    private var exportAbschnitt: some View {
        Section {
            Button {
                exportieren()
            } label: {
                Label("Belege und Auswertung exportieren", systemImage: "square.and.arrow.up")
            }
        } footer: {
            Text("Zwei CSV-Dateien mit Semikolon als Trennzeichen \u{2013} direkt in Excel oder Numbers zu oeffnen und an die Steuerberatung weiterzugeben.")
        }
    }

    private func exportieren() {
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
