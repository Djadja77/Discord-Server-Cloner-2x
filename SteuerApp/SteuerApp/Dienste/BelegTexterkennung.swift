import Foundation
import UIKit
import Vision

/// Liest Betrag und Datum aus einem abfotografierten Beleg.
///
/// Das Ergebnis ist ein **Vorschlag**, kein Ersatz fuer die Kontrolle: die Werte landen in
/// der Belegmaske und koennen dort korrigiert werden. Erkannt wird nur, was deutsche Belege
/// ueblicherweise zeigen - Summenzeile und Belegdatum.
enum BelegTexterkennung {

    struct Vorschlag: Equatable {
        var bruttoBetrag: Decimal?
        var datum: Date?
        var erkannterText: String
    }

    /// Schlagworte, die in deutschen Belegen direkt vor dem Endbetrag stehen.
    private static let summenworte = [
        "summe", "gesamt", "gesamtbetrag", "total", "zu zahlen", "zahlbetrag",
        "endbetrag", "rechnungsbetrag", "brutto", "betrag",
    ]

    static func auswerten(bild: UIImage) async -> Vorschlag {
        guard let cgBild = bild.cgImage else {
            return Vorschlag(bruttoBetrag: nil, datum: nil, erkannterText: "")
        }

        let zeilen: [String] = await withCheckedContinuation { fortsetzung in
            let anfrage = VNRecognizeTextRequest { anfrage, _ in
                let beobachtungen = anfrage.results as? [VNRecognizedTextObservation] ?? []
                fortsetzung.resume(returning: beobachtungen.compactMap {
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

        return Vorschlag(
            bruttoBetrag: betragFinden(in: zeilen),
            datum: datumFinden(in: zeilen),
            erkannterText: zeilen.joined(separator: "\n")
        )
    }

    // MARK: - Auswertung

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
}
