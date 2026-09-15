import Foundation

/// Ein Beleg in Bearbeitung - noch nicht in der Datenbank.
///
/// Sowohl die Einzelmaske als auch die Stapelerfassung arbeiten damit. Auf einem Entwurf
/// statt direkt auf dem Datenbankobjekt zu arbeiten heisst: Abbrechen ist folgenlos, und
/// ein Scan-Stapel kann als Ganzes verworfen werden.
struct Belegentwurf: Identifiable, Equatable {

    let id = UUID()

    var datum = Date()
    var bezeichnung = ""
    var bruttoBetrag: Decimal = 0
    var kategorie: Belegkategorie = .sonstigeAusgaben
    var umsatzsteuersatz: Umsatzsteuersatz = .regel
    var betrieblicherAnteil: Double = 1.0
    var notiz = ""

    /// Dateiname eines bereits gespeicherten Belegfotos.
    var belegbildDatei: String?

    init() {}

    init(beleg: Beleg) {
        datum = beleg.datum
        bezeichnung = beleg.bezeichnung
        bruttoBetrag = beleg.bruttoBetrag
        kategorie = beleg.kategorie
        umsatzsteuersatz = beleg.umsatzsteuersatz
        betrieblicherAnteil = beleg.betrieblicherAnteil
        notiz = beleg.notiz
        belegbildDatei = beleg.belegbildDatei
    }

    /// Uebertraegt den Entwurf auf einen Beleg.
    func anwenden(auf beleg: Beleg) {
        beleg.datum = datum
        beleg.bezeichnung = bezeichnung
        beleg.bruttoBetrag = bruttoBetrag
        beleg.kategorie = kategorie
        beleg.umsatzsteuersatz = umsatzsteuersatz
        beleg.betrieblicherAnteil = betrieblicherAnteil
        beleg.notiz = notiz
        beleg.belegbildDatei = belegbildDatei
    }

    /// Uebernimmt die Vorschlaege der Texterkennung.
    ///
    /// Gefuellt wird nur, was noch leer ist: eine Korrektur von Hand darf die Texterkennung
    /// niemals ueberschreiben. Das Datum wird zusaetzlich nur uebernommen, wenn es ins
    /// bearbeitete Steuerjahr faellt - ein falsch erkanntes Jahr sortiert den Beleg sonst
    /// unbemerkt aus der Auswertung heraus.
    mutating func uebernehmen(
        _ vorschlag: BelegTexterkennung.Vorschlag,
        steuerjahr: Int? = nil
    ) {
        if bruttoBetrag == 0, let betrag = vorschlag.bruttoBetrag {
            bruttoBetrag = betrag
        }
        if bezeichnung.isEmpty, let haendler = vorschlag.haendler {
            bezeichnung = haendler
        }
        if kategorie == .sonstigeAusgaben, let vorgeschlagen = vorschlag.kategorie {
            kategorie = vorgeschlagen
        }
        if let satz = vorschlag.umsatzsteuersatz {
            umsatzsteuersatz = satz
        }
        if let erkanntesDatum = vorschlag.datum {
            let jahr = Calendar.kalender.component(.year, from: erkanntesDatum)
            if steuerjahr == nil || steuerjahr == jahr {
                datum = erkanntesDatum
            }
        }
    }

    /// Ein Entwurf ist erfassbar, sobald ein Betrag darin steht.
    var istVollstaendig: Bool { bruttoBetrag > 0 }

    /// Startdatum fuer einen neuen Beleg im gerade bearbeiteten Steuerjahr.
    ///
    /// Wer im Februar die Belege des Vorjahres nacherfasst, soll sie nicht versehentlich
    /// im laufenden Jahr anlegen - deshalb faellt die Vorgabe in fremden Jahren auf den
    /// 31. Dezember.
    static func vorgabedatum(fuerJahr jahr: Int) -> Date {
        let heute = Date()
        guard Calendar.kalender.component(.year, from: heute) != jahr else { return heute }
        return Calendar.kalender.date(from: DateComponents(
            year: jahr, month: 12, day: 31, hour: 12)) ?? heute
    }
}
