import SwiftUI
import SwiftData

/// Alle Belege eines Jahres - suchbar, filterbar.
struct BelegeAnsicht: View {

    @Binding var jahr: Int
    @Environment(\.modelContext) private var kontext
    @Query(sort: \Beleg.datum, order: .reverse) private var alleBelege: [Beleg]

    /// Von außen gesetzt: die Liste "Zu erledigen" auf dem Stand springt mit einem
    /// gesetzten Filter hierher.
    @Binding var filter: Filter
    /// Setzt den Belegeinzug an der Wurzel der App in Gang.
    @Binding var aufnahme: Aufnahmeart?
    @State private var kategorie: Belegkategorie?
    @State private var suchtext = ""
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
                guard let kategorie else { return true }
                return beleg.kategorie == kategorie
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
                        if suchtext.isEmpty { erfassungsknöpfe }
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
        HStack(spacing: 10) {
            Text("Belege")
                .font(Stil.titel())
                .foregroundStyle(Stil.schrift)
            Spacer()
            Jahrespille(jahr: $jahr)
            neuknopf
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
            Monatsbalken(werte: monatswerte,
                         hervorgehoben: jüngsterMonat,
                         beschriftung: verlaufsbeschriftung)
        }
        .alsKarte()
        .padding(.horizontal, Stil.rand)
    }

    /// Der sichtbare Weg zu einem neuen Beleg.
    ///
    /// Vorher lagen Fotomediathek und Handeintrag ausschließlich auf dem langen Druck
    /// des Scanknopfs. Wer das nicht zufällig ausprobiert, findet sie nie - und für
    /// eine Rechnung, die als Bildschirmfoto in der Mediathek liegt, gibt es dann
    /// scheinbar keinen Weg in die App.
    private var neuknopf: some View {
        Menu {
            Button("Beleg scannen", systemImage: "doc.viewfinder") { aufnahme = .scannen }
            Button("Aus Fotomediathek", systemImage: "photo.on.rectangle") { aufnahme = .mediathek }
            Button("Von Hand eintragen", systemImage: "square.and.pencil") { aufnahme = .vonHand }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Stil.schrift)
                .frame(width: 38, height: 34)
                .alsGlas(Capsule())
        }
        .accessibilityLabel("Beleg hinzufügen")
    }

    /// Im leeren Jahr führen die beiden häufigsten Wege direkt unter dem Hinweis.
    private var erfassungsknöpfe: some View {
        VStack(spacing: 10) {
            Button("Beleg scannen") { aufnahme = .scannen }
                .buttonStyle(HauptknopfStil())
            Button("Aus Fotomediathek") { aufnahme = .mediathek }
                .buttonStyle(NebenknopfStil())
        }
        .padding(.horizontal, Stil.rand + 14)
        .padding(.top, 20)
    }

    /// Sagt über dem Diagramm, was die Balken zeigen - das hängt am Filter.
    private var verlaufsbeschriftung: String {
        switch filter {
        case .alle: "Saldo je Monat"
        case .einnahmen: "Einnahmen je Monat"
        case .ausgaben: "Ausgaben je Monat"
        case .ohneBetrag, .ohneBeleg: "\(filter.bezeichnung) je Monat"
        }
    }

    private var beischriftSaldo: String {
        let anzahl = gefiltert.count == 1 ? "1 Beleg" : "\(gefiltert.count) Belege"
        guard filter == .alle, ohneBetragAnzahl > 0 else { return anzahl }
        return "\(anzahl) · \(ohneBetragAnzahl) ohne Betrag"
    }

    private var pillenreihe: some View {
        VStack(alignment: .leading, spacing: 10) {
            Filterpillen(
                auswahl: Filter.allCases.map { (wert: $0, titel: $0.bezeichnung) },
                gewählt: $filter
            )
            kategoriewahl
        }
        .padding(.top, 18)
    }

    /// Einschränkung auf eine Kategorie.
    ///
    /// Als Menü und nicht als weitere Pillenreihe: es gibt über zwanzig Kategorien, und
    /// zwanzig Pillen nebeneinander sind keine Auswahl mehr, sondern ein Suchspiel. Die
    /// gewählte steht danach im Knopf, damit man nicht vergisst, dass gefiltert ist.
    private var kategoriewahl: some View {
        Menu {
            Button("Alle Kategorien") { kategorie = nil }
            Divider()
            ForEach(vorkommendeKategorien, id: \.self) { eintrag in
                Button {
                    kategorie = eintrag
                } label: {
                    Label("\(eintrag.bezeichnung) (\(anzahl(eintrag)))", systemImage: eintrag.symbol)
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 13, weight: .medium))
                Text(kategorie?.bezeichnung ?? "Alle Kategorien")
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(kategorie == nil ? Stil.schriftGedämpft : Stil.schrift)
            .padding(.horizontal, 15)
            .padding(.vertical, 9)
            .alsGlas(Capsule())
            .overlay(Capsule().strokeBorder(kategorie == nil ? .clear : Stil.akzent, lineWidth: 1.5))
        }
        .padding(.horizontal, Stil.rand)
    }

    /// Nur Kategorien, die im gewählten Jahr tatsächlich vorkommen.
    ///
    /// Eine Liste aller denkbaren Kategorien wäre vollständig und nutzlos - man filtert
    /// nach dem, was man hat.
    private var vorkommendeKategorien: [Belegkategorie] {
        let vorhanden = Set(desJahres.map(\.kategorie))
        return Belegkategorie.allCases.filter { vorhanden.contains($0) }
    }

    private func anzahl(_ eintrag: Belegkategorie) -> Int {
        desJahres.filter { $0.kategorie == eintrag }.count
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .alsGlas(radius: Stil.radiusKachel)
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
            .alsGlas()
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
    BelegeAnsicht(
        jahr: .constant(Calendar.kalender.component(.year, from: Date())),
        filter: .constant(.alle),
        aufnahme: .constant(nil)
    )
    .modelContainer(Datenbank.vorschauContainer())
}
