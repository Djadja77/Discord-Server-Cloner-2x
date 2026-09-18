import SwiftUI
import SwiftData
import PDFKit

/// Eine gestellte Rechnung: das Dokument, dazu alles, was man damit noch tun kann.
struct RechnungAnsicht: View {

    @Bindable var rechnung: Rechnung

    @Environment(\.modelContext) private var kontext
    @Query private var profile: [Steuerprofil]

    @State private var datei: URL?
    @State private var stornoGefragt = false
    @State private var bezahltAm = Date()
    @State private var zahlungGefragt = false

    private var profil: Steuerprofil { profile.first ?? Steuerprofil() }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                kopf
                dokument
                knöpfe
                angaben
            }
            .padding(.horizontal, Stil.rand)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .aufGrund()
        .navigationTitle(rechnung.nummer)
        .navigationBarTitleDisplayMode(.inline)
        .task { dateiSchreiben() }
        .confirmationDialog(
            "Rechnung stornieren?",
            isPresented: $stornoGefragt,
            titleVisibility: .visible
        ) {
            Button("Stornorechnung erstellen", role: .destructive) { stornieren() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die Rechnung bleibt bestehen und wird durch eine neue Rechnung mit umgekehrten "
                 + "Beträgen aufgehoben. Beide Belege bleiben in der Liste - so verlangen es die GoBD.")
        }
        .sheet(isPresented: $zahlungGefragt) { zahlungsblatt }
    }

    // MARK: - Bausteine

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rechnung.empfaengerName.isEmpty ? "Ohne Empfänger" : rechnung.empfaengerName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Stil.schrift)
                    Text("vom \(Formatierung.datum(rechnung.datum))")
                        .font(.system(size: 13))
                        .foregroundStyle(Stil.schriftGedämpft)
                }
                Spacer()
                Statusmarke(text: statustext, farbe: statuston)
            }

            Text(Formatierung.euro(rechnung.brutto))
                .font(.system(size: 32, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Stil.schrift)

            if !rechnung.stornoFuerNummer.isEmpty {
                Hinweiszeile(text: "Hebt die Rechnung \(rechnung.stornoFuerNummer) auf.",
                             symbol: "arrow.uturn.backward")
            }
            if !rechnung.storniertDurchNummer.isEmpty {
                Hinweiszeile(text: "Aufgehoben durch die Stornorechnung \(rechnung.storniertDurchNummer).",
                             symbol: "xmark.circle")
            }
        }
        .alsKarte()
        .padding(.top, 10)
    }

    @ViewBuilder
    private var dokument: some View {
        if let datei {
            PDFBlatt(datei: datei)
                .frame(height: 440)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Stil.umriss, lineWidth: 1))
        } else {
            ProgressView().frame(height: 200)
        }
    }

    private var knöpfe: some View {
        VStack(spacing: 10) {
            if let datei {
                ShareLink(item: datei) {
                    Label("Rechnung senden", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Stil.akzent, in: Capsule())
                        .foregroundStyle(.white)
                        .font(.system(size: 16, weight: .semibold))
                }
            }

            switch rechnung.status {
            case .offen:
                Button("Als bezahlt markieren") {
                    bezahltAm = Date()
                    zahlungGefragt = true
                }
                .buttonStyle(NebenknopfStil())
                Button("Stornieren") { stornoGefragt = true }
                    .buttonStyle(NebenknopfStil())
            case .bezahlt:
                Button("Zahlung zurücknehmen") {
                    Rechnungsstellung.zahlungZurücknehmen(rechnung, in: kontext)
                }
                .buttonStyle(NebenknopfStil())
                Button("Stornieren") { stornoGefragt = true }
                    .buttonStyle(NebenknopfStil())
            case .storniert, .entwurf:
                EmptyView()
            }
        }
    }

    private var angaben: some View {
        VStack(spacing: 0) {
            Postenzeile(bezeichnung: "Nettobetrag", betrag: rechnung.netto)
            if !rechnung.kleinunternehmer {
                ForEach(Array(rechnung.umsatzsteuerJeSatz.enumerated()), id: \.offset) { _, satz in
                    Trennzeile()
                    Postenzeile(bezeichnung: "Umsatzsteuer \(satz.satz.bezeichnung)", betrag: satz.steuer)
                }
            }
            Trennzeile()
            textzeile("Zahlbar bis", Formatierung.datum(rechnung.zahlbarBis))
            if let bezahlt = rechnung.bezahltAm {
                Trennzeile()
                textzeile("Bezahlt am", Formatierung.datum(bezahlt))
            }
            if rechnung.beleg != nil {
                Trennzeile()
                textzeile("In der EÜR", "als Einnahme erfasst")
            }
        }
        .padding(.horizontal, 15)
        .alsGlas()
    }

    /// Wie `Postenzeile`, nur für Angaben, die kein Geldbetrag sind.
    private func textzeile(_ bezeichnung: String, _ wert: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(bezeichnung)
                .font(.system(size: 15))
                .foregroundStyle(Stil.schrift)
            Spacer(minLength: 8)
            Text(wert)
                .font(.system(size: 15))
                .foregroundStyle(Stil.schriftGedämpft)
        }
        .padding(.vertical, 13)
    }

    private var zahlungsblatt: some View {
        NavigationStack {
            Form {
                DatePicker("Zahlungseingang", selection: $bezahltAm, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "de_DE"))
                Section {
                    Text("Die App legt dazu eine Einnahme über \(Formatierung.euro(rechnung.brutto)) an. "
                         + "Ohne sie fehlte der Betrag in der Einnahmen-Überschuss-Rechnung.")
                        .font(.system(size: 14))
                        .foregroundStyle(Stil.schriftGedämpft)
                }
            }
            .alsListe()
            .navigationTitle("Bezahlt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { zahlungGefragt = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Eintragen") {
                        Rechnungsstellung.bezahltSetzen(rechnung, am: bezahltAm, in: kontext)
                        zahlungGefragt = false
                    }
                }
            }
        }
    }

    // MARK: - Zustand

    private var statustext: String {
        if rechnung.istÜberfällig { return "\(rechnung.tageÜberfällig) Tage über" }
        return rechnung.status.bezeichnung
    }

    private var statuston: Color {
        if rechnung.istÜberfällig { return Stil.gefahr }
        switch rechnung.status {
        case .bezahlt: return Stil.haben
        case .offen: return Stil.warnung
        case .storniert, .entwurf: return Stil.schriftGedämpft
        }
    }

    // MARK: - Vorgänge

    /// Schreibt das PDF in einen Ordner, aus dem heraus es sich teilen lässt.
    ///
    /// Der Name der Datei ist der, den der Empfänger im Anhang sieht - deshalb steht die
    /// Rechnungsnummer darin und nicht eine Folge von Zufallszeichen.
    private func dateiSchreiben() {
        let daten = RechnungPDF.erzeugen(rechnung)
        let ziel = FileManager.default.temporaryDirectory
            .appendingPathComponent(RechnungPDF.dateiname(rechnung))
        try? daten.write(to: ziel, options: .atomic)
        datei = ziel
    }

    private func stornieren() {
        Rechnungsstellung.stornieren(rechnung, profil: profil, in: kontext)
        dateiSchreiben()
    }
}

/// Zeigt ein PDF an.
private struct PDFBlatt: UIViewRepresentable {

    let datei: URL

    func makeUIView(context: Context) -> PDFView {
        let ansicht = PDFView()
        ansicht.autoScales = true
        ansicht.backgroundColor = .clear
        ansicht.document = PDFDocument(url: datei)
        return ansicht
    }

    func updateUIView(_ ansicht: PDFView, context: Context) {
        if ansicht.document?.documentURL != datei {
            ansicht.document = PDFDocument(url: datei)
        }
    }
}
