import SwiftUI
import SwiftData

/// Der erste Bildschirm: Wo stehe ich, und was ist noch zu tun?
///
/// Die Reihenfolge ist bewusst gedreht. Vorher stand der Gewinn oben und die Steuer
/// darunter - das ist die Reihenfolge der Buchhaltung, nicht die der Frage, die man
/// sich stellt. Wer die App öffnet, will wissen, wie viel Geld ihm nicht gehört.
/// Also steht die Rücklage oben, der Gewinn darunter als Begründung.
///
/// Neu ist der Abschnitt "Zu erledigen". Ein Beleg ohne Betrag war bisher unsichtbar,
/// solange man nicht danach filterte - jetzt steht er hier, mit einem Tipp dorthin.
struct StandAnsicht: View {

    @Binding var jahr: Int
    @Binding var bereich: SchwebendeLeiste.Bereich
    @Binding var belegfilter: BelegeAnsicht.Filter

    @Query(sort: \Beleg.datum, order: .reverse) private var belege: [Beleg]
    @Query private var profile: [Steuerprofil]
    @Query private var alleJahresangaben: [Jahresangaben]
    @Query private var wirtschaftsgüter: [Wirtschaftsgut]

    private var profil: Steuerprofil { profile.first ?? Steuerprofil() }
    private var angaben: Jahresangaben {
        alleJahresangaben.first { $0.jahr == jahr } ?? Jahresangaben(jahr: jahr)
    }
    private var steuerjahr: Steuerjahr { Steuerjahr.fuer(jahr) }

    private func euerFuer(_ welchesJahr: Int) -> EinnahmenÜberschussRechnung.Ergebnis {
        EinnahmenÜberschussRechnung.berechnen(
            belege: belege, wirtschaftsgüter: wirtschaftsgüter,
            jahr: welchesJahr, kleinunternehmer: profil.kleinunternehmer
        )
    }

    private var euer: EinnahmenÜberschussRechnung.Ergebnis { euerFuer(jahr) }

    private var schätzung: Steuerschaetzung.Ergebnis {
        Steuerschaetzung.berechnen(Steuerschaetzung.Eingaben(
            profil: profil, jahresangaben: angaben,
            gewinn: euer.gewinn, steuerjahr: steuerjahr
        ))
    }

    /// Wie sich der Gewinn gegenüber dem Vorjahr entwickelt hat.
    ///
    /// Nur wenn im Vorjahr überhaupt etwas erfasst ist - sonst wäre die Zahl entweder
    /// unendlich oder schlicht erfunden.
    private var veränderungZumVorjahr: Double? {
        let vorher = euerFuer(jahr - 1).gewinn
        guard vorher > 0 else { return nil }
        return (euer.gewinn - vorher).alsDouble / vorher.alsDouble
    }

    private var desJahres: [Beleg] { belege.filter { $0.jahr == jahr } }

    private var monatswerte: [Decimal] {
        var werte = [Decimal](repeating: 0, count: 12)
        for beleg in desJahres where (1...12).contains(beleg.monat) {
            werte[beleg.monat - 1] += beleg.art == .einnahme ? beleg.bruttoBetrag
                                                             : -beleg.bruttoBetrag
        }
        return werte
    }

    private var letzteBelege: [Beleg] { Array(desJahres.prefix(4)) }

    // MARK: - Zu erledigen

    /// Ein offener Punkt: was fehlt, wie viele, und wohin der Tipp führt.
    private struct Aufgabe: Identifiable {
        let id: String
        let text: String
        let symbol: String
        let farbe: Color
        let ziel: BelegeAnsicht.Filter?
    }

    private var aufgaben: [Aufgabe] {
        var liste: [Aufgabe] = []

        let ohneBetrag = desJahres.filter { $0.bruttoBetrag == 0 }.count
        if ohneBetrag > 0 {
            liste.append(Aufgabe(
                id: "betrag",
                text: ohneBetrag == 1
                    ? "Ein Beleg hat noch keinen Betrag"
                    : "\(ohneBetrag) Belege haben noch keinen Betrag",
                symbol: "eurosign.circle",
                farbe: Stil.warnung,
                ziel: .ohneBetrag
            ))
        }

        let ohneFoto = desJahres.filter { $0.belegbildDatei == nil }.count
        if ohneFoto > 0 {
            liste.append(Aufgabe(
                id: "foto",
                text: ohneFoto == 1
                    ? "Ein Beleg hat kein Foto"
                    : "\(ohneFoto) Belege haben kein Foto",
                symbol: "camera",
                farbe: Stil.schriftGedämpft,
                ziel: .ohneBeleg
            ))
        }

        // Ohne eingetragene Vorauszahlungen ist die Rücklage oben systematisch zu hoch.
        if schätzung.geleisteteVorauszahlungen == 0 && euer.gewinn > 0 {
            liste.append(Aufgabe(
                id: "vorauszahlung",
                text: "Vorauszahlungen sind nicht eingetragen",
                symbol: "calendar",
                farbe: Stil.schriftGedämpft,
                ziel: nil
            ))
        }

        return liste
    }

    // MARK: - Aufbau

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    kopfzeile

                    if euer.anzahlBelege == 0 {
                        leererZustand
                    } else {
                        rücklagekarte
                        if !aufgaben.isEmpty { aufgabenliste }
                        gewinnkarte
                        if !letzteBelege.isEmpty { letzteBewegungen }
                    }

                    steuerkarte

                    hinweisWennJahrUngeprüft
                }
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .aufGrund()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Bausteine

    /// Der Weg zu Schätzung und Auswertung.
    ///
    /// Steuer hat den Platz in der Leiste an die Rechnungen abgegeben und steht dafür
    /// hier. Der Tausch folgt der Häufigkeit: Rechnungen schreibt man laufend, die
    /// Schätzung sieht man sich ein paarmal im Jahr an - und wenn, dann von hier aus,
    /// wo die Zahl schon steht.
    private var steuerkarte: some View {
        NavigationLink {
            SteuerAnsicht(jahr: $jahr, eingebettet: true)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Steuer")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Stil.schrift)
                    Text("Schätzung und Auswertung für \(String(jahr))")
                        .font(.system(size: 13))
                        .foregroundStyle(Stil.schriftGedämpft)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Stil.schriftLeise)
            }
            .alsKarte()
            .padding(.horizontal, Stil.rand)
            .padding(.top, 12)
        }
        .buttonStyle(.plain)
    }

    private var kopfzeile: some View {
        HStack {
            Text("Stand")
                .font(Stil.titel())
                .foregroundStyle(Stil.schrift)
            Spacer()
            Jahrespille(jahr: $jahr)
        }
        .padding(.horizontal, Stil.rand)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    /// Die eine Zahl, wegen der es diese App gibt.
    private var rücklagekarte: some View {
        VStack(alignment: .leading, spacing: 14) {
            Betragskopf(
                beschriftung: schätzung.istErstattung
                    ? "Voraussichtliche Erstattung"
                    : "Dafür zurücklegen",
                betrag: abs(schätzung.offenerBetrag),
                mitVorzeichen: false,
                beischrift: begründung
            )

            if euer.gewinn > 0 {
                balkenAnteil(min(schätzung.ruecklagenquote, 1))
                Text("\(Formatierung.prozent(schätzung.ruecklagenquote, nachkommastellen: 0)) deines Gewinns von \(Formatierung.euro(euer.gewinn, mitCent: false))")
                    .font(.system(size: 12))
                    .foregroundStyle(Stil.schriftLeise)
            }
        }
        .alsKarte()
        .padding(.horizontal, Stil.rand)
    }

    private func balkenAnteil(_ anteil: Double) -> some View {
        GeometryReader { fläche in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                Capsule()
                    .fill(schätzung.istErstattung ? Stil.haben : Stil.warnung)
                    .frame(width: max(fläche.size.width * anteil, 4))
            }
        }
        .frame(height: 7)
    }

    private var begründung: String {
        let vorauszahlung = schätzung.geleisteteVorauszahlungen
        guard vorauszahlung > 0 else {
            return "Geschätzt aus \(euer.anzahlBelege) Belegen"
        }
        return "Nach Abzug von \(Formatierung.euro(vorauszahlung, mitCent: false)) Vorauszahlung"
    }

    /// Was noch offen ist - mit einem Tipp dorthin, wo man es erledigt.
    private var aufgabenliste: some View {
        VStack(alignment: .leading, spacing: 0) {
            Abschnittskopf(text: "Zu erledigen")
                .padding(.horizontal, Stil.rand + 4)

            VStack(spacing: 0) {
                ForEach(Array(aufgaben.enumerated()), id: \.element.id) { stelle, aufgabe in
                    aufgabenzeile(aufgabe)
                    if stelle < aufgaben.count - 1 {
                        Trennzeile(einzug: 34)
                    }
                }
            }
            .padding(.horizontal, 15)
            .alsGlas()
            .padding(.horizontal, Stil.rand)
        }
    }

    private func aufgabenzeile(_ aufgabe: Aufgabe) -> some View {
        Button {
            guard let ziel = aufgabe.ziel else {
                bereich = .mehr
                return
            }
            belegfilter = ziel
            withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                bereich = .belege
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: aufgabe.symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(aufgabe.farbe)
                    .frame(width: 22)

                Text(aufgabe.text)
                    .font(.system(size: 15))
                    .foregroundStyle(Stil.schrift)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Stil.schriftLeise)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var gewinnkarte: some View {
        VStack(alignment: .leading, spacing: 16) {
            Betragskopf(
                beschriftung: "Gewinn \(String(jahr))",
                betrag: euer.gewinn,
                mitVorzeichen: false,
                veränderung: veränderungZumVorjahr,
                beischrift: "\(Formatierung.euro(euer.summeEinnahmen, mitCent: false)) ein · \(Formatierung.euro(euer.summeAusgaben, mitCent: false)) aus",
                hochzählen: false
            )
            Monatsbalken(werte: monatswerte,
                         hervorgehoben: desJahres.map(\.monat).max().map { $0 - 1 },
                         beschriftung: "Gewinn je Monat")
        }
        .alsKarte()
        .padding(.horizontal, Stil.rand)
        .padding(.top, 12)
    }

    private var letzteBewegungen: some View {
        VStack(alignment: .leading, spacing: 0) {
            Abschnittskopf(text: "Zuletzt erfasst")
                .padding(.horizontal, Stil.rand + 4)

            VStack(spacing: 0) {
                ForEach(Array(letzteBelege.enumerated()), id: \.element.id) { stelle, beleg in
                    NavigationLink {
                        BelegBearbeitenAnsicht(beleg: beleg, vorgabeJahr: jahr)
                    } label: {
                        BelegZeile(beleg: beleg)
                    }
                    .buttonStyle(.plain)

                    if stelle < letzteBelege.count - 1 {
                        Trennzeile(einzug: Stil.symbolgröße + 13)
                    }
                }
            }
            .padding(.horizontal, 15)
            .alsGlas()
            .padding(.horizontal, Stil.rand)
        }
    }

    private var leererZustand: some View {
        VStack(spacing: 14) {
            LeerHinweis(
                symbol: "doc.text.viewfinder",
                titel: "Noch nichts erfasst für \(String(jahr))",
                text: "Tippe unten auf das Scannersymbol und fotografiere einen Beleg. Händler, Betrag, Datum und Steuersatz werden vorgeschlagen – auch bei einem ganzen Stapel. Eigene Rechnungen an Kunden schreibst du unten unter „Rechnungen“."
            )
        }
        .alsKarte(polster: 0)
        .padding(.horizontal, Stil.rand)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var hinweisWennJahrUngeprüft: some View {
        if !steuerjahr.amtlichGeprüft {
            Hinweiszeile(
                text: "Die Tarifwerte für \(String(steuerjahr.jahr)) sind noch nicht gegen die amtliche Tabelle geprüft.",
                symbol: "exclamationmark.triangle",
                farbe: Stil.warnung
            )
            .alsKarte(polster: 14)
            .padding(.horizontal, Stil.rand)
            .padding(.top, 12)
        }
    }
}

/// Eine Belegzeile, wie sie auf dem Stand und in der Belegliste erscheint.
struct BelegZeile: View {

    let beleg: Beleg

    var body: some View {
        Buchungszeile(
            kategorie: beleg.kategorie,
            bezeichnung: beleg.bezeichnung.isEmpty ? beleg.kategorie.bezeichnung
                                                   : beleg.bezeichnung,
            beischrift: "\(Formatierung.datum(beleg.datum)) · \(beleg.kategorie.bezeichnung)",
            betrag: beleg.bruttoBetrag,
            istEinnahme: beleg.art == .einnahme,
            mitBild: beleg.belegbildDatei != nil,
            unvollständig: beleg.bruttoBetrag == 0
        )
    }
}
