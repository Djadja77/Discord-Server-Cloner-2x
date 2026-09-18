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

    /// Container für den produktiven Betrieb.
    ///
    /// Wirft, statt abzustürzen. Ein Absturz beim Start sieht auf dem Gerät aus wie
    /// ein schwarzer Bildschirm - man sieht nicht, dass überhaupt etwas schiefging,
    /// geschweige denn was. Der Fehler wird stattdessen angezeigt (siehe
    /// `Startfehleransicht`), damit er ablesbar ist statt geraten werden muss.
    static func container() throws -> ModelContainer {
        let konfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try ModelContainer(for: schema, configurations: konfiguration)
    }

    /// Container nur im Arbeitsspeicher - für SwiftUI-Vorschauen und Tests.
    ///
    /// `@MainActor`, weil `mainContext` an den Hauptstrang gebunden ist. Aufgerufen wird
    /// die Methode ausschließlich aus `#Preview`-Blöcken, und die laufen ohnehin dort.
    @MainActor
    static func vorschauContainer(mitBeispieldaten: Bool = true) -> ModelContainer {
        let konfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: konfiguration)
        if mitBeispieldaten {
            beispieldatenAnlegen(in: container.mainContext)
        }
        return container
    }

    // MARK: - Profil und Jahresangaben

    /// Löscht alles, was der Nutzer erfasst hat: Belege samt Fotos, Anlagen,
    /// Jahresangaben und das Profil.
    ///
    /// Bisher gab es dafür nur einen Weg - die App vom Gerät löschen. Das ist keiner:
    /// wer die App mit Probebelegen ausprobiert hat, soll aufräumen können, ohne sie
    /// neu installieren und alles neu einrichten zu müssen.
    ///
    /// Die Fotos gehen zuerst, solange die Belege noch da sind. Andersherum wüsste
    /// hinterher niemand mehr, welche Dateien zu welchem Beleg gehörten - sie blieben
    /// als Altlast im Archiv liegen.
    static func allesLöschen(in kontext: ModelContext) {
        let belege = (try? kontext.fetch(FetchDescriptor<Beleg>())) ?? []
        for beleg in belege {
            if let datei = beleg.belegbildDatei { Belegarchiv.löschen(datei) }
        }

        for beleg in belege { kontext.delete(beleg) }
        for gut in (try? kontext.fetch(FetchDescriptor<Wirtschaftsgut>())) ?? [] {
            kontext.delete(gut)
        }
        for angaben in (try? kontext.fetch(FetchDescriptor<Jahresangaben>())) ?? [] {
            kontext.delete(angaben)
        }
        for profil in (try? kontext.fetch(FetchDescriptor<Steuerprofil>())) ?? [] {
            kontext.delete(profil)
        }

        try? kontext.save()
    }

    /// Legt das Profil an, falls noch keines existiert.
    ///
    /// Bewusst eine eigene Methode statt eines Zugriffs, der nebenbei anlegt: ein Einfügen
    /// während des Renderns würde SwiftUI mitten im Aufbau der Ansicht zum Neuzeichnen
    /// zwingen. Die Ansichten lesen über `@Query` und rufen dies einmal beim Start.
    static func profilSicherstellen(in kontext: ModelContext) {
        let vorhandene = (try? kontext.fetchCount(FetchDescriptor<Steuerprofil>())) ?? 0
        guard vorhandene == 0 else { return }
        kontext.insert(Steuerprofil())
    }

    /// Legt die Jahresangaben für das Jahr an, falls sie fehlen.
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
        profil.tätigkeitsart = .freiberuflich
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
                  bruttoBetrag: 8_330, kategorie: .umsatzerlöse),
            Beleg(datum: datum(2, 28), bezeichnung: "Beratung Februar",
                  bruttoBetrag: 5_950, kategorie: .umsatzerlöse),
            Beleg(datum: datum(4, 3), bezeichnung: "Workshop Konzeption",
                  bruttoBetrag: 3_570, kategorie: .umsatzerlöse),
            Beleg(datum: datum(6, 12), bezeichnung: "Wartungspauschale Q2",
                  bruttoBetrag: 2_380, kategorie: .umsatzerlöse),
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
            notiz: "Arbeitsgerät, über drei Jahre abzuschreiben"
        ))
    }
}
