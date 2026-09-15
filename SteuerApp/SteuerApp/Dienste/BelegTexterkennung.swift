import Foundation
import UIKit
import Vision

/// Liest aus einem abfotografierten Beleg alles heraus, was die Belegmaske sonst von Hand
/// verlangt: Betrag, Datum, Haendler und Umsatzsteuersatz.
///
/// Das Ergebnis ist ein **Vorschlag**, kein Ersatz fuer die Kontrolle. Die Werte landen in
/// der Maske und koennen dort korrigiert werden. Erkannt wird, was deutsche Belege
/// ueblicherweise zeigen - bei einem zerknitterten Tankbeleg bleibt eben ein Feld leer.
enum BelegTexterkennung {

    struct Vorschlag: Equatable {
        var bruttoBetrag: Decimal?
        var datum: Date?
        var haendler: String?
        var umsatzsteuersatz: Umsatzsteuersatz?
        var kategorie: Belegkategorie?
        var erkannteZeilen: [String] = []

        static let leer = Vorschlag()
    }

    /// Schlagworte, die in deutschen Belegen direkt vor dem Endbetrag stehen.
    private static let summenworte = [
        "summe", "gesamt", "gesamtbetrag", "total", "zu zahlen", "zahlbetrag",
        "endbetrag", "rechnungsbetrag", "brutto", "betrag",
    ]

    /// Zeilen, die zwar oben stehen, aber nie der Haendlername sind.
    private static let keinHaendler = [
        "rechnung", "quittung", "beleg", "kassenbon", "bon", "datum", "uhrzeit",
        "tisch", "kasse", "steuer-nr", "steuernummer", "ust-id", "ustid",
        "telefon", "tel.", "www.", "http", "vielen dank", "danke",
    ]

    /// Strassenbezeichnungen. Zusammen mit einer Hausnummer kennzeichnen sie eine
    /// Adresszeile - "Baeckerei Sonnenweg" ohne Ziffer bleibt dagegen ein Haendlername.
    private static let strassenworte = ["str.", "strasse", "straße", "platz", "allee", "weg", "gasse"]

    // MARK: - Einstieg

    static func auswerten(bild: UIImage) async -> Vorschlag {
        auswerten(zeilen: await zeilenLesen(bild: bild))
    }

    /// Wertet bereits erkannte Textzeilen aus.
    ///
    /// Von der Bilderkennung getrennt, damit die Auswertung ohne Kamera und ohne Geraet
    /// pruefbar bleibt - dort sitzen die Fehler, nicht in der Texterkennung selbst.
    static func auswerten(zeilen: [String]) -> Vorschlag {
        let betrag = betragFinden(in: zeilen)
        let haendler = haendlerFinden(in: zeilen)
        return Vorschlag(
            bruttoBetrag: betrag,
            datum: datumFinden(in: zeilen),
            haendler: haendler,
            umsatzsteuersatz: steuersatzFinden(in: zeilen, bruttoBetrag: betrag),
            kategorie: Kategorievorschlag.fuer(haendler: haendler, zeilen: zeilen),
            erkannteZeilen: zeilen
        )
    }

    static func zeilenLesen(bild: UIImage) async -> [String] {
        guard let cgBild = bild.cgImage else { return [] }

        return await withCheckedContinuation { fortsetzung in
            let anfrage = VNRecognizeTextRequest { anfrage, _ in
                let beobachtungen = anfrage.results as? [VNRecognizedTextObservation] ?? []
                // Von oben nach unten sortieren: der Haendler steht im Kopf des Belegs,
                // und die Reihenfolge entscheidet daher ueber die Trefferqualitaet.
                let sortiert = beobachtungen.sorted {
                    $0.boundingBox.maxY > $1.boundingBox.maxY
                }
                fortsetzung.resume(returning: sortiert.compactMap {
                    $0.topCandidates(1).first?.string
                })
            }
            anfrage.recognitionLevel = .accurate
            anfrage.recognitionLanguages = ["de-DE", "en-US"]
            anfrage.usesLanguageCorrection = true

            let bearbeiter = VNImageRequestHandler(cgImage: cgBild, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try bearbeiter.perform([anfrage])
                } catch {
                    fortsetzung.resume(returning: [])
                }
            }
        }
    }

    // MARK: - Betrag

    /// Sucht zuerst in Zeilen mit Summenwort, sonst den groessten Betrag des Belegs.
    static func betragFinden(in zeilen: [String]) -> Decimal? {
        let mitSummenwort = zeilen.filter { zeile in
            let klein = zeile.lowercased()
            return summenworte.contains { klein.contains($0) }
        }

        if let treffer = mitSummenwort.flatMap(betraege(in:)).max() {
            return treffer
        }
        return zeilen.flatMap(betraege(in:)).max()
    }

    /// Alle Geldbetraege einer Zeile - deutsche Schreibweise mit Komma als Dezimaltrenner.
    static func betraege(in zeile: String) -> [Decimal] {
        let muster = #"\d{1,3}(?:[.\s]\d{3})*,\d{2}|\d+,\d{2}"#
        guard let regex = try? NSRegularExpression(pattern: muster) else { return [] }

        let bereich = NSRange(zeile.startIndex..<zeile.endIndex, in: zeile)
        return regex.matches(in: zeile, range: bereich).compactMap { treffer in
            guard let spanne = Range(treffer.range, in: zeile) else { return nil }
            let roh = String(zeile[spanne])
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: ".")
            return Decimal(string: roh, locale: Locale(identifier: "en_US_POSIX"))
        }
    }

    // MARK: - Datum

    /// Erstes plausibles Datum im Format TT.MM.JJJJ oder TT.MM.JJ.
    static func datumFinden(in zeilen: [String]) -> Date? {
        let muster = #"\b(\d{1,2})\.(\d{1,2})\.(\d{2}|\d{4})\b"#
        guard let regex = try? NSRegularExpression(pattern: muster) else { return nil }

        for zeile in zeilen {
            let bereich = NSRange(zeile.startIndex..<zeile.endIndex, in: zeile)
            guard let treffer = regex.firstMatch(in: zeile, range: bereich) else { continue }

            func zahl(_ index: Int) -> Int? {
                guard let spanne = Range(treffer.range(at: index), in: zeile) else { return nil }
                return Int(zeile[spanne])
            }
            guard let tag = zahl(1), let monat = zahl(2), var jahr = zahl(3) else { continue }
            if jahr < 100 { jahr += 2000 }
            guard (1...31).contains(tag), (1...12).contains(monat),
                  (2000...2100).contains(jahr) else { continue }

            var bestandteile = DateComponents()
            bestandteile.day = tag
            bestandteile.month = monat
            bestandteile.year = jahr
            bestandteile.hour = 12
            if let datum = Calendar.kalender.date(from: bestandteile) { return datum }
        }
        return nil
    }

    // MARK: - Haendler

    /// Der Haendlername steht im Kopf des Belegs - allerdings selten in der ersten Zeile.
    static func haendlerFinden(in zeilen: [String]) -> String? {
        for zeile in zeilen.prefix(6) {
            let bereinigt = zeile
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            guard bereinigt.count >= 3, bereinigt.count <= 48 else { continue }

            let klein = bereinigt.lowercased()
            guard !keinHaendler.contains(where: { klein.contains($0) }) else { continue }

            // Betragszeilen aussortieren: ueberwiegend Buchstaben muss es sein.
            let buchstaben = bereinigt.filter { $0.isLetter }.count
            let ziffern = bereinigt.filter { $0.isNumber }.count
            guard buchstaben >= 3, buchstaben > ziffern else { continue }

            guard !istAdresszeile(bereinigt) else { continue }

            return bereinigt
        }
        return nil
    }

    /// Strasse mit Hausnummer oder Postleitzahl - beides gehoert zur Anschrift, nicht zum Namen.
    static func istAdresszeile(_ zeile: String) -> Bool {
        let klein = zeile.lowercased()
        let hatZiffer = zeile.contains { $0.isNumber }
        if hatZiffer, strassenworte.contains(where: { klein.contains($0) }) { return true }
        return zeile.range(of: #"\b\d{5}\b"#, options: .regularExpression) != nil
    }

    // MARK: - Umsatzsteuersatz

    /// Ermittelt den Steuersatz aus den Prozentangaben des Belegs.
    ///
    /// Steht nur ein Satz auf dem Beleg, ist die Sache klar. Stehen beide da - bei einer
    /// Quittung mit Speisen und Getraenken etwa -, wird geprueft, welcher Satz zum
    /// Gesamtbetrag passt: der ausgewiesene Steuerbetrag muss dazu auf dem Beleg stehen.
    /// Passt keiner eindeutig, bleibt das Feld leer, statt zu raten.
    static func steuersatzFinden(
        in zeilen: [String],
        bruttoBetrag: Decimal?
    ) -> Umsatzsteuersatz? {
        let saetze = prozentangaben(in: zeilen)

        if saetze == [19] { return .regel }
        if saetze == [7] { return .ermaessigt }
        guard saetze.contains(19), saetze.contains(7), let brutto = bruttoBetrag,
              brutto > 0 else { return nil }

        // Prozentangaben vorher entfernen: "19,00 %" wuerde sonst als Betrag von 19,00 Euro
        // gelesen und die Pruefung auf sich selbst zurueckfuehren.
        let ohneProzente = zeilen.map {
            $0.replacingOccurrences(of: #"\d{1,2}(?:[.,]\d{1,2})?\s*%"#, with: " ",
                                    options: .regularExpression)
        }
        let vorhandeneBetraege = Set(ohneProzente.flatMap(betraege(in:)))
        let passend = [Umsatzsteuersatz.regel, .ermaessigt].filter {
            vorhandeneBetraege.contains($0.steueranteil(ausBrutto: brutto))
        }
        return passend.count == 1 ? passend.first : nil
    }

    /// Alle als Umsatzsteuersatz brauchbaren Prozentangaben des Belegs.
    static func prozentangaben(in zeilen: [String]) -> Set<Int> {
        let muster = #"(\d{1,2})(?:[.,]\d{1,2})?\s*%"#
        guard let regex = try? NSRegularExpression(pattern: muster) else { return [] }

        var gefunden = Set<Int>()
        for zeile in zeilen {
            let bereich = NSRange(zeile.startIndex..<zeile.endIndex, in: zeile)
            for treffer in regex.matches(in: zeile, range: bereich) {
                guard let spanne = Range(treffer.range(at: 1), in: zeile),
                      let wert = Int(zeile[spanne]), wert == 19 || wert == 7 else { continue }
                gefunden.insert(wert)
            }
        }
        return gefunden
    }
}
