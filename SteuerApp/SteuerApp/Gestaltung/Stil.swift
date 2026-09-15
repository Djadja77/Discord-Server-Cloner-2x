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

    /// Wie stark das Glas tönt - entspricht dem Regler, den iOS 27 unter
    /// "Anzeige & Helligkeit > Liquid Glass" anbietet.
    ///
    /// Apple hat den Regler nachgereicht, weil klares Glas über unruhigem Inhalt
    /// schwer zu lesen ist. Dieselbe Wahl gehört in die App: wer viele Belegfotos
    /// mit hellen Flächen hat, dreht auf "Getönt" und liest wieder mühelos.
    enum Glasstärke: Int, CaseIterable, Identifiable {
        case klar = 0
        case mittel = 1
        case getönt = 2

        var id: Int { rawValue }

        var bezeichnung: String {
            switch self {
            case .klar: "Klar"
            case .mittel: "Mittel"
            case .getönt: "Getönt"
            }
        }

        /// Das Material darunter. Je getönter, desto dichter streut es.
        var material: Material {
            switch self {
            case .klar: .ultraThinMaterial
            case .mittel: .thinMaterial
            case .getönt: .regularMaterial
            }
        }

        /// Zusätzlicher Schleier über dem Material.
        ///
        /// Das ist der Teil, den iOS 27 "bessere Streuung" nennt: Material allein
        /// lässt kräftige Farben durchschlagen, und Text darauf fällt unter die
        /// Lesbarkeitsgrenze von 4,5:1. Der Schleier hebt den Untergrund an, bevor
        /// die Schrift darauf liegt.
        var schleier: Double {
            switch self {
            case .klar: 0.04
            case .mittel: 0.10
            case .getönt: 0.20
            }
        }
    }

    /// Der Schleier über dem Material - im Dunkeln schwarz, im Hellen weiß.
    static func schleierfarbe(_ stärke: Glasstärke) -> Color {
        Color(uiColor: UIColor { merkmale in
            merkmale.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(stärke.schleier)
                : UIColor.white.withAlphaComponent(stärke.schleier + 0.30)
        })
    }

    /// Deckende Fläche für alle, die "Transparenz reduzieren" eingeschaltet haben.
    static let flächeDeckend = farbe(dunkel: 0x16151E, hell: 0xFFFFFF)

    /// Die Lichtkante innen an einer Glasfläche - die Spiegelung.
    ///
    /// Oben links hell, unten rechts fast weg. Sie macht eine Fläche als Glas
    /// lesbar und nicht als graues Rechteck.
    static var kante: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.42), Color.white.opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Der dunkle Umriss außen.
    ///
    /// In iOS 26 fehlte er, und Glasflächen verschwammen vor unruhigem Hintergrund.
    /// iOS 27 hat ihn nachgezogen: er trennt die Fläche vom Grund, unabhängig davon,
    /// was gerade dahinter liegt.
    static let umriss = Color.black.opacity(0.28)

    /// Schwächere Lichtkante für kleine Elemente - Pillen, Knöpfe, Symbolkreise.
    static var kanteFein: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.30), Color.white.opacity(0.04)],
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

/// Macht aus einer beliebigen Form eine Glasfläche nach den Regeln von iOS 27.
///
/// Drei Schichten, jede mit einer Aufgabe:
/// 1. **Material** streut, was dahinter liegt.
/// 2. **Schleier** hebt den Untergrund an, damit Schrift darauf über der
///    Lesbarkeitsgrenze von 4,5:1 bleibt - iOS 26 hatte ihn nicht, und genau
///    deshalb war Text über Fotos dort schwer zu lesen.
/// 3. **Zwei Ränder**: außen ein dunkler Umriss, der die Fläche vom Grund trennt,
///    innen eine helle Kante als Spiegelung. Nur der helle Rand allein lässt Glas
///    vor unruhigem Hintergrund verschwimmen.
///
/// Wer "Transparenz reduzieren" eingeschaltet hat, bekommt eine deckende Fläche;
/// bei "Kontrast erhöhen" schaltet die Tönung selbsttätig auf die stärkste Stufe.
struct Glasfläche<Form: InsettableShape>: ViewModifier {

    let form: Form
    /// Für Leisten, die über Inhalt liegen und ihn sichtbar abtrennen müssen.
    var kräftig = false

    @Environment(\.accessibilityReduceTransparency) private var transparenzReduziert
    @Environment(\.colorSchemeContrast) private var kontrast
    @AppStorage("glasstaerke") private var stärkeRoh = Stil.Glasstärke.mittel.rawValue

    private var stärke: Stil.Glasstärke {
        guard kontrast != .increased else { return .getönt }
        return Stil.Glasstärke(rawValue: stärkeRoh) ?? .mittel
    }

    func body(content: Content) -> some View {
        content
            .background {
                if transparenzReduziert {
                    form.fill(Stil.flächeDeckend)
                } else {
                    ZStack {
                        form.fill(kräftig ? .regularMaterial : stärke.material)
                        form.fill(Stil.schleierfarbe(stärke))
                    }
                }
            }
            .overlay { form.strokeBorder(Stil.umriss, lineWidth: 1) }
            .overlay { form.inset(by: 1).strokeBorder(Stil.kante, lineWidth: 0.9) }
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

    /// Glas in einer beliebigen Form - Kapsel, Kreis, abgerundetes Rechteck.
    func alsGlas<Form: InsettableShape>(_ form: Form, kräftig: Bool = false) -> some View {
        modifier(Glasfläche(form: form, kräftig: kräftig))
    }

    /// Glas als abgerundetes Rechteck, ohne eigenes Polster.
    func alsGlas(radius: CGFloat = Stil.radiusKarte, kräftig: Bool = false) -> some View {
        alsGlas(RoundedRectangle(cornerRadius: radius, style: .continuous), kräftig: kräftig)
    }

    /// Eine schwebende Glaskarte mit Polster.
    func alsKarte(radius: CGFloat = Stil.radiusKarte, polster: CGFloat = 18) -> some View {
        self
            .padding(polster)
            .frame(maxWidth: .infinity, alignment: .leading)
            .alsGlas(radius: radius)
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
