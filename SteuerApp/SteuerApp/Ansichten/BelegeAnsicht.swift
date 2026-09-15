import SwiftUI
import SwiftData

/// Alle Belege eines Jahres - suchbar, filterbar.
struct BelegeAnsicht: View {

    @Binding var jahr: Int
    @Environment(\.modelContext) private var kontext
    @Query(sort: \Beleg.datum, order: .reverse) private var alleBelege: [Beleg]

    @State private var suchtext = ""
    @State private var filter: Filter = .alle
    @FocusState private var sucheAktiv: Bool
    @State private var zuLöschen: Beleg?

    enum Filter: String, CaseIterable, Identifiable {
        case alle, einnahmen, ausgaben, ohneBetrag, ohneBeleg

        var id: String { rawValue }

        var bezeichnung: String {
            switch self {
            case .alle: "Alle"
            case .einnahmen: "Einnahmen"
            case .ausgaben: "Ausgaben"
            case .ohneBetrag: "Ohne Betrag"
            case .ohneBeleg: "Ohne Foto"
            }
        }
    }

    // MARK: - Abgeleitete Werte

    private var desJahres: [Beleg] { alleBelege.filter { $0.jahr == jahr } }

    private var gefiltert: [Beleg] {
        desJahres
            .filter { beleg in
                switch filter {
                case .alle: true
                case .einnahmen: beleg.art == .einnahme
                case .ausgaben: beleg.art == .ausgabe
                case .ohneBetrag: beleg.bruttoBetrag == 0
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

    /// Ein Wert je Monat für das Balkendiagramm - der Saldo des Monats.
    private var monatswerte: [Decimal] {
        var werte = [Decimal](repeating: 0, count: 12)
        for beleg in gefiltert where (1...12).contains(beleg.monat) {
            werte[beleg.monat - 1] += beleg.art == .einnahme ? beleg.bruttoBetrag
                                                             : -beleg.bruttoBetrag
        }
        return werte
    }

    private var jüngsterMonat: Int? {
        gefiltert.map(\.monat).max().map { $0 - 1 }
    }

    private var ohneBetragAnzahl: Int { desJahres.filter { $0.bruttoBetrag == 0 }.count }

    // MARK: - Aufbau

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    kopfzeile
                    saldokarte
                    pillenreihe
                    suchfeld

                    if gefiltert.isEmpty {
                        LeerHinweis(
                            symbol: suchtext.isEmpty ? "tray" : "magnifyingglass",
                            titel: suchtext.isEmpty ? "Keine Belege" : "Keine Treffer",
                            text: suchtext.isEmpty
                                ? "Für \(String(jahr)) ist noch nichts erfasst."
                                : "Für „\(suchtext)\" wurde nichts gefunden."
                        )
                    } else {
                        ForEach(nachMonat, id: \.monat) { gruppe in
                            monatsgruppe(gruppe)
                        }
                    }
                }
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .aufGrund()
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog(
                "Beleg löschen?",
                isPresented: Binding(get: { zuLöschen != nil },
                                     set: { if !$0 { zuLöschen = nil } }),
                titleVisibility: .visible
            ) {
                Button("Löschen", role: .destructive) { löschenBestätigt() }
                Button("Abbrechen", role: .cancel) { zuLöschen = nil }
            } message: {
                Text("Das Belegfoto wird mit gelöscht. Das lässt sich nicht rückgängig machen.")
            }
        }
    }

    // MARK: - Bausteine

    private var kopfzeile: some View {
        HStack {
            Text("Belege")
                .font(Stil.titel())
                .foregroundStyle(Stil.schrift)
            Spacer()
            Jahrespille(jahr: $jahr)
            BelegErfassenSchaltfläche(jahr: jahr)
        }
        .padding(.horizontal, Stil.rand)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    private var saldokarte: some View {
        VStack(alignment: .leading, spacing: 18) {
            Betragskopf(
                beschriftung: filter == .alle ? "Saldo \(String(jahr))" : filter.bezeichnung,
                betrag: summeGefiltert,
                beischrift: beischriftSaldo
            )
            Monatsbalken(werte: monatswerte, hervorgehoben: jüngsterMonat)
        }
        .alsKarte()
        .padding(.horizontal, Stil.rand)
    }

    private var beischriftSaldo: String {
        let anzahl = gefiltert.count == 1 ? "1 Beleg" : "\(gefiltert.count) Belege"
        guard filter == .alle, ohneBetragAnzahl > 0 else { return anzahl }
        return "\(anzahl) · \(ohneBetragAnzahl) ohne Betrag"
    }

    private var pillenreihe: some View {
        Filterpillen(
            auswahl: Filter.allCases.map { (wert: $0, titel: $0.bezeichnung) },
            gewählt: $filter
        )
        .padding(.top, 18)
    }

    private var suchfeld: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Stil.schriftGedämpft)
                .accessibilityHidden(true)

            TextField("Bezeichnung, Kategorie oder Notiz", text: $suchtext)
                .font(.system(size: 15))
                .foregroundStyle(Stil.schrift)
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
                        .foregroundStyle(Stil.schriftGedämpft)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Suche löschen")
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(Stil.fläche, in: RoundedRectangle(cornerRadius: Stil.radiusKachel,
                                                      style: .continuous))
        .padding(.horizontal, Stil.rand)
        .padding(.top, 14)
    }

    private func monatsgruppe(_ gruppe: (monat: Int, belege: [Beleg])) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Abschnittskopf(
                text: monatsname(gruppe.monat),
                nachsatz: Formatierung.euroMitVorzeichen(saldo(gruppe.belege), mitCent: false)
            )
            .padding(.horizontal, Stil.rand + 4)

            VStack(spacing: 0) {
                ForEach(Array(gruppe.belege.enumerated()), id: \.element.id) { stelle, beleg in
                    NavigationLink {
                        BelegBearbeitenAnsicht(beleg: beleg, vorgabeJahr: jahr)
                    } label: {
                        BelegZeile(beleg: beleg)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Beleg löschen", systemImage: "trash", role: .destructive) {
                            zuLöschen = beleg
                        }
                    }

                    if stelle < gruppe.belege.count - 1 {
                        Trennzeile(einzug: Stil.symbolgröße + 13)
                    }
                }
            }
            .padding(.horizontal, 15)
            .background(Stil.fläche, in: RoundedRectangle(cornerRadius: Stil.radiusKarte,
                                                          style: .continuous))
            .padding(.horizontal, Stil.rand)
        }
    }

    // MARK: - Verhalten

    private func saldo(_ belege: [Beleg]) -> Decimal {
        belege.map { $0.art == .einnahme ? $0.bruttoBetrag : -$0.bruttoBetrag }.summe
    }

    private func monatsname(_ monat: Int) -> String {
        let namen = ["Januar", "Februar", "März", "April", "Mai", "Juni",
                     "Juli", "August", "September", "Oktober", "November", "Dezember"]
        guard (1...12).contains(monat) else { return "" }
        return "\(namen[monat - 1]) \(String(jahr))"
    }

    /// Löschen bewusst nur über Nachfrage.
    ///
    /// Ein Wisch reicht bei einem aufbewahrungspflichtigen Beleg nicht - versehentlich
    /// gelöscht ist das Foto endgültig weg. Deshalb liegt das Löschen im Kontextmenü
    /// und braucht eine zweite Bestätigung.
    private func löschenBestätigt() {
        guard let beleg = zuLöschen else { return }
        if let datei = beleg.belegbildDatei { Belegarchiv.löschen(datei) }
        kontext.delete(beleg)
        zuLöschen = nil
    }
}

#Preview {
    BelegeAnsicht(jahr: .constant(Calendar.kalender.component(.year, from: Date())))
        .modelContainer(Datenbank.vorschauContainer())
}
