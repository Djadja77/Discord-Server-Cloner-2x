import Foundation
import UIKit

/// Ablage der Belegfotos im Dateisystem.
///
/// Die Bilder liegen bewusst **nicht** in der SwiftData-Datenbank: als externe Dateien
/// bleibt die Datenbank klein und schnell, und ein Beleg laesst sich einzeln exportieren.
/// Das Verzeichnis liegt in "Application Support" und ist damit vom Backup erfasst, aber
/// fuer den Nutzer nicht sichtbar.
enum Belegarchiv {

    enum Fehler: LocalizedError {
        case verzeichnisNichtVerfuegbar
        case bildKonnteNichtKodiertWerden

        var errorDescription: String? {
            switch self {
            case .verzeichnisNichtVerfuegbar: "Das Belegarchiv konnte nicht geoeffnet werden."
            case .bildKonnteNichtKodiertWerden: "Das Belegfoto konnte nicht gespeichert werden."
            }
        }
    }

    static var verzeichnis: URL? {
        guard let basis = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return nil }

        let ordner = basis.appendingPathComponent("Belege", isDirectory: true)
        if !FileManager.default.fileExists(atPath: ordner.path) {
            try? FileManager.default.createDirectory(
                at: ordner, withIntermediateDirectories: true
            )
        }
        return ordner
    }

    /// Speichert ein Belegfoto als JPEG und liefert den Dateinamen zurueck.
    @discardableResult
    static func speichern(_ bild: UIImage) throws -> String {
        guard let ordner = verzeichnis else { throw Fehler.verzeichnisNichtVerfuegbar }
        guard let daten = bild.jpegData(compressionQuality: 0.8) else {
            throw Fehler.bildKonnteNichtKodiertWerden
        }
        let dateiname = "\(UUID().uuidString).jpg"
        try daten.write(to: ordner.appendingPathComponent(dateiname), options: .atomic)
        return dateiname
    }

    static func laden(_ dateiname: String) -> UIImage? {
        guard let ordner = verzeichnis else { return nil }
        return UIImage(contentsOfFile: ordner.appendingPathComponent(dateiname).path)
    }

    static func loeschen(_ dateiname: String) {
        guard let ordner = verzeichnis else { return }
        try? FileManager.default.removeItem(at: ordner.appendingPathComponent(dateiname))
    }
}
