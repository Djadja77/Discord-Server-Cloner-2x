import SwiftUI
import UIKit

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
    ///
    /// Im Dunkeln bewusst nicht Schwarz. Die Lichter des Verlaufs sitzen oben;
    /// wer eine lange Liste durchscrollt, ist nach einem Bildschirm daran vorbei.
    /// Auf reinem Schwarz wird dort jedes Material wieder schwarz - der untere
    /// Teil der App sah aus wie ausgeschaltet.
    static let grund = farbe(dunkel: 0x0E0C18, hell: 0xF4F3FA)

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

    /// Die Farben, aus denen Ordner ihre Kennzeichnung bekommen.
    ///
    /// Sechs reichen: bei mehr unterscheidet sie ohnehin niemand mehr auseinander, und
    /// der Name steht daneben. Der Index kommt aus der Datenbank, die Farbe von hier -
    /// so weiss die Datenbank nichts über die Gestaltung.
    static func ordnerfarbe(_ index: Int) -> Color {
        let töne: [(UInt32, UInt32)] = [
            (0x7A6BFF, 0x5443E0),
            (0x3DDC84, 0x158A45),
            (0xFFC94D, 0xA97400),
            (0xFF7FB6, 0xC01F62),
            (0x4FC3F7, 0x0277BD),
            (0xFFA05C, 0xC96A12),
        ]
        let ton = töne[((index % töne.count) + töne.count) % töne.count]
        return farbe(dunkel: ton.0, hell: ton.1)
    }

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

        /// Wie stark der Schleier im Hellen deckt.
        ///
        /// Das ist der Teil, den iOS 27 "bessere Streuung" nennt: Material allein
        /// lässt kräftige Farben durchschlagen, und Text darauf fällt unter die
        /// Lesbarkeitsgrenze von 4,5:1. Der Schleier hebt den Untergrund an, bevor
        /// die Schrift darauf liegt.
        ///
        /// Die drei Stufen lagen einmal bei 0,52 / 0,58 / 0,68 - über einer ohnehin
        /// fast weissen Fläche ein Unterschied, den niemand sieht. Der Regler schien
        /// deshalb wirkungslos. Jetzt spannen sie den ganzen Bereich von "sieht den
        /// Verlauf" bis "deckt ihn ab".
        var deckungHell: Double {
            switch self {
            case .klar: 0.30
            case .mittel: 0.58
            case .getönt: 0.86
            }
        }

        /// Wie stark der Schleier im Dunkeln anhebt.
        ///
        /// Im Dunkeln gibt es nichts abzudecken - dort fehlt Licht. Deshalb hebt der
        /// Schleier an, und die Stufen unterscheiden sich entsprechend deutlich.
        var aufhellungDunkel: Double {
            switch self {
            case .klar: 0.04
            case .mittel: 0.11
            case .getönt: 0.19
            }
        }
    }

    /// Der Schleier über dem Material.
    ///
    /// Im Hellen deckt er mit Weiß ab, damit der Verlauf nicht durch die Schrift
    /// schlägt. Im Dunkeln macht er das Gegenteil: er hebt die Fläche mit einem
    /// Hauch Violett an.
    ///
    /// Der Grund dafür ist, was Material im Dunkeln tut - es streut, was
    /// dahinterliegt, und erfindet kein Licht. Über der hellen Stelle des
    /// Verlaufs sah eine Karte deshalb gut aus, eine Liste weiter unten auf
    /// demselben Bildschirm dagegen fast schwarz. Der Aufheller macht die Fläche
    /// unabhängig davon, wie viel Licht zufällig dahinterliegt.
    static func schleierfarbe(_ stärke: Glasstärke) -> Color {
        Color(uiColor: UIColor { merkmale in
            merkmale.userInterfaceStyle == .dark
                ? UIColor(red: 0.478, green: 0.420, blue: 1.0,
                          alpha: stärke.aufhellungDunkel)
                : UIColor.white.withAlphaComponent(stärke.deckungHell)
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
    static let umriss = Color(uiColor: UIColor { merkmale in
        merkmale.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.32)
            : UIColor(red: 0.06, green: 0.05, blue: 0.10, alpha: 0.14)
    })

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

    @Environment(\.colorScheme) private var modus
    @Environment(\.colorSchemeContrast) private var kontrast

    /// Wie kräftig die Lichter brennen dürfen.
    ///
    /// Im Dunkeln tragen sie den Bildschirm - dort ist der Grund fast schwarz, und
    /// ohne sie wäre jede Glasfläche ein graues Rechteck. Im Hellen liegen sie über
    /// Weiß, und dieselbe Stärke ergäbe keinen Hauch Farbe, sondern eine lila
    /// Milchsuppe, durch die man den Text kaum noch liest. Ein Drittel reicht dort.
    /// Bei "Kontrast erhöhen" verschwinden sie fast ganz.
    private var stärke: Double {
        if kontrast == .increased { return modus == .dark ? 0.45 : 0.10 }
        return modus == .dark ? 1.0 : 0.30
    }

    /// - Important: Die Lichter hängen als `overlay` an einer Farbfläche, nicht als
    ///   Geschwister in einem `ZStack`. Ein Overlay beeinflusst die Größe seines
    ///   Trägers nie. Als Geschwister dagegen bestimmt der größte Inhalt die Größe
    ///   des Stapels - und die Kreise sind 520 Punkt breit. Genau das hat einmal den
    ///   ganzen Bildschirm auf 520 Punkt aufgeblasen, sodass der Inhalt links und
    ///   rechts aus dem Gerät lief.
    var body: some View {
        Stil.grund
            .overlay {
                ZStack {
                    licht(farbe: Stil.farbe(dunkel: 0x6B3FFF, hell: 0x9E86FF),
                          größe: 520, unschärfe: 160, x: -130, y: -280, deckung: 0.55)
                    licht(farbe: Stil.farbe(dunkel: 0x1F5BFF, hell: 0x7FA8FF),
                          größe: 460, unschärfe: 170, x: 160, y: 300, deckung: 0.45)
                    licht(farbe: Stil.farbe(dunkel: 0xFF3FA0, hell: 0xFF9EC9),
                          größe: 320, unschärfe: 180, x: 170, y: -420, deckung: 0.28)
                }
            }
            .clipped()
            .ignoresSafeArea()
            // Der Verlauf ist Kulisse, kein Bedienelement - für die Sprachausgabe unsichtbar.
            .accessibilityHidden(true)
    }

    private func licht(
        farbe: Color, größe: CGFloat, unschärfe: CGFloat,
        x: CGFloat, y: CGFloat, deckung: Double
    ) -> some View {
        Circle()
            .fill(farbe)
            .frame(width: größe, height: größe)
            .blur(radius: unschärfe)
            .offset(x: x, y: y)
            .opacity(deckung * stärke)
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
        Stil.Glasstärke(rawValue: stärkeRoh) ?? .mittel
    }

    /// Bei "Kontrast erhöhen" ist die Fläche deckend, nicht nur stärker getönt:
    /// Weiß auf Glas bleibt sonst auch in der dichtesten Stufe eine Frage des
    /// Hintergrunds, und genau das soll die Einstellung ausschließen.
    private var deckend: Bool { transparenzReduziert || kontrast == .increased }

    func body(content: Content) -> some View {
        content
            .background {
                if deckend {
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

/// Der Grund einer Zeile in einer Systemliste - dasselbe Glas wie eine Karte,
/// nur ohne Ränder.
///
/// Vorher war das eine feste dunkle Farbe. Dadurch sahen die Listenbildschirme
/// (Steuer, Mehr) deutlich dunkler aus als die Kartenbildschirme (Stand,
/// Belege), obwohl beide dieselbe Fläche meinen. Jetzt liegt unter beiden das
/// gleiche Material samt Schleier, und der Regler unter "Mehr > Glas" wirkt
/// überall gleich.
///
/// Ränder bekommt eine Zeile bewusst nicht: sie grenzt oben und unten an die
/// nächste, ein Rahmen je Zeile ergäbe ein Gitter statt einer Fläche. Die
/// Ecken rundet die Systemliste selbst.
struct Listenfläche: View {

    @Environment(\.accessibilityReduceTransparency) private var transparenzReduziert
    @Environment(\.colorSchemeContrast) private var kontrast
    @AppStorage("glasstaerke") private var stärkeRoh = Stil.Glasstärke.mittel.rawValue

    private var stärke: Stil.Glasstärke {
        Stil.Glasstärke(rawValue: stärkeRoh) ?? .mittel
    }

    var body: some View {
        if transparenzReduziert || kontrast == .increased {
            Rectangle().fill(Stil.flächeDeckend)
        } else {
            Rectangle()
                .fill(stärke.material)
                .overlay { Rectangle().fill(Stil.schleierfarbe(stärke)) }
        }
    }
}

extension View {

    /// "Fertig" über der Tastatur - für dieses Feld.
    ///
    /// Nicht jede Tastatur bringt einen Weg aus sich heraus mit. Die Zifferntastatur hat
    /// keine Eingabetaste, und in einem mehrzeiligen Feld setzt die Eingabetaste einen
    /// Zeilenumbruch, statt abzuschliessen. Auf genau diesen Feldern stünde man sonst
    /// vor einer Tastatur ohne Ausgang. Die übrigen bekommen den Knopf trotzdem: ein
    /// Abschluss, den es mal gibt und mal nicht, ist schlimmer als einer zu viel.
    ///
    /// Der Knopf hängt am Feld und nicht am Bildschirm, und zwar hinter `amZug`. Eine
    /// Leiste je Bildschirm wäre die kürzere Schreibweise, aber `Mehr` schiebt das
    /// Anlagevermögen nach, das selbst wieder Felder führt - und Tastaturleisten aus
    /// zwei übereinanderliegenden Bildschirmen legen sich nebeneinander statt sich zu
    /// ersetzen. Zwei "Fertig" nebeneinander sähen aus wie ein Fehler. So kann es sie
    /// nicht geben: sichtbar ist immer nur die Leiste des Feldes, in dem geschrieben
    /// wird.
    func tastaturFertig() -> some View {
        modifier(TastaturAbschluss())
    }

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
    /// - Parameter mitGrund: `false`, wenn die umgebende Ansicht den Verlauf schon
    ///   legt. Zweimal gezeichnet säße jeder Verlauf in seinem eigenen Rahmen, und
    ///   die Lichter der Kopfzeile träfen die der Liste nicht.
    func alsListe(mitGrund: Bool = true) -> some View {
        self
            .scrollContentBackground(.hidden)
            .background { if mitGrund { Verlaufsgrund() } }
            .listRowBackground(Listenfläche())
            .tint(Stil.akzent)
            // Zweiter Weg aus der Tastatur heraus, neben "Fertig" über den Tasten:
            // ein Wisch über die Liste. Eine Tastatur, aus der man nur auf einem
            // einzigen Weg herauskommt, ist eine Falle, sobald dieser Weg klemmt.
            .scrollDismissesKeyboard(.interactively)
            .safeAreaPadding(.bottom, Stil.leistenhöhe)
            .toolbar(.hidden, for: .tabBar)
    }
}

/// Trägt den "Fertig"-Knopf über der Tastatur - siehe `tastaturFertig()`.
private struct TastaturAbschluss: ViewModifier {

    @FocusState private var amZug: Bool

    func body(content: Content) -> some View {
        content
            .focused($amZug)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if amZug {
                        Spacer()
                        Button("Fertig") { amZug = false }
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
            }
    }
}
