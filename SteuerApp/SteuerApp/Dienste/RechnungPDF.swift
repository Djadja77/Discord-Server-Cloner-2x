import Foundation
import UIKit

/// Druckt eine Rechnung als PDF - das Dokument, das beim Kunden ankommt.
///
/// Gezeichnet statt aus einer SwiftUI-Ansicht gerendert, aus einem Grund: eine Rechnung
/// mit dreißig Positionen muss auf die zweite Seite umbrechen, und zwar so, dass die
/// Tabellenköpfe wieder oben stehen und der Fuß mit Steuernummer und Bankverbindung auf
/// jeder Seite erscheint. Das ist Seitenumbruch, und den macht man von Hand.
///
/// Das Blatt ist DIN A4 in Punkten (72 dpi): 595,3 × 841,9.
enum RechnungPDF {

    // MARK: - Maße

    private static let seite = CGRect(x: 0, y: 0, width: 595.3, height: 841.9)
    private static let randLinks: CGFloat = 56
    private static let randRechts: CGFloat = 56
    private static let randOben: CGFloat = 52
    private static let randUnten: CGFloat = 64
    private static var breite: CGFloat { seite.width - randLinks - randRechts }

    // MARK: - Schriften

    private static let klein = UIFont.systemFont(ofSize: 7.5)
    private static let text = UIFont.systemFont(ofSize: 9.5)
    private static let textFett = UIFont.systemFont(ofSize: 9.5, weight: .semibold)
    private static let überschrift = UIFont.systemFont(ofSize: 17, weight: .bold)
    private static let grau = UIColor(white: 0.42, alpha: 1)
    private static let schwarz = UIColor(white: 0.10, alpha: 1)
    private static let linie = UIColor(white: 0.80, alpha: 1)

    // MARK: - Druck

    static func erzeugen(_ rechnung: Rechnung) -> Data {
        let drucker = UIGraphicsPDFRenderer(bounds: seite, format: eigenschaften(rechnung))

        return drucker.pdfData { zug in
            var seitennummer = 1
            zug.beginPage()

            var y = kopf(rechnung, zug: zug)
            y = tabellenkopf(rechnung, ab: y)

            for (stelle, posten) in rechnung.postenGeordnet.enumerated() {
                let höhe = zeilenhöhe(posten, kleinunternehmer: rechnung.kleinunternehmer)
                if y + höhe > seite.height - randUnten - 20 {
                    fuß(rechnung, seitennummer: seitennummer)
                    zug.beginPage()
                    seitennummer += 1
                    y = randOben
                    y = tabellenkopf(rechnung, ab: y)
                }
                y = zeile(posten, stelle: stelle + 1, kleinunternehmer: rechnung.kleinunternehmer, ab: y)
            }

            // Die Summen dürfen nicht allein auf einer Seite stehen - sie gehören zu
            // dem, was sie summieren.
            let summenhöhe: CGFloat = 26 + CGFloat(rechnung.umsatzsteuerJeSatz.count) * 14 + 78
            if y + summenhöhe > seite.height - randUnten {
                fuß(rechnung, seitennummer: seitennummer)
                zug.beginPage()
                seitennummer += 1
                y = randOben
            }
            y = summen(rechnung, ab: y)
            _ = schluss(rechnung, ab: y)
            fuß(rechnung, seitennummer: seitennummer)
        }
    }

    private static func eigenschaften(_ rechnung: Rechnung) -> UIGraphicsPDFRendererFormat {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Rechnung \(rechnung.nummer)",
            kCGPDFContextAuthor as String: rechnung.absenderName,
            kCGPDFContextCreator as String: "Steuer",
        ]
        return format
    }

    /// Dateiname zum Teilen - so, wie ihn der Empfänger im Anhang sieht.
    static func dateiname(_ rechnung: Rechnung) -> String {
        let kunde = rechnung.empfaengerName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespaces)
        let teil = kunde.isEmpty ? "" : " " + kunde
        return "Rechnung \(rechnung.nummer)\(teil).pdf"
    }

    // MARK: - Blöcke

    private static func kopf(_ rechnung: Rechnung, zug: UIGraphicsPDFRendererContext) -> CGFloat {
        // Eigene Anschrift klein über dem Adressfeld - so, wie es im Fensterumschlag
        // sichtbar wird.
        let absenderEinzeilig = rechnung.absenderAnschrift
            .split(separator: "\n")
            .joined(separator: " · ")
        schreiben(absenderEinzeilig, in: CGRect(x: randLinks, y: randOben + 34, width: breite * 0.6, height: 12),
                  schrift: klein, farbe: grau)

        var y = randOben + 50
        for zeile in rechnung.empfaengerAnschrift.split(separator: "\n") {
            schreiben(String(zeile), in: CGRect(x: randLinks, y: y, width: breite * 0.55, height: 14),
                      schrift: text, farbe: schwarz)
            y += 13
        }
        if !rechnung.empfaengerUstIdNr.isEmpty {
            schreiben("USt-IdNr. " + rechnung.empfaengerUstIdNr,
                      in: CGRect(x: randLinks, y: y + 2, width: breite * 0.55, height: 12),
                      schrift: klein, farbe: grau)
        }

        // Rechte Spalte: die Angaben, nach denen jeder zuerst sucht.
        var rechtsY = randOben + 34
        var angaben: [(String, String)] = [
            ("Rechnungsnummer", rechnung.nummer),
            ("Rechnungsdatum", Formatierung.datum(rechnung.datum)),
        ]
        if let zeitraum = leistungszeitraum(rechnung) { angaben.append(("Leistung", zeitraum)) }
        if !rechnung.absenderSteuernummer.isEmpty {
            angaben.append(("Steuernummer", rechnung.absenderSteuernummer))
        }
        if !rechnung.absenderUstIdNr.isEmpty { angaben.append(("USt-IdNr.", rechnung.absenderUstIdNr)) }

        let spalteX = seite.width - randRechts - 190
        for (bezeichnung, wert) in angaben {
            schreiben(bezeichnung, in: CGRect(x: spalteX, y: rechtsY, width: 92, height: 12),
                      schrift: klein, farbe: grau)
            schreiben(wert, in: CGRect(x: spalteX + 94, y: rechtsY - 1, width: 96, height: 13),
                      schrift: text, farbe: schwarz, ausrichtung: .right)
            rechtsY += 14
        }

        let titelY = max(y + 34, rechtsY + 24)
        let titel = rechnung.stornoFuerNummer.isEmpty ? "Rechnung" : "Stornorechnung"
        schreiben("\(titel) \(rechnung.nummer)",
                  in: CGRect(x: randLinks, y: titelY, width: breite, height: 24),
                  schrift: überschrift, farbe: schwarz)

        var unten = titelY + 30
        if !rechnung.stornoFuerNummer.isEmpty {
            schreiben("Hebt die Rechnung \(rechnung.stornoFuerNummer) vollständig auf.",
                      in: CGRect(x: randLinks, y: unten, width: breite, height: 14),
                      schrift: text, farbe: grau)
            unten += 18
        }
        return unten + 6
    }

    private static func tabellenkopf(_ rechnung: Rechnung, ab y: CGFloat) -> CGFloat {
        let spalten = spaltenbreiten(kleinunternehmer: rechnung.kleinunternehmer)
        var x = randLinks
        let köpfe: [(String, NSTextAlignment)] = rechnung.kleinunternehmer
            ? [("Pos.", .left), ("Bezeichnung", .left), ("Menge", .right), ("Einzel", .right), ("Betrag", .right)]
            : [("Pos.", .left), ("Bezeichnung", .left), ("Menge", .right), ("Einzel", .right),
               ("USt", .right), ("Betrag", .right)]

        for (stelle, kopf) in köpfe.enumerated() {
            schreiben(kopf.0, in: CGRect(x: x, y: y, width: spalten[stelle], height: 12),
                      schrift: klein, farbe: grau, ausrichtung: kopf.1)
            x += spalten[stelle]
        }
        strich(y: y + 14)
        return y + 20
    }

    private static func zeilenhöhe(_ posten: Rechnungsposten, kleinunternehmer: Bool) -> CGFloat {
        let spalten = spaltenbreiten(kleinunternehmer: kleinunternehmer)
        let höhe = (posten.bezeichnung as NSString).boundingRect(
            with: CGSize(width: spalten[1] - 8, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: text],
            context: nil
        ).height
        return max(höhe, 12) + 9
    }

    private static func zeile(
        _ posten: Rechnungsposten, stelle: Int, kleinunternehmer: Bool, ab y: CGFloat
    ) -> CGFloat {
        let spalten = spaltenbreiten(kleinunternehmer: kleinunternehmer)
        let höhe = zeilenhöhe(posten, kleinunternehmer: kleinunternehmer)
        var x = randLinks

        schreiben("\(stelle)", in: CGRect(x: x, y: y, width: spalten[0], height: 14), schrift: text, farbe: grau)
        x += spalten[0]

        schreiben(posten.bezeichnung, in: CGRect(x: x, y: y, width: spalten[1] - 8, height: höhe),
                  schrift: text, farbe: schwarz)
        x += spalten[1]

        let menge = Formatierung.menge(posten.menge) + (posten.einheit.isEmpty ? "" : " " + posten.einheit)
        schreiben(menge, in: CGRect(x: x, y: y, width: spalten[2], height: 14),
                  schrift: text, farbe: schwarz, ausrichtung: .right)
        x += spalten[2]

        schreiben(Formatierung.euro(posten.einzelpreis), in: CGRect(x: x, y: y, width: spalten[3], height: 14),
                  schrift: text, farbe: schwarz, ausrichtung: .right)
        x += spalten[3]

        if !kleinunternehmer {
            schreiben(posten.umsatzsteuersatz.bezeichnung,
                      in: CGRect(x: x, y: y, width: spalten[4], height: 14),
                      schrift: text, farbe: grau, ausrichtung: .right)
            x += spalten[4]
        }

        schreiben(Formatierung.euro(posten.netto),
                  in: CGRect(x: x, y: y, width: spalten.last ?? 80, height: 14),
                  schrift: text, farbe: schwarz, ausrichtung: .right)

        strich(y: y + höhe - 3, farbe: UIColor(white: 0.90, alpha: 1))
        return y + höhe
    }

    private static func summen(_ rechnung: Rechnung, ab y: CGFloat) -> CGFloat {
        var zeile = y + 10
        let spalteX = seite.width - randRechts - 220

        func summenzeile(_ bezeichnung: String, _ betrag: Decimal, fett: Bool = false) {
            schreiben(bezeichnung, in: CGRect(x: spalteX, y: zeile, width: 130, height: 14),
                      schrift: fett ? textFett : text, farbe: fett ? schwarz : grau, ausrichtung: .right)
            schreiben(Formatierung.euro(betrag), in: CGRect(x: spalteX + 136, y: zeile, width: 84, height: 14),
                      schrift: fett ? textFett : text, farbe: schwarz, ausrichtung: .right)
            zeile += 15
        }

        if rechnung.kleinunternehmer {
            summenzeile("Gesamtbetrag", rechnung.netto, fett: true)
        } else {
            summenzeile("Nettobetrag", rechnung.netto)
            for satz in rechnung.umsatzsteuerJeSatz {
                summenzeile("Umsatzsteuer \(satz.satz.bezeichnung) auf \(Formatierung.euro(satz.netto))", satz.steuer)
            }
            strich(y: zeile + 1, von: spalteX, bis: seite.width - randRechts)
            zeile += 6
            summenzeile("Gesamtbetrag", rechnung.brutto, fett: true)
        }
        return zeile + 12
    }

    private static func schluss(_ rechnung: Rechnung, ab y: CGFloat) -> CGFloat {
        var zeile = y

        if rechnung.kleinunternehmer {
            // Pflichthinweis: ohne ihn fehlt die Begründung, warum keine Steuer
            // ausgewiesen ist (§ 34a UStDV).
            schreiben("Kein Ausweis von Umsatzsteuer, da Kleinunternehmer nach § 19 UStG.",
                      in: CGRect(x: randLinks, y: zeile, width: breite, height: 14),
                      schrift: text, farbe: schwarz)
            zeile += 18
        }

        // Das Zahlungsziel: entweder der eigene Satz, der von der App, oder gar keiner.
        // Bei Vorkasse oder Lastschrift stünde dort sonst eine Frist, die nicht stimmt.
        if rechnung.zahlungszielZeigen {
            let eigener = rechnung.zahlungshinweis.trimmingCharacters(in: .whitespacesAndNewlines)
            let ziel = eigener.isEmpty
                ? "Zahlbar ohne Abzug bis zum \(Formatierung.datum(rechnung.zahlbarBis))."
                : eigener
            let höhe = (ziel as NSString).boundingRect(
                with: CGSize(width: breite, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: text], context: nil
            ).height
            schreiben(ziel, in: CGRect(x: randLinks, y: zeile, width: breite, height: höhe + 4),
                      schrift: text, farbe: schwarz)
            zeile += max(höhe, 12) + 4
        }

        if !rechnung.absenderBank.isEmpty {
            schreiben(rechnung.absenderBank, in: CGRect(x: randLinks, y: zeile, width: breite, height: 14),
                      schrift: text, farbe: grau)
            zeile += 16
        }

        let fußtext = rechnung.fusstext.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fußtext.isEmpty {
            let höhe = (fußtext as NSString).boundingRect(
                with: CGSize(width: breite, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: text], context: nil
            ).height
            schreiben(fußtext, in: CGRect(x: randLinks, y: zeile + 8, width: breite, height: höhe + 4),
                      schrift: text, farbe: grau)
            zeile += höhe + 14
        }
        return zeile
    }

    private static func fuß(_ rechnung: Rechnung, seitennummer: Int) {
        let y = seite.height - randUnten + 16
        strich(y: y - 8, farbe: linie)

        let links = rechnung.absenderAnschrift.split(separator: "\n").joined(separator: " · ")
        schreiben(links, in: CGRect(x: randLinks, y: y, width: breite * 0.62, height: 12),
                  schrift: klein, farbe: grau)

        var rechts: [String] = []
        if !rechnung.absenderSteuernummer.isEmpty { rechts.append("St.-Nr. " + rechnung.absenderSteuernummer) }
        if !rechnung.absenderUstIdNr.isEmpty { rechts.append(rechnung.absenderUstIdNr) }
        rechts.append("Seite \(seitennummer)")
        schreiben(rechts.joined(separator: " · "),
                  in: CGRect(x: seite.width - randRechts - breite * 0.36, y: y, width: breite * 0.36, height: 12),
                  schrift: klein, farbe: grau, ausrichtung: .right)
    }

    // MARK: - Werkzeug

    private static func spaltenbreiten(kleinunternehmer: Bool) -> [CGFloat] {
        kleinunternehmer
            ? [26, breite - 26 - 62 - 72 - 78, 62, 72, 78]
            : [26, breite - 26 - 58 - 66 - 34 - 76, 58, 66, 34, 76]
    }

    private static func leistungszeitraum(_ rechnung: Rechnung) -> String? {
        guard let von = rechnung.leistungVon else { return nil }
        guard let bis = rechnung.leistungBis, !Calendar.kalender.isDate(von, inSameDayAs: bis) else {
            return Formatierung.datum(von)
        }
        return "\(Formatierung.datum(von)) – \(Formatierung.datum(bis))"
    }

    private static func schreiben(
        _ inhalt: String, in rahmen: CGRect, schrift: UIFont, farbe: UIColor,
        ausrichtung: NSTextAlignment = .left
    ) {
        let absatz = NSMutableParagraphStyle()
        absatz.alignment = ausrichtung
        absatz.lineBreakMode = .byWordWrapping
        (inhalt as NSString).draw(in: rahmen, withAttributes: [
            .font: schrift, .foregroundColor: farbe, .paragraphStyle: absatz,
        ])
    }

    private static func strich(
        y: CGFloat, von: CGFloat? = nil, bis: CGFloat? = nil,
        farbe: UIColor = RechnungPDF.linie
    ) {
        guard let zug = UIGraphicsGetCurrentContext() else { return }
        zug.setStrokeColor(farbe.cgColor)
        zug.setLineWidth(0.5)
        zug.move(to: CGPoint(x: von ?? randLinks, y: y))
        zug.addLine(to: CGPoint(x: bis ?? seite.width - randRechts, y: y))
        zug.strokePath()
    }
}
