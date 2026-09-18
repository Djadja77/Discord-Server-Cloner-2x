import Foundation
import SwiftData

/// Rechtsform der Tätigkeit - entscheidet über die Gewerbesteuer.
enum Tätigkeitsart: String, CaseIterable, Codable, Identifiable, Sendable {
    /// § 18 EStG - keine Gewerbesteuer.
    case freiberuflich
    /// § 15 EStG - Gewerbesteuer ab einem Gewinn von 24.500 Euro.
    case gewerblich

    var id: String { rawValue }

    var bezeichnung: String {
        switch self {
        case .freiberuflich: "Freiberuflich (§ 18 EStG)"
        case .gewerblich: "Gewerbebetrieb (§ 15 EStG)"
        }
    }
}

enum Veranlagungsart: String, CaseIterable, Codable, Identifiable, Sendable {
    case einzel
    case zusammen

    var id: String { rawValue }

    var bezeichnung: String {
        switch self {
        case .einzel: "Einzelveranlagung"
        case .zusammen: "Zusammenveranlagung (Splitting)"
        }
    }

    var splitting: Bool { self == .zusammen }
}

/// Angaben, die sich von Jahr zu Jahr nicht ändern.
///
/// Alles, was jährlich neu ist - Beiträge, Vorauszahlungen, Kinder, Verlustvortrag -
/// steht in `Jahresangaben`. Diese Trennung ist der Grund, warum ein Wechsel des
/// Steuerjahres in der App nicht die Zahlen des Vorjahres überschreibt.
///
/// - Note: Die Namen der gespeicherten Eigenschaften bleiben ohne Umlaute. SwiftData legt
///   sie als Feldnamen in der Datenbank ab, und dort gehören nur ASCII-Zeichen hin -
///   ein `ä` im Feldnamen bringt den Aufbau des Containers zum Absturz. Alles, was auf dem
///   Bildschirm erscheint, trägt dagegen selbstverständlich Umlaute.
@Model
final class Steuerprofil {

    var taetigkeitsartCode: String = Tätigkeitsart.freiberuflich.rawValue
    var veranlagungsartCode: String = Veranlagungsart.einzel.rawValue
    var kirchensteuersatzCode: String = Kirchensteuersatz.keine.rawValue

    /// § 19 UStG: keine Umsatzsteuer auf Rechnungen, dafür auch kein Vorsteuerabzug.
    var kleinunternehmer: Bool = false

    /// Gewerbesteuer-Hebesatz der Gemeinde in Prozent (nur bei gewerblicher Tätigkeit).
    var gewerbesteuerHebesatz: Decimal = Decimal(400)

    // MARK: - Angaben für ausgehende Rechnungen
    //
    // Diese Felder stehen auf jeder Rechnung, die die App erzeugt. Name, Anschrift und
    // Steuernummer sind Pflichtangaben (§ 14 Abs. 4 Nr. 1 und 2 UStG) - ohne sie darf
    // der Empfänger die Vorsteuer nicht ziehen, und die Rechnung kommt zurück.

    var absenderName: String = ""
    var absenderStrasse: String = ""
    var absenderPlz: String = ""
    var absenderOrt: String = ""
    var steuernummer: String = ""
    var ustIdNr: String = ""

    var bankName: String = ""
    var iban: String = ""
    var bic: String = ""

    /// Vorbelegung für neue Rechnungen, in Tagen.
    var zahlungszielTage: Int = 14
    /// Fester Text unter den Positionen - Dank, Hinweis auf Skonto, Bezug zum Auftrag.
    var rechnungsfusstext: String = ""

    /// Stand des Nummernkreises je Jahr, als "2026:42" getrennt durch Semikolon.
    ///
    /// Bewusst eine Zeichenkette und kein eigenes Modell: der Kreis ist ein einzelner
    /// Zähler, den nur `Rechnungsnummer` anfasst. Ein eigenes Modell dafür wäre eine
    /// Tabelle mit einer Zeile.
    var nummernkreis: String = ""

    init() {}

    var tätigkeitsart: Tätigkeitsart {
        get { Tätigkeitsart(rawValue: taetigkeitsartCode) ?? .freiberuflich }
        set { taetigkeitsartCode = newValue.rawValue }
    }

    var veranlagungsart: Veranlagungsart {
        get { Veranlagungsart(rawValue: veranlagungsartCode) ?? .einzel }
        set { veranlagungsartCode = newValue.rawValue }
    }

    /// Die eigene Anschrift als Zeilen, leere Angaben fallen weg.
    var absenderzeilen: [String] {
        [absenderName, absenderStrasse, [absenderPlz, absenderOrt].filter { !$0.isEmpty }.joined(separator: " ")]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Bankverbindung als eine Zeile für den Fuß der Rechnung.
    var bankzeile: String {
        [bankName, iban.isEmpty ? "" : "IBAN " + iban, bic.isEmpty ? "" : "BIC " + bic]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// Was fehlt, bevor sich überhaupt eine Rechnung stellen lässt.
    var rechnungsHindernisse: [String] {
        var fehlt: [String] = []
        if absenderName.trimmingCharacters(in: .whitespaces).isEmpty { fehlt.append("Dein Name") }
        if absenderStrasse.trimmingCharacters(in: .whitespaces).isEmpty
            || absenderOrt.trimmingCharacters(in: .whitespaces).isEmpty {
            fehlt.append("Deine Anschrift")
        }
        if steuernummer.trimmingCharacters(in: .whitespaces).isEmpty
            && ustIdNr.trimmingCharacters(in: .whitespaces).isEmpty {
            fehlt.append("Steuernummer oder USt-IdNr.")
        }
        return fehlt
    }

    var kirchensteuersatz: Kirchensteuersatz {
        get { Kirchensteuersatz(rawValue: kirchensteuersatzCode) ?? .keine }
        set { kirchensteuersatzCode = newValue.rawValue }
    }
}
