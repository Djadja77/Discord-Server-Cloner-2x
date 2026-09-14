import Foundation
import SwiftData

/// Alles, was fuer genau einen Veranlagungszeitraum gilt.
///
/// Je Jahr existiert hoechstens ein Datensatz; `Datenbank.jahresangabenSicherstellen(fuer:in:)` legt ihn
/// beim ersten Zugriff an. Beitraege und Vorauszahlungen aendern sich jaehrlich, deshalb
/// waere ein einziger Satz fuer alle Jahre schlicht falsch.
@Model
final class Jahresangaben {

    /// Veranlagungszeitraum. Eindeutig - pro Jahr gibt es genau einen Datensatz.
    var jahr: Int = Calendar.kalender.component(.year, from: Date())

    /// Einkuenfte, die nicht ueber die Belege erfasst werden
    /// (Arbeitslohn, Vermietung, Kapitalertraege ueber dem Sparerpauschbetrag).
    var weitereEinkuenfte: Decimal = Decimal(0)

    // Vorsorgeaufwendungen
    var beitragAltersvorsorge: Decimal = Decimal(0)
    var beitragKrankenPflegeBasis: Decimal = Decimal(0)
    var beitragSonstigeVersicherungen: Decimal = Decimal(0)

    /// Uebrige Sonderausgaben: Spenden, Kirchensteuer des Vorjahres, Unterhaltsleistungen.
    var weitereSonderausgaben: Decimal = Decimal(0)

    /// Aussergewoehnliche Belastungen nach Abzug der zumutbaren Belastung.
    var aussergewoehnlicheBelastungen: Decimal = Decimal(0)

    /// Bereits geleistete Einkommensteuer-Vorauszahlungen dieses Jahres.
    var geleisteteVorauszahlungen: Decimal = Decimal(0)

    /// Verbleibender Verlustvortrag aus den Vorjahren laut Feststellungsbescheid.
    ///
    /// Bewusst von Hand einzutragen statt aus den App-Daten abgeleitet: massgeblich ist der
    /// gesonderte Feststellungsbescheid des Finanzamts, nicht der hier erfasste Belegbestand.
    var verlustvortragAusVorjahren: Decimal = Decimal(0)

    /// Anzahl der Kinder, fuer die Kindergeld bezogen wird.
    var anzahlKinder: Int = 0

    /// Voller statt halber Kinderfreibetrag bei Einzelveranlagung - etwa wenn der
    /// Freibetrag des anderen Elternteils uebertragen wurde.
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
