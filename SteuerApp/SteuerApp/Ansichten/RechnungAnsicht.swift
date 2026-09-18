import SwiftUI
import SwiftData
import PDFKit

/// Eine gestellte Rechnung: das Dokument, dazu alles, was man damit noch tun kann.
struct RechnungAnsicht: View {

    @Bindable var rechnung: Rechnung

    @Environment(\.modelContext) private var kontext
    @Query private var profile: [Steuerprofil]
    @Query(sort: \Ordner.reihenfolge) private var ordner: [Ordner]

    @State private var datei: URL?
    @State private var stornoGefragt = false
    @State private var bezahltAm = Date()
    @State private var zahlungGefragt = false
    @State private var zuLöschen: Rechnung?
    @Environment(\.dismiss) private var schließen

    private var profil: Steuerprofil { profile.first ?? Steuerprofil() }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                kopf
                dokument
                knöpfe
                ablage
                angaben
                steuerhinweis
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
        .rechnungLoeschen(zuLöschen: $zuLöschen, vorherSchliessen: { schließen() })
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

            Button(role: .destructive) { zuLöschen = rechnung } label: {
                Label("Rechnung löschen", systemImage: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Stil.gefahr)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .alsGlas(Capsule())
            }
            .buttonStyle(.plain)
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
            if rechnung.zahlungszielZeigen {
                Trennzeile()
                textzeile("Zahlbar bis", Formatierung.datum(rechnung.zahlbarBis))
            }
            if let bezahlt = rechnung.bezahltAm {
                Trennzeile()
                textzeile("Bezahlt am", Formatierung.datum(bezahlt))
            }
        }
        .padding(.horizontal, 15)
        .alsGlas()
    }

    /// In welchem Ordner die Rechnung liegt - auch nachträglich noch zu ändern.
    ///
    /// Das ist kein Widerspruch zur Unveränderlichkeit einer gestellten Rechnung: der
    /// Ordner steht auf keinem Dokument. Er ist Ablage, nicht Inhalt - so wie es keinen
    /// Unterschied macht, in welchen Aktenordner man ein Blatt heftet.
    private var ablage: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 15))
                .foregroundStyle(Stil.schriftGedämpft)
                .frame(width: 22)

            Text("Ordner")
                .font(.system(size: 15))
                .foregroundStyle(Stil.schrift)

            Spacer(minLength: 8)

            Menu {
                Button("Keiner") { rechnung.ordner = nil }
                if !ordner.isEmpty { Divider() }
                ForEach(ordner) { mappe in
                    Button(mappe.name.isEmpty ? "Ohne Namen" : mappe.name) { rechnung.ordner = mappe }
                }
                if ordner.isEmpty { Text("Noch kein Ordner angelegt") }
            } label: {
                HStack(spacing: 7) {
                    if let mappe = rechnung.ordner {
                        Circle().fill(Stil.ordnerfarbe(mappe.farbindex)).frame(width: 8, height: 8)
                    }
                    Text(rechnung.ordner?.name.isEmpty == false
                         ? rechnung.ordner!.name
                         : (rechnung.ordner == nil ? "Keiner" : "Ohne Namen"))
                        .font(.system(size: 15))
                        .foregroundStyle(rechnung.ordner == nil ? Stil.schriftGedämpft : Stil.schrift)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Stil.schriftLeise)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 15)
        .alsGlas()
    }

    /// Sagt geradeheraus, was die Rechnungen mit der Steuer zu tun haben: nichts.
    ///
    /// Ohne diesen Satz nimmt man an, eine bezahlte Rechnung sei damit auch gebucht -
    /// und wundert sich im Herbst über einen zu niedrigen Gewinn.
    private var steuerhinweis: some View {
        Hinweiszeile(
            text: "Rechnungen sind ein eigener Bereich und fließen nicht in Gewinn, EÜR oder "
                + "Schätzung ein. Damit der Zahlungseingang zählt, erfasse ihn unter „Belege“.",
            symbol: "info.circle"
        )
        .padding(14)
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
                    Text("Ändert nur den Zustand dieser Rechnung. In der Steuerschätzung taucht der "
                         + "Betrag dadurch nicht auf - dafür ist der Bereich „Belege“ da.")
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
