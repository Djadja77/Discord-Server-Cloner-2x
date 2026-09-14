import Foundation
import SwiftData

/// Aufbau des SwiftData-Containers und Zugriff auf Profil und Jahresangaben.
enum Datenbank {

    static let schema = Schema([
        Beleg.self,
        Steuerprofil.self,
        Jahresangaben.self,
        Wirtschaftsgut.self,
    ])

    /// Container fuer den produktiven Betrieb.
    static func container() -> ModelContainer {
        let konfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: konfiguration)
        } catch {
            // Ein nicht oeffenbarer Store ist nicht sinnvoll zu behandeln: ohne Datenbank
            // gibt es keine App. Der Absturz macht die Ursache im Log sichtbar.
            fatalError("SwiftData-Container konnte nicht geladen werden: \(error)")
        }
    }

    /// Container nur im Arbeitsspeicher - fuer SwiftUI-Vorschauen und Tests.
    static func vorschauContainer(mitBeispieldaten: Bool = true) -> ModelContainer {
        let konfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: konfiguration)
        if mitBeispieldaten {
            beispieldatenAnlegen(in: container.mainContext)
        }
        return container
    }

    // MARK: - Profil und Jahresangaben

    /// Legt das Profil an, falls noch keines existiert.
    ///
    /// Bewusst eine eigene Methode statt eines Zugriffs, der nebenbei anlegt: ein Einfuegen
    /// waehrend des Renderns wuerde SwiftUI mitten im Aufbau der Ansicht zum Neuzeichnen
    /// zwingen. Die Ansichten lesen ueber `@Query` und rufen dies einmal beim Start.
    static func profilSicherstellen(in kontext: ModelContext) {
        let vorhandene = (try? kontext.fetchCount(FetchDescriptor<Steuerprofil>())) ?? 0
        guard vorhandene == 0 else { return }
        kontext.insert(Steuerprofil())
    }

    /// Legt die Jahresangaben fuer das Jahr an, falls sie fehlen.
    static func jahresangabenSicherstellen(fuer jahr: Int, in kontext: ModelContext) {
        let abfrage = FetchDescriptor<Jahresangaben>(
            predicate: #Predicate { $0.jahr == jahr }
        )
        let vorhandene = (try? kontext.fetchCount(abfrage)) ?? 0
        guard vorhandene == 0 else { return }
        kontext.insert(Jahresangaben(jahr: jahr))
    }

    // MARK: - Beispieldaten

    static func beispieldatenAnlegen(in kontext: ModelContext) {
        let jahr = Calendar.kalender.component(.year, from: Date())

        let profil = Steuerprofil()
        profil.taetigkeitsart = .freiberuflich
        kontext.insert(profil)

        let angaben = Jahresangaben(jahr: jahr)
        angaben.beitragKrankenPflegeBasis = 7_200
        angaben.beitragAltersvorsorge = 6_000
        angaben.geleisteteVorauszahlungen = 4_000
        kontext.insert(angaben)

        func datum(_ monat: Int, _ tag: Int, jahr verwendetesJahr: Int? = nil) -> Date {
            Calendar.kalender.date(from: DateComponents(
                year: verwendetesJahr ?? jahr, month: monat, day: tag, hour: 12
            )) ?? Date()
        }

        let beispiele: [Beleg] = [
            Beleg(datum: datum(1, 15), bezeichnung: "Projekt Website Relaunch",
                  bruttoBetrag: 8_330, kategorie: .umsatzerloese),
            Beleg(datum: datum(2, 28), bezeichnung: "Beratung Februar",
                  bruttoBetrag: 5_950, kategorie: .umsatzerloese),
            Beleg(datum: datum(4, 3), bezeichnung: "Workshop Konzeption",
                  bruttoBetrag: 3_570, kategorie: .umsatzerloese),
            Beleg(datum: datum(6, 12), bezeichnung: "Wartungspauschale Q2",
                  bruttoBetrag: 2_380, kategorie: .umsatzerloese),
            Beleg(datum: datum(1, 8), bezeichnung: "Vorsteuer Notebook",
                  bruttoBetrag: 399, kategorie: .sonstigeAusgaben,
                  notiz: "Umsatzsteuer aus der Anschaffung des Notebooks"),
            Beleg(datum: datum(1, 31), bezeichnung: "Coworking Januar",
                  bruttoBetrag: 297.50, kategorie: .raumkosten),
            Beleg(datum: datum(2, 5), bezeichnung: "Mobilfunk und Internet",
                  bruttoBetrag: 79.90, kategorie: .telefonInternet, betrieblicherAnteil: 0.7),
            Beleg(datum: datum(3, 20), bezeichnung: "Fachkonferenz Ticket",
                  bruttoBetrag: 690, kategorie: .fachliteraturFortbildung),
            Beleg(datum: datum(3, 21), bezeichnung: "Bahnfahrt Konferenz",
                  bruttoBetrag: 128.40, kategorie: .reisekosten,
                  umsatzsteuersatz: .ermaessigt),
            Beleg(datum: datum(5, 14), bezeichnung: "Kundenessen Projektabschluss",
                  bruttoBetrag: 184.60, kategorie: .bewirtung,
                  notiz: "Anlass: Abschluss Relaunch, Teilnehmer: 3"),
            Beleg(datum: datum(6, 30), bezeichnung: "Steuerberatung Jahresabschluss",
                  bruttoBetrag: 1_071, kategorie: .rechtsUndSteuerberatung),
            Beleg(datum: datum(7, 1), bezeichnung: "Designsoftware Jahresabo",
                  bruttoBetrag: 659.60, kategorie: .softwareAbos),
        ]
        beispiele.forEach { kontext.insert($0) }

        kontext.insert(Wirtschaftsgut(
            bezeichnung: "Notebook",
            anschaffungsdatum: datum(1, 8),
            anschaffungskostenNetto: 2_100,
            nutzungsdauerJahre: 3,
            notiz: "Arbeitsgeraet, ueber drei Jahre abzuschreiben"
        ))
    }
}
