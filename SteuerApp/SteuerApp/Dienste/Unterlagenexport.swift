import Foundation
import SwiftData

/// Packt alles zusammen, was die Steuerberatung fuer ein Jahr braucht: beide Auswertungen
/// als CSV und saemtliche Belegfotos.
///
/// Der reine CSV-Export liefert nur Zahlen - die Belege selbst blieben auf dem Geraet.
/// Genau die will das Finanzamt im Zweifel aber sehen, und zehn Jahre lang. Dieses Archiv
/// ist deshalb der eigentliche Abgabestand.
///
/// Die Fotos bekommen sprechende Dateinamen aus Datum, Bezeichnung und Betrag, und die
/// Belegliste fuehrt denselben Namen in einer eigenen Spalte. So laesst sich jede Zeile der
/// Auswertung ohne Suchen dem Papier zuordnen.
///
/// ## Zwei Schritte mit Absicht
/// `bauplan(...)` liest die Datenbank und laeuft deshalb auf dem Hauptstrang.
/// `archivErstellen(...)` fasst nur noch Dateien an und darf nebenher laufen. SwiftData-
/// Objekte sind nicht threadsicher - sie duerfen den Hauptstrang nie verlassen.
enum Unterlagenexport {

    enum Fehler: LocalizedError {
        case archivierenFehlgeschlagen

        var errorDescription: String? {
            switch self {
            case .archivierenFehlgeschlagen:
                "Die Unterlagen konnten nicht zu einem Archiv zusammengefasst werden."
            }
        }
    }

    /// Eine zu kopierende Belegdatei: Name im Belegarchiv, Name im Export.
    struct Fotokopie: Sendable, Equatable {
        let quelle: String
        let ziel: String
    }

    /// Alles, was zum Schreiben des Archivs noetig ist - ohne Datenbankbezug.
    struct Bauplan: Sendable {
        let jahr: Int
        let belegeCsv: String
        let euerCsv: String
        let liesmich: String
        let fotos: [Fotokopie]
    }

    // MARK: - Schritt 1: aus der Datenbank lesen

    @MainActor
    static func bauplan(
        belege: [Beleg],
        euer: EinnahmenUeberschussRechnung.Ergebnis,
        jahr: Int
    ) -> Bauplan {
        let belegeDesJahres = belege.filter { $0.jahr == jahr }
            .sorted { $0.datum < $1.datum }

        var fotos: [Fotokopie] = []
        var namen: [PersistentIdentifier: String] = [:]
        var vergeben = Set<String>()

        for beleg in belegeDesJahres {
            guard let quelle = beleg.belegbildDatei else { continue }
            let name = eindeutigerName(fuer: beleg, bereitsVergeben: &vergeben)
            fotos.append(Fotokopie(quelle: quelle, ziel: name))
            namen[beleg.persistentModelID] = name
        }

        return Bauplan(
            jahr: jahr,
            belegeCsv: CSVExport.belege(belegeDesJahres, jahr: jahr, fotonamen: namen),
            euerCsv: CSVExport.euer(euer),
            liesmich: liesmich(jahr: jahr, belege: belegeDesJahres, euer: euer,
                               anzahlFotos: fotos.count),
            fotos: fotos
        )
    }

    // MARK: - Schritt 2: Dateien schreiben

    /// Erzeugt das ZIP-Archiv und liefert dessen Adresse. Fasst nur Dateien an.
    static func archivErstellen(_ bauplan: Bauplan) throws -> URL {
        let arbeitsordner = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString)", isDirectory: true)
        let inhalt = arbeitsordner
            .appendingPathComponent("Steuerunterlagen-\(bauplan.jahr)", isDirectory: true)
        let belegordner = inhalt.appendingPathComponent("Belege", isDirectory: true)

        try FileManager.default.createDirectory(at: belegordner,
                                                withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: arbeitsordner) }

        if let archivordner = Belegarchiv.verzeichnis {
            for foto in bauplan.fotos {
                // Ein fehlendes Einzelfoto darf den ganzen Export nicht verhindern; die
                // Belegliste weist es weiterhin aus, sodass die Luecke sichtbar bleibt.
                try? FileManager.default.copyItem(
                    at: archivordner.appendingPathComponent(foto.quelle),
                    to: belegordner.appendingPathComponent(foto.ziel)
                )
            }
        }

        try schreiben(bauplan.belegeCsv,
                      nach: inhalt.appendingPathComponent("Belege-\(bauplan.jahr).csv"))
        try schreiben(bauplan.euerCsv,
                      nach: inhalt.appendingPathComponent("EUER-\(bauplan.jahr).csv"))
        try schreiben(bauplan.liesmich,
                      nach: inhalt.appendingPathComponent("Liesmich.txt"))

        return try archivieren(inhalt, name: "Steuerunterlagen-\(bauplan.jahr).zip")
    }

    // MARK: - Dateinamen

    /// `2025-03-14_Ristorante-Bella-Vista_184-60.jpg`
    static func dateiname(fuer beleg: Beleg) -> String {
        let datum = Formatierung.dateinamendatum.string(from: beleg.datum)
        let bezeichnung = dateisicher(beleg.bezeichnung.isEmpty
                                      ? beleg.kategorie.bezeichnung : beleg.bezeichnung)
        return "\(datum)_\(bezeichnung)_\(betragImNamen(beleg.bruttoBetrag)).jpg"
    }

    /// `184-60` statt `184.60` - ueber die Cent gerechnet, damit die Nachkommastellen
    /// unabhaengig von der Darstellung einer `Decimal` immer zweistellig sind.
    static func betragImNamen(_ betrag: Decimal) -> String {
        let cent = NSDecimalNumber(decimal: (betrag * 100).gerundet(stellen: 0)).intValue
        return "\(cent / 100)-\(String(format: "%02d", abs(cent % 100)))"
    }

    /// Zwei Belege am selben Tag mit gleicher Bezeichnung und gleichem Betrag sind selten,
    /// aber moeglich - ohne Zaehler ueberschriebe der zweite den ersten.
    private static func eindeutigerName(
        fuer beleg: Beleg,
        bereitsVergeben: inout Set<String>
    ) -> String {
        var name = dateiname(fuer: beleg)
        if bereitsVergeben.contains(name) {
            let stamm = String(name.dropLast(4))
            var zaehler = 2
            while bereitsVergeben.contains("\(stamm)-\(zaehler).jpg") { zaehler += 1 }
            name = "\(stamm)-\(zaehler).jpg"
        }
        bereitsVergeben.insert(name)
        return name
    }

    /// Umlaute uebersetzen, alles Uebrige auf Buchstaben, Ziffern und Bindestriche reduzieren.
    static func dateisicher(_ text: String) -> String {
        let ersetzt = text
            .replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ü", with: "ue")
            .replacingOccurrences(of: "Ä", with: "Ae")
            .replacingOccurrences(of: "Ö", with: "Oe")
            .replacingOccurrences(of: "Ü", with: "Ue")
            .replacingOccurrences(of: "ß", with: "ss")

        let erlaubt = ersetzt.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        let zusammengefasst = String(erlaubt)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        let gekuerzt = String(zusammengefasst.prefix(40))
        return gekuerzt.isEmpty ? "Beleg" : gekuerzt
    }

    // MARK: - Hilfsmittel

    private static func schreiben(_ inhalt: String, nach adresse: URL) throws {
        try ("\u{FEFF}" + inhalt).write(to: adresse, atomically: true, encoding: .utf8)
    }

    @MainActor
    private static func liesmich(
        jahr: Int,
        belege: [Beleg],
        euer: EinnahmenUeberschussRechnung.Ergebnis,
        anzahlFotos: Int
    ) -> String {
        """
        Steuerunterlagen \(jahr)

        Belege-\(jahr).csv   Alle Belege des Jahres, eine Zeile je Beleg.
                             Die Spalte "Belegdatei" nennt das zugehoerige Foto im Ordner Belege.
        EUER-\(jahr).csv     Jahresauswertung in der Gliederung der Anlage EUER.
        Belege/              Die Belegfotos, benannt nach Datum, Bezeichnung und Betrag.

        Belege insgesamt: \(belege.count), davon mit Foto: \(anzahlFotos)
        Betriebseinnahmen: \(Formatierung.euro(euer.summeEinnahmen))
        Betriebsausgaben:  \(Formatierung.euro(euer.summeAusgaben))
        Gewinn:            \(Formatierung.euro(euer.gewinn))

        Die Auswertung rechnet mit Nettobetraegen. In der Anlage EUER ist die Bruttomethode
        vorgesehen - Umsatzsteuer und Vorsteuer sind beim Uebertragen also zu ergaenzen.

        Erstellt mit der Steuer-App. Ersetzt keine Steuerberatung.
        """
    }

    /// Fasst einen Ordner als ZIP zusammen.
    ///
    /// Ohne fremde Bibliothek: `NSFileCoordinator` schreibt beim Lesen eines Ordners mit der
    /// Option `forUploading` ein ZIP-Archiv - derselbe Weg, den auch die Dateien-App beim
    /// Komprimieren nimmt. Die Datei ist danach nur kurz gueltig, deshalb wird sie sofort
    /// an einen eigenen Platz kopiert.
    private static func archivieren(_ ordner: URL, name: String) throws -> URL {
        let ziel = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: ziel)

        var koordinationsfehler: NSError?
        var kopierfehler: Error?

        NSFileCoordinator().coordinate(
            readingItemAt: ordner,
            options: [.forUploading],
            error: &koordinationsfehler
        ) { archiv in
            do {
                try FileManager.default.copyItem(at: archiv, to: ziel)
            } catch {
                kopierfehler = error
            }
        }

        if let koordinationsfehler { throw koordinationsfehler }
        if let kopierfehler { throw kopierfehler }
        guard FileManager.default.fileExists(atPath: ziel.path) else {
            throw Fehler.archivierenFehlgeschlagen
        }
        return ziel
    }
}
