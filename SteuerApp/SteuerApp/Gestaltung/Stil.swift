import SwiftUI

/// Farben, Materialien und Maße der Oberfläche - an einer Stelle festgelegt.
///
/// Die Gestaltung folgt Apples Liquid Glass: ein farbiger Verlauf trägt den Bildschirm,
/// darüber schweben Flächen aus durchscheinendem Glas mit einer hellen Kante am Rand.
/// Nichts ist deckend - der Hintergrund scheint überall durch und hält die Ebenen
/// zusammen.
///
/// - Note: Gebaut mit `Material`, nicht mit `glassEffect(_:)`. Die echten Schnittstellen
///   gibt es erst ab dem iOS-26-SDK; mit Materialien läuft dasselbe Bild ab iOS 17.
///   Der Umstieg beträfe nur diese Datei und `Bausteine.swift`.
enum Stil {

    // MARK: - Grundfarben

    /// Der tiefste Grund, auf dem der Verlauf liegt.
    static let grund = farbe(dunkel: 0x07060C, hell: 0xF4F3FA)

    /// Wird nur noch dort gebraucht, wo eine deckende Fläche nötig ist - etwa hinter
    /// einer Systemliste, die kein Material durchlässt.
    static let fläche = farbe(dunkel: 0x141320, hell: 0xFFFFFF)

    /// Abgesetzt innerhalb einer Glasfläche.
    static let flächeHoch = farbe(dunkel: 0x232235, hell: 0xE9E8F4)

    /// Haarlinie zwischen zwei Zeilen derselben Karte.
    static let trenner = farbe(dunkel: 0x2C2B40, hell: 0xE2E1EE)

    // MARK: - Schrift

    static let schrift = farbe(dunkel: 0xFFFFFF, hell: 0x0B0A14)
    static let schriftGedämpft = farbe(dunkel: 0x9D9BB4, hell: 0x66647A)
    static let schriftLeise = farbe(dunkel: 0x6A6883, hell: 0x9795AB)

    // MARK: - Bedeutungsfarben

    /// Bedienelemente, ausgewählte Chips, der Hauptknopf.
    static let akzent = farbe(dunkel: 0x7A6BFF, hell: 0x5443E0)

    /// Geld, das hereinkommt.
    static let haben = farbe(dunkel: 0x3DDC84, hell: 0x158A45)

    /// Etwas fehlt oder läuft ab - kein Fehler, aber zu erledigen.
    static let warnung = farbe(dunkel: 0xFFC94D, hell: 0xA97400)

    /// Fehler, Storno, überfällig.
    static let gefahr = farbe(dunkel: 0xFF6B6B, hell: 0xCE2F2F)

    // MARK: - Glas

    /// Das Material der schwebenden Flächen.
    static let glas: Material = .ultraThinMaterial

    /// Ein kräftigeres Glas für Leisten, die über Inhalt liegen und ihn verdecken sollen.
    static let glasDicht: Material = .regularMaterial

    /// Die Lichtkante am Rand einer Glasfläche.
    ///
    /// Oben links hell, unten rechts fast weg - das ist es, was eine Fläche als Glas
    /// lesbar macht und nicht als graues Rechteck. Ohne diese Kante verschwimmt jede
    /// Karte mit ihrem Hintergrund.
    static var kante: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.30), Color.white.opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Schwächere Kante für kleine Elemente - Pillen, Knöpfe, Symbolkreise.
    static var kanteFein: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Maße

    /// Radius einer großen Karte.
    static let radiusKarte: CGFloat = 26

    /// Radius einer kleinen Kachel oder eines Eingabefelds.
    static let radiusKachel: CGFloat = 20

    /// Seitenrand der Blätter.
    static let rand: CGFloat = 18

    /// Durchmesser des runden Kategoriesymbols in einer Buchungszeile.
    static let symbolgröße: CGFloat = 42

    /// Wie hoch die schwebende Leiste am unteren Rand baut - so viel Luft braucht der
    /// Inhalt darunter, damit nichts dahinter verschwindet.
    static let leistenhöhe: CGFloat = 96

    /// Radius eines Elements, das mit `polster` Abstand in einem Rahmen mit `außen`
    /// Radius sitzt.
    ///
    /// Apple nennt das konzentrische Ecken: nur wenn der innere Radius um genau den
    /// Abstand kleiner ist, laufen beide Rundungen parallel. Sonst wirkt die innere
    /// Ecke zu eckig oder zu rund.
    static func innenradius(außen: CGFloat, polster: CGFloat) -> CGFloat {
        max(außen - polster, 6)
    }

    // MARK: - Schriftgrade

    /// Die eine sehr große Zahl je Bildschirm. Bewusst ohne Ziffernbreite: bei dieser
    /// Größe reißt die feste Breite hässliche Lücken zwischen die Ziffern.
    static func hauptzahl(_ größe: CGFloat = 40) -> Font {
        .system(size: größe, weight: .bold, design: .rounded)
    }

    /// Ein Betrag in einer Liste - hier zählt, dass die Kommas fluchten.
    static func betrag(_ größe: CGFloat = 16, fett: Bool = true) -> Font {
        .system(size: größe, weight: fett ? .semibold : .regular).monospacedDigit()
    }

    /// Bildschirmtitel.
    static func titel(_ größe: CGFloat = 30) -> Font {
        .system(size: größe, weight: .bold, design: .rounded)
    }

    /// Abschnittsmarke über einer Gruppe - klein, versal, gesperrt.
    static let abschnitt = Font.system(size: 12, weight: .semibold)

    // MARK: - Kategoriefarben

    /// Die Farbe des runden Symbols einer Kategorie.
    ///
    /// Verwandte Kategorien teilen sich einen Ton, damit die Liste beim Überfliegen
    /// Gruppen zeigt statt eines Farbkastens: alles rund ums Fahrzeug blau, alles
    /// Bewirtete bernstein, alle Einnahmen grün.
    static func farbe(fuer kategorie: Belegkategorie) -> Color {
        switch kategorie {
        case .umsatzerlöse, .sonstigeErlöse, .anlagenverkauf, .privatentnahmeSachleistung:
            return haben
        case .wareneinkauf, .fremdleistungen:
            return farbe(dunkel: 0xFFA05C, hell: 0xC96A12)
        case .personalkosten:
            return farbe(dunkel: 0xFF7FB6, hell: 0xC01F62)
        case .abschreibung, .geringwertigeWirtschaftsgüter:
            return farbe(dunkel: 0x98A3C4, hell: 0x596585)
        case .raumkosten, .arbeitszimmer:
            return farbe(dunkel: 0x8C8BFF, hell: 0x4B48D4)
        case .versicherungenBeiträge:
            return farbe(dunkel: 0x4FDCCB, hell: 0x0B8579)
        case .kfzKosten, .reisekosten:
            return farbe(dunkel: 0x5EA8FF, hell: 0x1B6AD6)
        case .verpflegungsmehraufwand, .bewirtung:
            return farbe(dunkel: 0xFFCB5C, hell: 0xA37100)
        case .werbung:
            return farbe(dunkel: 0xEB80FF, hell: 0x9722B6)
        case .telefonInternet, .softwareAbos:
            return farbe(dunkel: 0xBB95FF, hell: 0x6C33C9)
        case .bürobedarf, .portoVersand, .fachliteraturFortbildung:
            return farbe(dunkel: 0x56D9F0, hell: 0x0B7893)
        case .rechtsUndSteuerberatung, .bankgebühren, .zinsen:
            return farbe(dunkel: 0xD4AE3A, hell: 0x846808)
        case .sonstigeAusgaben:
            return schriftGedämpft
        }
    }

    // MARK: - Hilfsmittel

    /// Baut eine Farbe, die dem Hell-/Dunkelmodus folgt, aus zwei Hexwerten.
    static func farbe(dunkel: UInt32, hell: UInt32) -> Color {
        Color(uiColor: UIColor { merkmale in
            merkmale.userInterfaceStyle == .dark ? uiFarbe(dunkel) : uiFarbe(hell)
        })
    }

    private static func uiFarbe(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    /// Die Farbe, in der ein Betrag geschrieben wird.
    ///
    /// Einnahmen grün mit Pluszeichen, Ausgaben in normaler Schriftfarbe. Ausgaben rot
    /// zu färben würde ein gewöhnliches Betriebsjahr wie einen Notstand aussehen lassen.
    static func betragsfarbe(istEinnahme: Bool) -> Color {
        istEinnahme ? haben : schrift
    }
}

// MARK: - Der Hintergrund

/// Der farbige Verlauf, der jeden Bildschirm trägt.
///
/// Zwei weiche Lichter auf tiefem Grund - eines violett oben links, eines blau unten
/// rechts. Sie sind das, was durch die Glasflächen scheint; ohne sie wäre jedes Glas
/// nur ein graues Rechteck.
struct Verlaufsgrund: View {

    var body: some View {
        ZStack {
            Stil.grund

            Circle()
                .fill(Stil.farbe(dunkel: 0x6B3FFF, hell: 0xA893FF))
                .frame(width: 520, height: 520)
                .blur(radius: 160)
                .offset(x: -130, y: -280)
                .opacity(0.55)

            Circle()
                .fill(Stil.farbe(dunkel: 0x1F5BFF, hell: 0x8FB4FF))
                .frame(width: 460, height: 460)
                .blur(radius: 170)
                .offset(x: 160, y: 300)
                .opacity(0.45)

            Circle()
                .fill(Stil.farbe(dunkel: 0xFF3FA0, hell: 0xFFAFD4))
                .frame(width: 320, height: 320)
                .blur(radius: 180)
                .offset(x: 170, y: -420)
                .opacity(0.28)
        }
        .ignoresSafeArea()
        // Der Verlauf ist Kulisse, kein Bedienelement - für die Sprachausgabe unsichtbar.
        .accessibilityHidden(true)
    }
}

extension View {

    /// Legt den Verlaufsgrund unter eine Ansicht und setzt die Akzentfarbe.
    func aufGrund() -> some View {
        self
            .background(Verlaufsgrund())
            .tint(Stil.akzent)
            // Platz für die schwebende Leiste: ohne ihn endet die letzte Zeile
            // unlesbar hinter dem Glas.
            .safeAreaPadding(.bottom, Stil.leistenhöhe)
            .toolbar(.hidden, for: .tabBar)
    }

    /// Macht aus einer Ansicht eine schwebende Glasfläche.
    func alsKarte(radius: CGFloat = Stil.radiusKarte, polster: CGFloat = 18) -> some View {
        self
            .padding(polster)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Stil.glas, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Stil.kante, lineWidth: 1)
            )
    }

    /// Glas ohne eigenes Polster - für Behälter, die ihre Zeilen selbst einrücken.
    func alsGlas(radius: CGFloat = Stil.radiusKarte) -> some View {
        self
            .background(Stil.glas, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Stil.kante, lineWidth: 1)
            )
    }

    /// Setzt eine `List` oder ein `Form` auf die Farben dieser App.
    ///
    /// Formulare bleiben bewusst Systemlisten: Auswahlfelder, Datumswähler und
    /// Zifferntastaturen sind darin erprobt, nachgebaute Bedienelemente sind genau die
    /// Stelle, an der Fehler entstehen. Verändert wird nur, was sie tragen.
    func alsListe() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Verlaufsgrund())
            .listRowBackground(Stil.fläche.opacity(0.55))
            .tint(Stil.akzent)
            .safeAreaPadding(.bottom, Stil.leistenhöhe)
            .toolbar(.hidden, for: .tabBar)
    }
}
