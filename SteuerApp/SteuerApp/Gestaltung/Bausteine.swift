import SwiftUI

// MARK: - Zahlen

/// Ein Betrag, der sich beim Ändern hochzählt, statt zu springen.
///
/// SwiftUI interpoliert nur, was `Animatable` ist - ein `Decimal` in einem `Text` gehört
/// nicht dazu und würde ohne diesen Umweg schlagartig umspringen. Über `animatableData`
/// bekommt die Ansicht bei jedem Einzelbild einen Zwischenwert und zeichnet sich neu.
struct ZählenderBetrag: View, Animatable {

    var wert: Double
    var schrift: Font = Stil.betrag()
    var farbe: Color = Stil.schrift
    var mitVorzeichen = false

    var animatableData: Double {
        get { wert }
        set { wert = newValue }
    }

    var body: some View {
        let betrag = Decimal(wert)
        Text(mitVorzeichen
             ? Formatierung.euroMitVorzeichen(betrag)
             : Formatierung.euro(betrag))
            .font(schrift)
            .foregroundStyle(farbe)
    }
}

// MARK: - Kopfbereich

/// Die große Betragskarte oben auf einem Bildschirm.
///
/// Eine Zahl, die man aus zwei Metern liest, darunter in einer Zeile, woraus sie sich
/// ergibt. Alles Weitere gehört in die Liste darunter, nicht hierher.
struct Betragskopf: View {

    let beschriftung: String
    let betrag: Decimal
    var mitVorzeichen = true
    var veränderung: Double?
    var beischrift: String?
    var hochzählen = true

    @State private var angezeigt: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(beschriftung)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Stil.schriftGedämpft)

            ZählenderBetrag(
                wert: angezeigt,
                schrift: Stil.hauptzahl(),
                farbe: Stil.schrift,
                mitVorzeichen: mitVorzeichen
            )
            .lineLimit(1)
            .minimumScaleFactor(0.5)

            HStack(spacing: 10) {
                if let veränderung {
                    Veränderungsmarke(anteil: veränderung)
                }
                if let beischrift {
                    Text(beischrift)
                        .font(.system(size: 13))
                        .foregroundStyle(Stil.schriftGedämpft)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: betrag) {
            guard hochzählen else { angezeigt = betrag.alsDouble; return }
            withAnimation(.easeOut(duration: 0.7)) { angezeigt = betrag.alsDouble }
        }
    }
}

/// Pfeil mit Prozentwert - wie viel mehr oder weniger als im Zeitraum davor.
struct Veränderungsmarke: View {

    let anteil: Double

    var body: some View {
        let steigt = anteil >= 0
        HStack(spacing: 3) {
            Image(systemName: steigt ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .bold))
            Text(Formatierung.prozent(abs(anteil)))
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(steigt ? Stil.haben : Stil.schriftGedämpft)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            (steigt ? Stil.haben : Stil.schriftGedämpft).opacity(0.14),
            in: Capsule()
        )
    }
}

// MARK: - Diagramm

/// Ein Balken je Monat. Der hervorgehobene Monat trägt die Akzentfarbe.
struct Monatsbalken: View {

    /// Zwölf Werte, Januar bis Dezember.
    let werte: [Decimal]
    var hervorgehoben: Int?
    var höhe: CGFloat = 78

    private let kürzel = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]

    private var größter: Double {
        max(werte.map { abs($0.alsDouble) }.max() ?? 0, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(Array(werte.prefix(12).enumerated()), id: \.offset) { monat, wert in
                VStack(spacing: 6) {
                    // Immer mindestens zwei Punkte hoch, damit leere Monate sichtbar
                    // bleiben - ein unsichtbarer Balken sieht aus wie ein Fehler.
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(monat == hervorgehoben ? Stil.akzent : Stil.flächeHoch)
                        .frame(height: max(höhe * CGFloat(abs(wert.alsDouble) / größter), 2))

                    Text(kürzel[monat])
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(monat == hervorgehoben
                                         ? Stil.schrift : Stil.schriftLeise)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: höhe + 18, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

// MARK: - Filter

/// Waagerecht scrollende Filterpillen.
struct Filterpillen<Wert: Hashable>: View {

    let auswahl: [(wert: Wert, titel: String)]
    @Binding var gewählt: Wert

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(auswahl, id: \.wert) { eintrag in
                    let aktiv = eintrag.wert == gewählt
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { gewählt = eintrag.wert }
                    } label: {
                        Text(eintrag.titel)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(aktiv ? Stil.grund : Stil.schriftGedämpft)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(aktiv ? Stil.schrift : Stil.flächeHoch, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Stil.rand)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}

// MARK: - Zeilen

/// Das runde Farbsymbol einer Kategorie.
struct Kategoriesymbol: View {

    let kategorie: Belegkategorie
    var größe: CGFloat = Stil.symbolgröße

    var body: some View {
        let ton = Stil.farbe(fuer: kategorie)
        ZStack {
            Circle().fill(ton.opacity(0.18))
            Image(systemName: kategorie.symbol)
                .font(.system(size: größe * 0.42, weight: .medium))
                .foregroundStyle(ton)
        }
        .frame(width: größe, height: größe)
    }
}

/// Eine Buchung in der Liste: Symbol, Bezeichnung, Beischrift, Betrag.
struct Buchungszeile: View {

    let kategorie: Belegkategorie
    let bezeichnung: String
    let beischrift: String
    let betrag: Decimal
    var istEinnahme = false
    var mitBild = false
    var unvollständig = false

    var body: some View {
        HStack(spacing: 13) {
            Kategoriesymbol(kategorie: kategorie)

            VStack(alignment: .leading, spacing: 2) {
                Text(bezeichnung.isEmpty ? "Ohne Bezeichnung" : bezeichnung)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(bezeichnung.isEmpty ? Stil.schriftGedämpft : Stil.schrift)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(beischrift)
                        .font(.system(size: 13))
                        .foregroundStyle(Stil.schriftGedämpft)
                        .lineLimit(1)
                    if mitBild {
                        Image(systemName: "paperclip")
                            .font(.system(size: 10))
                            .foregroundStyle(Stil.schriftLeise)
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(istEinnahme
                     ? Formatierung.euroMitVorzeichen(betrag)
                     : Formatierung.euro(betrag))
                    .font(Stil.betrag())
                    .foregroundStyle(Stil.betragsfarbe(istEinnahme: istEinnahme))

                if unvollständig {
                    Text("Betrag fehlt")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Stil.warnung)
                }
            }
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

/// Beschriftung links, Wert rechts - für alle Aufstellungen und Rechenwege.
struct Postenzeile: View {

    let bezeichnung: String
    let betrag: Decimal
    var beischrift: String?
    var gewichtet = false
    var mitVorzeichen = false
    var eingerückt = false
    var farbe: Color?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(bezeichnung)
                    .font(.system(size: 15, weight: gewichtet ? .semibold : .regular))
                    .foregroundStyle(Stil.schrift)
                if let beischrift {
                    Text(beischrift)
                        .font(.system(size: 12))
                        .foregroundStyle(Stil.schriftGedämpft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.leading, eingerückt ? 14 : 0)

            Spacer(minLength: 8)

            Text(mitVorzeichen
                 ? Formatierung.euroMitVorzeichen(betrag)
                 : Formatierung.euro(betrag))
                .font(Stil.betrag(15, fett: gewichtet))
                .foregroundStyle(farbe ?? Stil.schrift)
        }
        .padding(.vertical, 9)
    }
}

/// Trennlinie innerhalb einer Karte, links um die Symbolbreite eingerückt.
struct Trennzeile: View {
    var einzug: CGFloat = 0
    var body: some View {
        Rectangle()
            .fill(Stil.trenner)
            .frame(height: 0.5)
            .padding(.leading, einzug)
    }
}

/// Abschnittsmarke über einer Gruppe von Zeilen.
struct Abschnittskopf: View {

    let text: String
    var nachsatz: String?

    var body: some View {
        HStack {
            Text(text.uppercased())
                .font(Stil.abschnitt)
                .tracking(0.8)
                .foregroundStyle(Stil.schriftGedämpft)
            Spacer()
            if let nachsatz {
                Text(nachsatz)
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Stil.schriftLeise)
            }
        }
        .padding(.top, 22)
        .padding(.bottom, 8)
    }
}

// MARK: - Kacheln und Marken

/// Kleine Kennzahl neben einer anderen - zwei oder drei nebeneinander.
struct Kachel: View {

    let beschriftung: String
    let wert: String
    var beischrift: String?
    var farbe: Color = Stil.schrift
    var symbol: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(farbe)
                }
                Text(beschriftung)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Stil.schriftGedämpft)
                    .lineLimit(1)
            }

            Text(wert)
                .font(.system(size: 21, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(farbe)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let beischrift {
                Text(beischrift)
                    .font(.system(size: 11))
                    .foregroundStyle(Stil.schriftLeise)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(Stil.fläche, in: RoundedRectangle(cornerRadius: Stil.radiusKachel,
                                                      style: .continuous))
    }
}

/// Kleine Statusmarke - offen, bezahlt, storniert, überfällig.
struct Statusmarke: View {

    let text: String
    var farbe: Color = Stil.schriftGedämpft

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(farbe)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(farbe.opacity(0.16), in: Capsule())
    }
}

/// Hinweiszeile in einer Karte - erklärt etwas, ohne zu stören.
struct Hinweiszeile: View {

    let text: String
    var symbol = "info.circle"
    var farbe: Color = Stil.schriftGedämpft

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(farbe)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(farbe)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Leerer Zustand.
struct LeerHinweis: View {

    let symbol: String
    let titel: String
    let text: String

    var body: some View {
        VStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Stil.schriftLeise)
            Text(titel)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Stil.schrift)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Stil.schriftGedämpft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .padding(.horizontal, 24)
    }
}

// MARK: - Knöpfe

/// Der Hauptknopf - breit, gefüllt, unten am Bildschirm.
struct HauptknopfStil: ButtonStyle {

    var farbe: Color = Stil.akzent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(farbe, in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Zweitrangiger Knopf - gefüllt, aber ohne Farbe.
struct NebenknopfStil: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Stil.schrift)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Stil.flächeHoch, in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Runder Knopf für die Kopfzeile.
struct RundknopfStil: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Stil.schrift)
            .frame(width: 38, height: 38)
            .background(Stil.flächeHoch, in: Circle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Die Jahresauswahl als Pille in der Kopfzeile.
struct Jahrespille: View {

    @Binding var jahr: Int

    var body: some View {
        Menu {
            Picker("Jahr", selection: $jahr) {
                ForEach(Steuerjahr.alle.reversed()) { steuerjahr in
                    Text(String(steuerjahr.jahr)).tag(steuerjahr.jahr)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(String(jahr))
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(Stil.schrift)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(Stil.flächeHoch, in: Capsule())
        }
    }
}
