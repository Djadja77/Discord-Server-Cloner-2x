import Foundation
import SwiftData

/// Ein Rechnungsempfänger.
///
/// Einmal erfasst, danach nur noch ausgewählt. Die Anschrift steht deshalb hier und
/// nicht in der Rechnung - eine Rechnung übernimmt sie beim Stellen als Abschrift
/// (siehe `Rechnung`), damit eine spätere Adressänderung alte Rechnungen nicht ändert.
///
/// - Note: Die gespeicherten Eigenschaften tragen bewusst keine Umlaute. SwiftData legt
///   sie als Feldnamen in der Datenbank ab, und ein `ä` darin bringt den Aufbau des
///   Containers zum Absturz.
@Model
final class Kunde {

    var name: String = ""
    /// Zweite Zeile - Abteilung, Ansprechpartner, "z. Hd.".
    var zusatz: String = ""
    var strasse: String = ""
    var plz: String = ""
    var ort: String = ""
    /// Leer bedeutet Deutschland; nur ausländische Anschriften nennen das Land.
    var land: String = ""

    var ustIdNr: String = ""

    /// Nur für öffentliche Auftraggeber: ohne diese Kennung nimmt keine Behörde eine
    /// elektronische Rechnung an.
    var leitwegId: String = ""

    /// Tage bis zur Fälligkeit. Vorbelegung für jede Rechnung an diesen Kunden.
    var zahlungszielTage: Int = 14

    var notiz: String = ""
    var angelegtAm: Date = Date()

    init(
        name: String = "",
        zusatz: String = "",
        strasse: String = "",
        plz: String = "",
        ort: String = "",
        land: String = "",
        ustIdNr: String = "",
        leitwegId: String = "",
        zahlungszielTage: Int = 14,
        notiz: String = ""
    ) {
        self.name = name
        self.zusatz = zusatz
        self.strasse = strasse
        self.plz = plz
        self.ort = ort
        self.land = land
        self.ustIdNr = ustIdNr
        self.leitwegId = leitwegId
        self.zahlungszielTage = zahlungszielTage
        self.notiz = notiz
        self.angelegtAm = Date()
    }

    /// Die Anschrift als Zeilen, leere Angaben fallen weg.
    var anschriftszeilen: [String] {
        [name, zusatz, strasse, [plz, ort].filter { !$0.isEmpty }.joined(separator: " "), land]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var anschrift: String { anschriftszeilen.joined(separator: "\n") }

    /// Ob genug dasteht, um eine Rechnung zu stellen.
    ///
    /// Name und Anschrift des Empfängers sind Pflichtangaben (§ 14 Abs. 4 Nr. 1 UStG);
    /// ohne sie ist die Rechnung formell falsch und der Kunde darf die Vorsteuer nicht
    /// ziehen.
    var istVollständig: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !strasse.trimmingCharacters(in: .whitespaces).isEmpty
            && !ort.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
