import SwiftUI
import SwiftData

/// Alle Belege eines Jahres - suchbar, filterbar, loeschbar.
struct BelegeAnsicht: View {

    @Binding var jahr: Int
    @Environment(\.modelContext) private var kontext
    @Query(sort: \Beleg.datum, order: .reverse) private var alleBelege: [Beleg]

    @State private var suchtext = ""
    @State private var filter: Filter = .alle

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
                            ? "Fuer \(String(jahr)) ist noch nichts erfasst."
                            : "Fuer \"\(suchtext)\" wurde nichts gefunden.")
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
                                loeschen(indizes, aus: gruppe.belege)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $suchtext, prompt: "Bezeichnung, Kategorie oder Notiz")
            .navigationTitle("Belege")
            .safeAreaInset(edge: .top) { filterleiste }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { JahresWaehler(jahr: $jahr) }
                ToolbarItem(placement: .topBarTrailing) {
                    BelegErfassenSchaltflaeche(jahr: jahr)
                }
            }
        }
    }

    private var filterleiste: some View {
        VStack(spacing: 8) {
            Picker("Filter", selection: $filter) {
                ForEach(Filter.allCases) { Text($0.bezeichnung).tag($0) }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("\(gefiltert.count) Belege")
                Spacer()
                Text("Saldo \(Formatierung.euroMitVorzeichen(summeGefiltert))")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private func monatsname(_ monat: Int) -> String {
        let namen = ["Januar", "Februar", "Maerz", "April", "Mai", "Juni",
                     "Juli", "August", "September", "Oktober", "November", "Dezember"]
        guard (1...12).contains(monat) else { return "" }
        return "\(namen[monat - 1]) \(String(jahr))"
    }

    private func loeschen(_ indizes: IndexSet, aus belege: [Beleg]) {
        for index in indizes {
            let beleg = belege[index]
            // Das Belegfoto mit loeschen, sonst bleiben Dateileichen im Archiv zurueck.
            if let datei = beleg.belegbildDatei { Belegarchiv.loeschen(datei) }
            kontext.delete(beleg)
        }
    }
}

#Preview {
    BelegeAnsicht(jahr: .constant(Calendar.kalender.component(.year, from: Date())))
        .modelContainer(Datenbank.vorschauContainer())
}
