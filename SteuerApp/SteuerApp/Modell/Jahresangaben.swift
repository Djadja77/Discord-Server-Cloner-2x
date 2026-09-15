import Foundation
import SwiftData

/// Alles, was für genau einen Veranlagungszeitraum gilt.
///
/// Je Jahr existiert höchstens ein Datensatz; `Datenbank.jahresangabenSicherstellen(fuer:in:)` legt ihn
/// beim ersten Zugriff an. Beiträge und Vorauszahlungen ändern sich jährlich, deshalb
/// wäre ein einziger Satz für alle Jahre schlicht falsch.
///
/// - Note: Die Namen der gespeicherten Eigenschaften bleiben ohne Umlaute - siehe
///   `Steuerprofil`.
@Model
final class Jahresangaben {

    /// Veranlagungszeitraum. Eindeutig - pro Jahr gibt es genau einen Datensatz.
    var jahr: Int = Calendar.kalender.component(.year, from: Date())

    /// Einkünfte, die nicht über die Belege erfasst werden
    /// (Arbeitslohn, Vermietung, Kapitalerträge über dem Sparerpauschbetrag).
    var weitereEinkuenfte: Decimal = Decimal(0)

    // Vorsorgeaufwendungen
    var beitragAltersvorsorge: Decimal = Decimal(0)
    var beitragKrankenPflegeBasis: Decimal = Decimal(0)
    var beitragSonstigeVersicherungen: Decimal = Decimal(0)

    /// Übrige Sonderausgaben: Spenden, Kirchensteuer des Vorjahres, Unterhaltsleistungen.
    var weitereSonderausgaben: Decimal = Decimal(0)

    /// Außergewöhnliche Belastungen nach Abzug der zumutbaren Belastung.
    var aussergewoehnlicheBelastungen: Decimal = Decimal(0)

    /// Bereits geleistete Einkommensteuer-Vorauszahlungen dieses Jahres.
    var geleisteteVorauszahlungen: Decimal = Decimal(0)

    /// Verbleibender Verlustvortrag aus den Vorjahren laut Feststellungsbescheid.
    ///
    /// Bewusst von Hand einzutragen statt aus den App-Daten abgeleitet: maßgeblich ist der
    /// gesonderte Feststellungsbescheid des Finanzamts, nicht der hier erfasste Belegbestand.
    var verlustvortragAusVorjahren: Decimal = Decimal(0)

    /// Anzahl der Kinder, für die Kindergeld bezogen wird.
    var anzahlKinder: Int = 0

    /// Voller statt halber Kinderfreibetrag bei Einzelveranlagung - etwa wenn der
    /// Freibetrag des anderen Elternteils übertragen wurde.
    var vollerKinderfreibetrag: Bool = false

    init(jahr: Int) {
        self.jahr = jahr
    }

    var vorsorgeaufwendungen: Vorsorgeaufwendungen {
        Vorsorgeaufwendungen(
            altersvorsorge: beitragAltersvorsorge,
            krankenUndPflegeBasis: beitragKrankenPflegeBasis,
            sonstigeVersicherungen: beitragSonstigeVersicherungen
        )
    }
}
