import SwiftUI

/// Farben, Radien und Schriften der Oberfläche - an einer Stelle festgelegt.
///
/// Die Gestaltung folgt der Sprache moderner Banking-Apps: dunkler Grund, eine sehr große
/// Betragszahl als Blickfang, runde Farbsymbole je Kategorie, Filter als Pillen, Karten
/// mit großzügigem Radius. Der Hellmodus ist eigens gesetzt und nicht umgekehrt - dunkle
/// Farben einfach zu invertieren ergibt milchige Flächen und zu schwache Kontraste.
enum Stil {

    // MARK: - Flächen

    /// Der Seitengrund, auf dem alles liegt.
    static let grund = farbe(dunkel: 0x0B0B0F, hell: 0xF2F2F6)

    /// Eine Karte auf dem Grund.
    static let fläche = farbe(dunkel: 0x17171E, hell: 0xFFFFFF)

    /// Abgesetzt innerhalb einer Karte - Chips, Eingabefelder, Symbolgründe.
    static let flächeHoch = farbe(dunkel: 0x23232D, hell: 0xEAEAF0)

    /// Haarlinie zwischen zwei Zeilen derselben Karte.
    static let trenner = farbe(dunkel: 0x26262F, hell: 0xE3E3EA)

    // MARK: - Schrift

    static let schrift = farbe(dunkel: 0xFFFFFF, hell: 0x0B0B0F)
    static let schriftGedämpft = farbe(dunkel: 0x8E8E9E, hell: 0x6C6C78)
    static let schriftLeise = farbe(dunkel: 0x5C5C6B, hell: 0x9A9AA6)

    // MARK: - Bedeutungsfarben

    /// Bedienelemente, ausgewählte Chips, der Hauptknopf.
    static let akzent = farbe(dunkel: 0x4B6FFF, hell: 0x2F55E0)

    /// Geld, das hereinkommt.
    static let haben = farbe(dunkel: 0x31D158, hell: 0x1B9E45)

    /// Etwas fehlt oder läuft ab - kein Fehler, aber zu erledigen.
    static let warnung = farbe(dunkel: 0xFFCC33, hell: 0xB07800)

    /// Fehler, Storno, überfällig.
    static let gefahr = farbe(dunkel: 0xFF4F4A, hell: 0xD4342D)

    // MARK: - Maße

    /// Radius einer großen Karte.
    static let radiusKarte: CGFloat = 22

    /// Radius einer kleinen Kachel oder eines Eingabefelds.
    static let radiusKachel: CGFloat = 16

    /// Seitenrand der Blätter.
    static let rand: CGFloat = 20

    /// Durchmesser des runden Kategoriesymbols in einer Buchungszeile.
    static let symbolgröße: CGFloat = 42

    // MARK: - Schriftgrade

    /// Die eine sehr große Zahl je Bildschirm. Bewusst ohne Ziffernbreite: bei dieser
    /// Größe reißt die feste Breite hässliche Lücken zwischen die Ziffern.
    static func hauptzahl(_ größe: CGFloat = 40) -> Font {
        .system(size: größe, weight: .bold)
    }

    /// Ein Betrag in einer Liste - hier zählt, dass die Kommas fluchten.
    static func betrag(_ größe: CGFloat = 16, fett: Bool = true) -> Font {
        .system(size: größe, weight: fett ? .semibold : .regular).monospacedDigit()
    }

    /// Bildschirmtitel.
    static func titel(_ größe: CGFloat = 30) -> Font {
        .system(size: größe, weight: .bold)
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
            return farbe(dunkel: 0xFF9F45, hell: 0xD97706)
        case .personalkosten:
            return farbe(dunkel: 0xFF6FA8, hell: 0xC2185B)
        case .abschreibung, .geringwertigeWirtschaftsgüter:
            return farbe(dunkel: 0x8E9BB3, hell: 0x5B6B84)
        case .raumkosten, .arbeitszimmer:
            return farbe(dunkel: 0x7C83FF, hell: 0x4C51D6)
        case .versicherungenBeiträge:
            return farbe(dunkel: 0x3ECFC0, hell: 0x0E8A7D)
        case .kfzKosten, .reisekosten:
            return farbe(dunkel: 0x4B9DFF, hell: 0x1E6FD9)
        case .verpflegungsmehraufwand, .bewirtung:
            return farbe(dunkel: 0xFFC247, hell: 0xA87400)
        case .werbung:
            return farbe(dunkel: 0xE472FF, hell: 0x9B27B8)
        case .telefonInternet, .softwareAbos:
            return farbe(dunkel: 0xB088FF, hell: 0x7038CC)
        case .bürobedarf, .portoVersand, .fachliteraturFortbildung:
            return farbe(dunkel: 0x45CFE8, hell: 0x0E7C95)
        case .rechtsUndSteuerberatung, .bankgebühren, .zinsen:
            return farbe(dunkel: 0xC9A227, hell: 0x8A6D0B)
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

extension View {

    /// Legt den Seitengrund unter eine Ansicht und setzt die Akzentfarbe.
    func aufGrund() -> some View {
        self
            .background(Stil.grund.ignoresSafeArea())
            .tint(Stil.akzent)
    }

    /// Macht aus einer Ansicht eine Karte auf dem Grund.
    func alsKarte(radius: CGFloat = Stil.radiusKarte, polster: CGFloat = 18) -> some View {
        self
            .padding(polster)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Stil.fläche, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {

    /// Setzt eine `List` oder ein `Form` auf die Farben dieser App.
    ///
    /// Formulare bleiben bewusst Systemlisten: Auswahlfelder, Datumswähler und
    /// Zifferntastaturen sind darin erprobt, nachgebaute Bedienelemente sind genau die
    /// Stelle, an der Fehler entstehen. Verändert wird nur, was sie tragen.
    func alsListe() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Stil.grund.ignoresSafeArea())
            .listRowBackground(Stil.fläche)
            .tint(Stil.akzent)
    }
}
