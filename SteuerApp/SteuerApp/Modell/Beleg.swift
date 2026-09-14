import Foundation
import SwiftData

/// Ein einzelner Geschaeftsvorfall - Rechnung, Quittung, Kontoabbuchung.
///
/// Enums werden bewusst als `String` gespeichert und ueber berechnete Eigenschaften
/// zugaenglich gemacht: so bleibt die Datenbank lesbar und ein spaeter umbenannter Fall
/// macht den Datenbestand nicht unlesbar.
@Model
final class Beleg {

    // MARK: - Gespeicherte Daten

    var datum: Date = Date()
    var bezeichnung: String = ""

    /// Bruttobetrag, also inklusive Umsatzsteuer - das ist der Betrag, der auf dem Beleg steht.
    var bruttoBetrag: Decimal = Decimal(0)

    var kategorieCode: String = Belegkategorie.sonstigeAusgaben.rawValue
    var umsatzsteuersatzCode: String = Umsatzsteuersatz.regel.rawValue

    /// Betrieblicher Nutzungsanteil zwischen 0 und 1 - fuer gemischt genutzte Kosten
    /// wie Telefon oder Fahrzeug.
    var betrieblicherAnteil: Double = 1.0

    var notiz: String = ""

    /// Dateiname des Belegfotos im Belegarchiv, falls vorhanden.
    var belegbildDatei: String?

    var angelegtAm: Date = Date()

    init(
        datum: Date = Date(),
        bezeichnung: String = "",
        bruttoBetrag: Decimal = 0,
        kategorie: Belegkategorie = .sonstigeAusgaben,
        umsatzsteuersatz: Umsatzsteuersatz = .regel,
        betrieblicherAnteil: Double = 1.0,
        notiz: String = "",
        belegbildDatei: String? = nil
    ) {
        self.datum = datum
        self.bezeichnung = bezeichnung
        self.bruttoBetrag = bruttoBetrag
        self.kategorieCode = kategorie.rawValue
        self.umsatzsteuersatzCode = umsatzsteuersatz.rawValue
        self.betrieblicherAnteil = betrieblicherAnteil
        self.notiz = notiz
        self.belegbildDatei = belegbildDatei
        self.angelegtAm = Date()
    }

    // MARK: - Typisierter Zugriff

    var kategorie: Belegkategorie {
        get { Belegkategorie(rawValue: kategorieCode) ?? .sonstigeAusgaben }
        set { kategorieCode = newValue.rawValue }
    }

    var umsatzsteuersatz: Umsatzsteuersatz {
        get { Umsatzsteuersatz(rawValue: umsatzsteuersatzCode) ?? .regel }
        set { umsatzsteuersatzCode = newValue.rawValue }
    }

    var art: Belegart { kategorie.art }

    // MARK: - Abgeleitete Betraege

    /// Anteilsfaktor als `Decimal`, auf den gueltigen Bereich 0 ... 1 begrenzt.
    var anteilsfaktor: Decimal { Beleg.anteilsfaktor(aus: betrieblicherAnteil) }

    /// Der Weg ueber volle Prozentpunkte ist Absicht: `Decimal(Double)` kann je nach
    /// Plattform Rundungsreste erzeugen, und der Schieberegler kennt ohnehin nur
    /// Fuenf-Prozent-Schritte.
    static func anteilsfaktor(aus anteil: Double) -> Decimal {
        let prozentpunkte = (min(max(anteil, 0), 1) * 100).rounded()
        return Decimal(Int(prozentpunkte)) / 100
    }

    /// Nettobetrag des gesamten Belegs (ohne Beruecksichtigung des betrieblichen Anteils).
    var nettoBetrag: Decimal {
        umsatzsteuersatz.netto(ausBrutto: bruttoBetrag)
    }

    /// Im Beleg enthaltene Umsatzsteuer - bei Einnahmen die geschuldete Umsatzsteuer,
    /// bei Ausgaben die abziehbare Vorsteuer.
    var umsatzsteuerBetrag: Decimal {
        umsatzsteuersatz.steueranteil(ausBrutto: bruttoBetrag)
    }

    /// Betrieblicher Nettoanteil - Grundlage der Gewinnermittlung.
    var betrieblichesNetto: Decimal {
        (nettoBetrag * anteilsfaktor).gerundet()
    }

    /// Betrieblicher Bruttoanteil - Grundlage bei Kleinunternehmern ohne Vorsteuerabzug.
    var betrieblichesBrutto: Decimal {
        (bruttoBetrag * anteilsfaktor).gerundet()
    }

    /// Umsatzsteuer, die auf den betrieblichen Anteil entfaellt.
    var betrieblicheUmsatzsteuer: Decimal {
        (umsatzsteuerBetrag * anteilsfaktor).gerundet()
    }

    var jahr: Int {
        Calendar.kalender.component(.year, from: datum)
    }

    /// Kalenderquartal 1 ... 4 - fuer die Umsatzsteuer-Voranmeldung.
    var quartal: Int {
        (Calendar.kalender.component(.month, from: datum) - 1) / 3 + 1
    }

    var monat: Int {
        Calendar.kalender.component(.month, from: datum)
    }
}

extension Calendar {
    /// Gregorianischer Kalender in deutscher Zeitzone - damit ein Beleg vom 31.12. abends
    /// nicht versehentlich im Folgejahr landet.
    static let kalender: Calendar = {
        var kalender = Calendar(identifier: .gregorian)
        kalender.locale = Locale(identifier: "de_DE")
        kalender.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        return kalender
    }()
}
