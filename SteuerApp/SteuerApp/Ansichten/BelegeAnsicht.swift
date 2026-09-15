import SwiftUI
import SwiftData

/// Alle Belege eines Jahres - suchbar, filterbar, löschbar.
struct BelegeAnsicht: View {

    @Binding var jahr: Int
    @Environment(\.modelContext) private var kontext
    @Query(sort: \Beleg.datum, order: .reverse) private var alleBelege: [Beleg]

    @State private var suchtext = ""
    @State private var filter: Filter = .alle
    @FocusState private var sucheAktiv: Bool

    enum Filter: String, CaseIterable, Identifiable {
        case alle, einnahmen, ausgaben, ohneBeleg

        var id: String { rawValue }

        var bezeichnung: String {
            switch self {
            case .alle: "Alle"
            case .einnahmen: "Einnahmen"
            case .ausgaben: "Ausgaben"
            case .ohneBeleg: "Ohne Foto"
            }
        }
    }

    private var gefiltert: [Beleg] {
        alleBelege
            .filter { $0.jahr == jahr }
            .filter { beleg in
                switch filter {
                case .alle: true
                case .einnahmen: beleg.art == .einnahme
                case .ausgaben: beleg.art == .ausgabe
                case .ohneBeleg: beleg.belegbildDatei == nil
                }
            }
            .filter { beleg in
                guard !suchtext.isEmpty else { return true }
                let begriff = suchtext.lowercased()
                return beleg.bezeichnung.lowercased().contains(begriff)
                    || beleg.notiz.lowercased().contains(begriff)
                    || beleg.kategorie.bezeichnung.lowercased().contains(begriff)
            }
    }

    /// Gruppierung nach Monat - so findet man einen Beleg dort, wo man ihn sucht.
    private var nachMonat: [(monat: Int, belege: [Beleg])] {
        Dictionary(grouping: gefiltert, by: \.monat)
            .map { (monat: $0.key, belege: $0.value) }
            .sorted { $0.monat > $1.monat }
    }

    private var summeGefiltert: Decimal {
        gefiltert.map { $0.art == .einnahme ? $0.bruttoBetrag : -$0.bruttoBetrag }.summe
    }

    var body: some View {
        NavigationStack {
            List {
                if gefiltert.isEmpty {
                    ContentUnavailableView(
                        suchtext.isEmpty ? "Keine Belege" : "Keine Treffer",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(suchtext.isEmpty
                            ? "Für \(String(jahr)) ist noch nichts erfasst."
                            : "Für \"\(suchtext)\" wurde nichts gefunden.")
                    )
                } else {
                    ForEach(nachMonat, id: \.monat) { gruppe in
                        Section(monatsname(gruppe.monat)) {
                            ForEach(gruppe.belege) { beleg in
                                NavigationLink {
                                    BelegBearbeitenAnsicht(beleg: beleg, vorgabeJahr: jahr)
                                } label: {
                                    BelegZeile(beleg: beleg)
                                }
                            }
                            .onDelete { indizes in
                                löschen(indizes, aus: gruppe.belege)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Belege")
            .safeAreaInset(edge: .top) { filterleiste }
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { JahresWähler(jahr: $jahr) }
                ToolbarItem(placement: .topBarTrailing) {
                    BelegErfassenSchaltfläche(jahr: jahr)
                }
            }
        }
    }

    /// Eigenes Suchfeld statt `.searchable`.
    ///
    /// Das Systemsuchfeld lebt in der Navigationsleiste und blendet sich beim Scrollen
    /// ein und aus. Zusammen mit dieser angehefteten Leiste schoben sich beide beim
    /// Runterziehen übereinander - Titel, Suchfeld und Filter lagen dann sichtbar
    /// aufeinander. Ein Feld innerhalb der Leiste macht die Überlagerung unmöglich.
    private var filterleiste: some View {
        VStack(spacing: 10) {
            suchfeld

            Picker("Filter", selection: $filter) {
                ForEach(Filter.allCases) { Text($0.bezeichnung).tag($0) }
            }
            .pickerStyle(.segmented)

            HStack {
                Text(gefiltert.count == 1 ? "1 Beleg" : "\(gefiltert.count) Belege")
                Spacer()
                Text("Saldo \(Formatierung.euroMitVorzeichen(summeGefiltert))")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private var suchfeld: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField("Bezeichnung, Kategorie oder Notiz", text: $suchtext)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .focused($sucheAktiv)

            if !suchtext.isEmpty {
                Button {
                    suchtext = ""
                    sucheAktiv = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Suche löschen")
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
    }

    private func monatsname(_ monat: Int) -> String {
        let namen = ["Januar", "Februar", "März", "April", "Mai", "Juni",
                     "Juli", "August", "September", "Oktober", "November", "Dezember"]
        guard (1...12).contains(monat) else { return "" }
        return "\(namen[monat - 1]) \(String(jahr))"
    }

    private func löschen(_ indizes: IndexSet, aus belege: [Beleg]) {
        for index in indizes {
            let beleg = belege[index]
            // Das Belegfoto mit löschen, sonst bleiben Dateileichen im Archiv zurück.
            if let datei = beleg.belegbildDatei { Belegarchiv.löschen(datei) }
            kontext.delete(beleg)
        }
    }
}

#Preview {
    BelegeAnsicht(jahr: .constant(Calendar.kalender.component(.year, from: Date())))
        .modelContainer(Datenbank.vorschauContainer())
}
