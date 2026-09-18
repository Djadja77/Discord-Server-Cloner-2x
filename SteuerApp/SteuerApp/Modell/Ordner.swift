import Foundation
import SwiftData

/// Eine Mappe für Rechnungen.
///
/// Wofür sie steht, entscheidet der Nutzer: ein Kunde, ein Projekt, ein Standbein.
/// Deshalb gibt es keine vorgegebenen Ordner und keine Pflicht, einen zu wählen -
/// Rechnungen ohne Ordner sind kein Fehlerzustand, sondern der Normalfall am Anfang.
///
/// - Note: Gespeicherte Eigenschaften ohne Umlaute, siehe `Steuerprofil`.
@Model
final class Ordner {

    var name: String = ""
    /// Index in `Ordner.farben` - eine Zahl statt einer Farbe, damit die Datenbank
    /// nichts über die Gestaltung weiß.
    var farbindex: Int = 0
    var reihenfolge: Int = 0
    var angelegtAm: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Rechnung.ordner)
    var rechnungen: [Rechnung]? = []

    init(name: String = "", farbindex: Int = 0, reihenfolge: Int = 0) {
        self.name = name
        self.farbindex = farbindex
        self.reihenfolge = reihenfolge
        self.angelegtAm = Date()
        self.rechnungen = []
    }

    /// Die Auswahl, aus der ein Ordner seine Farbe bekommt.
    ///
    /// Sechs reichen: bei mehr unterscheidet man sie ohnehin nicht mehr auseinander,
    /// und der Name steht ja daneben.
    static let farbanzahl = 6
}
