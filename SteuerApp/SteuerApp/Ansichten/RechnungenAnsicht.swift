import SwiftUI
import SwiftData

/// Alle ausgehenden Rechnungen eines Jahres.
///
/// Oben steht, was offen ist - das ist die Frage, wegen der man diesen Bildschirm
/// öffnet. Erst darunter kommt die Liste.
struct RechnungenAnsicht: View {

    @Binding var jahr: Int

    @Environment(\.modelContext) private var kontext
    @Query(sort: \Rechnung.datum, order: .reverse) private var alleRechnungen: [Rechnung]
    @Query(sort: \Ordner.reihenfolge) private var ordner: [Ordner]
    @Query private var profile: [Steuerprofil]

    @State private var filter: Filter = .alle
    @State private var gewählterOrdner: Ordner?
    @State private var entwurf: Rechnung?
    @State private var ordnerVerwalten = false
    @State private var zuLöschen: Rechnung?

    private var profil: Steuerprofil { profile.first ?? Steuerprofil() }

    enum Filter: String, CaseIterable, Identifiable {
        case alle, offen, überfällig, bezahlt, entwürfe, storniert

        var id: String { rawValue }

        var bezeichnung: String {
            switch self {
            case .alle: "Alle"
            case .offen: "Offen"
            case .überfällig: "Überfällig"
            case .bezahlt: "Bezahlt"
            case .entwürfe: "Entwürfe"
            case .storniert: "Storniert"
            }
        }
    }

    var body: some View {
        NavigationStack {
            inhalt
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var inhalt: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                kopfzeile
                offenKarte
                Filterpillen(auswahl: Filter.allCases.map { (wert: $0, titel: $0.bezeichnung) },
                             gewählt: $filter)
                    .padding(.top, 16)
                ordnerreihe

                if gefiltert.isEmpty {
                    LeerHinweis(
                        symbol: "doc.text",
                        titel: "Keine Rechnung",
                        text: leertext
                    )
                    if filter == .alle && gewählterOrdner == nil {
                        Button("Rechnung schreiben") { neuAnlegen() }
                            .buttonStyle(HauptknopfStil())
                            .padding(.horizontal, Stil.rand + 14)
                            .padding(.top, 20)
                    }
                } else {
                    liste
                }
            }
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .aufGrund()
        .sheet(item: $entwurf) { rechnung in
            RechnungBearbeitenAnsicht(rechnung: rechnung)
        }
        .sheet(isPresented: $ordnerVerwalten) { OrdnerAnsicht() }
        .rechnungLoeschen(zuLöschen: $zuLöschen)
    }

    // MARK: - Bausteine

    private var kopfzeile: some View {
        HStack(spacing: 10) {
            Text("Rechnungen")
                .font(Stil.titel())
                .foregroundStyle(Stil.schrift)
            Spacer()
            Jahrespille(jahr: $jahr)
            Menu {
                Button("Rechnung schreiben", systemImage: "square.and.pencil") { neuAnlegen() }
                NavigationLink("Kunden", destination: KundenAnsicht())
                Button("Ordner verwalten", systemImage: "folder") { ordnerVerwalten = true }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Stil.schrift)
                    .frame(width: 38, height: 34)
                    .alsGlas(Capsule())
            }
            .accessibilityLabel("Neu")
        }
        .padding(.horizontal, Stil.rand)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var offenKarte: some View {
        VStack(alignment: .leading, spacing: 14) {
            Betragskopf(
                beschriftung: "Offen",
                betrag: summeOffen,
                mitVorzeichen: false,
                beischrift: beischrift,
                hochzählen: false
            )
        }
        .alsKarte()
        .padding(.horizontal, Stil.rand)
    }

    private var beischrift: String {
        let anzahl = desJahres.filter { $0.status == .offen }.count
        let überfällig = summeÜberfällig
        if überfällig > 0 {
            return "\(anzahl) offen · davon \(Formatierung.euro(überfällig, mitCent: false)) überfällig"
        }
        return anzahl == 1 ? "1 offene Rechnung" : "\(anzahl) offene Rechnungen"
    }

    @ViewBuilder
    private var ordnerreihe: some View {
        if !ordner.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ordnerpille(nil, titel: "Alle Ordner")
                    ForEach(ordner) { mappe in
                        ordnerpille(mappe, titel: mappe.name.isEmpty ? "Ohne Namen" : mappe.name)
                    }
                }
                .padding(.horizontal, Stil.rand)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .padding(.top, 10)
        }
    }

    private func ordnerpille(_ mappe: Ordner?, titel: String) -> some View {
        let aktiv = gewählterOrdner?.persistentModelID == mappe?.persistentModelID
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { gewählterOrdner = mappe }
        } label: {
            HStack(spacing: 6) {
                if let mappe {
                    Circle().fill(Stil.ordnerfarbe(mappe.farbindex)).frame(width: 8, height: 8)
                }
                Text(titel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(aktiv ? Stil.schrift : Stil.schriftGedämpft)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .alsGlas(Capsule())
            .overlay(Capsule().strokeBorder(aktiv ? Stil.akzent : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private var liste: some View {
        VStack(spacing: 0) {
            ForEach(Array(gefiltert.enumerated()), id: \.element.id) { stelle, rechnung in
                if rechnung.istEntwurf {
                    Button { entwurf = rechnung } label: { RechnungZeile(rechnung: rechnung) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            ordnerwahl(für: rechnung)
                            Divider()
                            Button("Entwurf löschen", role: .destructive) { zuLöschen = rechnung }
                        }
                } else {
                    NavigationLink { RechnungAnsicht(rechnung: rechnung) } label: {
                        RechnungZeile(rechnung: rechnung)
                    }
                    .buttonStyle(.plain)
                    // Ablegen ohne Umweg über die Rechnung selbst - beim Aufräumen
                    // schiebt man mehrere hintereinander.
                    .contextMenu {
                        ordnerwahl(für: rechnung)
                        Divider()
                        Button("Löschen", role: .destructive) { zuLöschen = rechnung }
                    }
                }
                if stelle < gefiltert.count - 1 { Trennzeile(einzug: 14) }
            }
        }
        .padding(.horizontal, 15)
        .alsGlas()
        .padding(.horizontal, Stil.rand)
        .padding(.top, 16)
    }

    @ViewBuilder
    private func ordnerwahl(für rechnung: Rechnung) -> some View {
        Button("In keinen Ordner") { rechnung.ordner = nil }
        ForEach(ordner) { mappe in
            Button(mappe.name.isEmpty ? "Ohne Namen" : mappe.name) { rechnung.ordner = mappe }
        }
        if ordner.isEmpty { Text("Noch kein Ordner angelegt") }
    }

    private var leertext: String {
        switch filter {
        case .alle: "Für \(String(jahr)) ist noch keine Rechnung angelegt."
        case .offen: "Alles bezahlt."
        case .überfällig: "Nichts überfällig."
        case .bezahlt: "Noch keine Rechnung als bezahlt eingetragen."
        case .entwürfe: "Kein Entwurf offen."
        case .storniert: "Nichts storniert."
        }
    }

    // MARK: - Abgeleitete Werte

    private var desJahres: [Rechnung] {
        alleRechnungen.filter { Calendar.kalender.component(.year, from: $0.datum) == jahr }
    }

    private var gefiltert: [Rechnung] {
        desJahres
            .filter { rechnung in
                switch filter {
                case .alle: true
                case .offen: rechnung.status == .offen
                case .überfällig: rechnung.istÜberfällig
                case .bezahlt: rechnung.status == .bezahlt
                case .entwürfe: rechnung.istEntwurf
                case .storniert: rechnung.status == .storniert
                }
            }
            .filter { rechnung in
                guard let gewählterOrdner else { return true }
                return rechnung.ordner?.persistentModelID == gewählterOrdner.persistentModelID
            }
    }

    private var summeOffen: Decimal {
        desJahres.filter { $0.status == .offen }.reduce(0) { $0 + $1.brutto }
    }

    private var summeÜberfällig: Decimal {
        desJahres.filter(\.istÜberfällig).reduce(0) { $0 + $1.brutto }
    }

    // MARK: - Vorgänge

    private func neuAnlegen() {
        let heute = Date()
        let ziel = Calendar.kalender.date(byAdding: .day, value: profil.zahlungszielTage, to: heute) ?? heute
        let rechnung = Rechnung(jahr: jahr, datum: heute, zahlbarBis: ziel)
        rechnung.leistungVon = heute
        rechnung.ordner = gewählterOrdner
        rechnung.fusstext = profil.rechnungsfusstext
        kontext.insert(rechnung)
        entwurf = rechnung
    }
}

/// Eine Zeile in der Rechnungsliste.
struct RechnungZeile: View {

    let rechnung: Rechnung

    var body: some View {
        HStack(spacing: 13) {
            VStack(alignment: .leading, spacing: 3) {
                Text(rechnung.empfaengerName.isEmpty
                     ? (rechnung.kunde?.name ?? "Ohne Empfänger")
                     : rechnung.empfaengerName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Stil.schrift)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(rechnung.istEntwurf ? "Entwurf" : rechnung.nummer)
                        .font(.system(size: 12))
                        .foregroundStyle(Stil.schriftLeise)
                    Text("·").foregroundStyle(Stil.schriftLeise)
                    Text(Formatierung.datum(rechnung.datum))
                        .font(.system(size: 12))
                        .foregroundStyle(Stil.schriftLeise)
                    if let mappe = rechnung.ordner {
                        Circle().fill(Stil.ordnerfarbe(mappe.farbindex)).frame(width: 6, height: 6)
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(Formatierung.euro(rechnung.brutto))
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Stil.schrift)
                Statusmarke(text: marke, farbe: ton)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var marke: String {
        if rechnung.istÜberfällig { return "\(rechnung.tageÜberfällig) T über" }
        return rechnung.status.bezeichnung
    }

    private var ton: Color {
        if rechnung.istÜberfällig { return Stil.gefahr }
        switch rechnung.status {
        case .bezahlt: return Stil.haben
        case .offen: return Stil.warnung
        case .entwurf, .storniert: return Stil.schriftGedämpft
        }
    }
}

/// Die Mappen, in denen Rechnungen liegen.
struct OrdnerAnsicht: View {

    @Environment(\.modelContext) private var kontext
    @Environment(\.dismiss) private var schließen
    @Query(sort: \Ordner.reihenfolge) private var ordner: [Ordner]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(ordner) { mappe in
                        HStack(spacing: 12) {
                            Circle().fill(Stil.ordnerfarbe(mappe.farbindex)).frame(width: 14, height: 14)
                            TextField("Name", text: namensbindung(mappe))
                                .tastaturFertig()
                            Button {
                                mappe.farbindex = (mappe.farbindex + 1) % Ordner.farbanzahl
                            } label: {
                                Image(systemName: "paintpalette")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Stil.schriftGedämpft)
                        }
                    }
                    .onDelete(perform: löschen)

                    Button("Ordner anlegen", systemImage: "folder.badge.plus") { anlegen() }
                } header: {
                    Text("Ordner")
                } footer: {
                    Text("Wofür ein Ordner steht, entscheidest du - ein Kunde, ein Projekt, ein Standbein. "
                         + "Eine Rechnung muss in keinem liegen. Wird ein Ordner gelöscht, bleiben seine "
                         + "Rechnungen erhalten und liegen danach in keinem Ordner.")
                }
            }
            .alsListe()
            .navigationTitle("Ordner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schließen() } }
            }
        }
    }

    private func namensbindung(_ mappe: Ordner) -> Binding<String> {
        Binding(get: { mappe.name }, set: { mappe.name = $0 })
    }

    private func anlegen() {
        let neu = Ordner(
            name: "",
            farbindex: ordner.count % Ordner.farbanzahl,
            reihenfolge: (ordner.last?.reihenfolge ?? -1) + 1
        )
        kontext.insert(neu)
    }

    private func löschen(_ stellen: IndexSet) {
        for stelle in stellen where ordner.indices.contains(stelle) {
            kontext.delete(ordner[stelle])
        }
    }
}

/// Der Rückfrage-Dialog vor dem Löschen einer Rechnung.
///
/// Als Modifikator, weil ihn die Liste und die Rechnung selbst brauchen und der Text
/// nirgends auseinanderlaufen darf.
///
/// Der Unterschied, um den es geht: ein **Entwurf** ist ein Zettel, den es nie gegeben
/// hat - weg damit, ohne Aufhebens. Eine **gestellte Rechnung** liegt dagegen beim
/// Empfänger und trägt eine Nummer aus einem Kreis, der lückenlos sein soll. Sie zu
/// löschen ist genau das, was die GoBD nicht wollen; der vorgesehene Weg ist der Storno.
/// Möglich ist es trotzdem - es ist deine App und dein Beleg. Aber nicht, ohne dass
/// dasteht, was es bedeutet.
struct RechnungLöschen: ViewModifier {

    @Binding var zuLöschen: Rechnung?
    /// Wird gerufen, bevor gelöscht wird.
    ///
    /// Die Rechnungsansicht zeigt genau das Objekt an, das gleich verschwindet - sie
    /// muss sich vorher schliessen, sonst greift sie beim nächsten Zeichnen auf etwas
    /// zu, das es nicht mehr gibt.
    var vorherSchliessen: (() -> Void)?
    @Environment(\.modelContext) private var kontext

    func body(content: Content) -> some View {
        content.confirmationDialog(
            zuLöschen?.istEntwurf == true ? "Entwurf löschen?" : "Rechnung wirklich löschen?",
            isPresented: Binding(get: { zuLöschen != nil }, set: { if !$0 { zuLöschen = nil } }),
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) { löschen() }
            Button("Abbrechen", role: .cancel) { zuLöschen = nil }
        } message: {
            Text(hinweis)
        }
    }

    private var hinweis: String {
        guard let rechnung = zuLöschen else { return "" }
        if rechnung.istEntwurf {
            return "Der Entwurf wird verworfen. Eine Nummer hat er noch nicht verbraucht."
        }
        return "Die Nummer \(rechnung.nummer) fehlt danach im Nummernkreis. Bei einer Prüfung ist "
            + "eine Lücke erklärungsbedürftig - der vorgesehene Weg ist die Stornorechnung, dabei "
            + "bleiben beide Belege stehen. Das Löschen lässt sich nicht rückgängig machen."
    }

    private func löschen() {
        guard let rechnung = zuLöschen else { return }
        zuLöschen = nil
        vorherSchliessen?()
        // Die Positionen nimmt die Löschregel der Beziehung mit.
        kontext.delete(rechnung)
        try? kontext.save()
    }
}

extension View {

    /// Hängt die Rückfrage vor dem Löschen einer Rechnung an eine Ansicht.
    func rechnungLoeschen(
        zuLöschen: Binding<Rechnung?>, vorherSchliessen: (() -> Void)? = nil
    ) -> some View {
        modifier(RechnungLöschen(zuLöschen: zuLöschen, vorherSchliessen: vorherSchliessen))
    }
}
