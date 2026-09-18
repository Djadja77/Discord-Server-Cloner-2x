import Foundation

/// Schlaegt anhand des Händlernamens eine Belegkategorie vor.
///
/// Eine Heuristik, keine Zuordnungsregel: Die Tabelle deckt häufige deutsche Anbieter ab
/// und trifft damit den Großteil der Alltagsbelege. Was sie nicht kennt, landet in der
/// Standardkategorie und wird von Hand gesetzt. Der Vorschlag ist immer überschreibbar -
/// eine falsche Kategorie kostet im Zweifel Betriebsausgaben, deshalb wird nie geraten,
/// wo die Tabelle nichts hergibt.
enum Kategorievorschlag {

    /// Stichwort und zugehörige Kategorie. Die Reihenfolge entscheidet bei mehreren
    /// Treffern - spezifische Begriffe stehen deshalb vor allgemeinen.
    ///
    /// Verglichen wird auf Teilzeichenketten, nicht auf ganze Wörter. Kurze Stichworte
    /// tragen deshalb ein führendes Leerzeichen, wo sie sonst in anderen Wörtern
    /// steckten: " esso" darf nicht auf "Espresso" anspringen und " uber" nicht auf "Huber".
    /// `KategorievorschlagTests` prüft genau diese Fälle.
    static let zuordnungen: [(stichwort: String, kategorie: Belegkategorie)] = [
        // Fahrt und Reise
        ("deutsche bahn", .reisekosten), ("db vertrieb", .reisekosten), ("flixbus", .reisekosten), ("lufthansa", .reisekosten), ("eurowings", .reisekosten),
        ("ryanair", .reisekosten), ("hotel", .reisekosten), ("motel", .reisekosten),
        ("pension", .reisekosten), ("airbnb", .reisekosten), ("booking", .reisekosten),
        ("taxi", .reisekosten), (" uber", .reisekosten), ("verkehrsbetriebe", .reisekosten),

        // Fahrzeug
        ("tankstelle", .kfzKosten), ("shell", .kfzKosten), ("aral", .kfzKosten),
        (" esso", .kfzKosten), ("total energies", .kfzKosten), ("jet ", .kfzKosten),
        ("autohaus", .kfzKosten), ("werkstatt", .kfzKosten), ("adac", .kfzKosten),
        ("dekra", .kfzKosten), ("tuev", .kfzKosten), ("sixt", .kfzKosten),
        ("europcar", .kfzKosten), ("parkhaus", .kfzKosten),

        // Bewirtung
        ("restaurant", .bewirtung), ("gasthaus", .bewirtung), ("gaststaette", .bewirtung),
        ("pizzeria", .bewirtung), ("trattoria", .bewirtung), ("brauhaus", .bewirtung),
        ("bistro", .bewirtung), ("ristorante", .bewirtung), ("wirtshaus", .bewirtung),

        // Kommunikation
        ("telekom", .telefonInternet), ("vodafone", .telefonInternet),
        ("o2 ", .telefonInternet), ("telefonica", .telefonInternet),
        ("congstar", .telefonInternet), ("1&1", .telefonInternet),

        // Software und Abonnements
        ("adobe", .softwareAbos), ("microsoft", .softwareAbos), ("apple", .softwareAbos),
        ("google", .softwareAbos), ("jetbrains", .softwareAbos), ("github", .softwareAbos),
        ("figma", .softwareAbos), ("notion", .softwareAbos), ("slack", .softwareAbos),
        ("zoom", .softwareAbos), ("dropbox", .softwareAbos), ("atlassian", .softwareAbos),
        ("hetzner", .softwareAbos), ("ionos", .softwareAbos), ("strato", .softwareAbos),

        // Büro und Versand
        ("mcpaper", .bürobedarf), ("staples", .bürobedarf), ("viking", .bürobedarf),
        ("schreibwaren", .bürobedarf), ("bürobedarf", .bürobedarf),
        ("dhl", .portoVersand), ("deutsche post", .portoVersand), ("hermes", .portoVersand),
        ("dpd", .portoVersand), ("gls", .portoVersand), (" ups ", .portoVersand),

        // Fortbildung
        ("buchhandlung", .fachliteraturFortbildung), ("thalia", .fachliteraturFortbildung),
        ("hugendubel", .fachliteraturFortbildung), ("udemy", .fachliteraturFortbildung),
        ("springer", .fachliteraturFortbildung), ("akademie", .fachliteraturFortbildung),
        ("seminar", .fachliteraturFortbildung), ("konferenz", .fachliteraturFortbildung),

        // Raum
        ("coworking", .raumkosten), ("wework", .raumkosten), ("mindspace", .raumkosten),
        ("regus", .raumkosten),

        // Beratung und Bank
        ("steuerberat", .rechtsUndSteuerberatung), ("rechtsanwalt", .rechtsUndSteuerberatung),
        ("kanzlei", .rechtsUndSteuerberatung), ("notariat", .rechtsUndSteuerberatung),
        ("datev", .rechtsUndSteuerberatung),
        ("sparkasse", .bankgebühren), ("volksbank", .bankgebühren),
        ("commerzbank", .bankgebühren), ("deutsche bank", .bankgebühren),
        ("holvi", .bankgebühren), ("qonto", .bankgebühren),

        // Versicherung
        ("versicherung", .versicherungenBeiträge), ("allianz", .versicherungenBeiträge),
        ("hiscox", .versicherungenBeiträge), ("huk", .versicherungenBeiträge),
        ("ihk", .versicherungenBeiträge), ("berufsgenossenschaft", .versicherungenBeiträge),
    ]

    /// Kategorie zu einem Händlernamen, ergaenzt um den übrigen Belegtext.
    ///
    /// Der Händlername wiegt schwerer: ein Beleg von "Ristorante Bella Vista" ist Bewirtung,
    /// auch wenn weiter unten das Wort "Hotel" auftaucht.
    static func fuer(händler: String?, zeilen: [String] = []) -> Belegkategorie? {
        if let händler, let treffer = kategorie(in: händler) { return treffer }
        // Im übrigen Text nur die ersten Zeilen beruecksichtigen - weiter unten stehen
        // Artikelbezeichnungen, die in die Irre führen.
        return kategorie(in: zeilen.prefix(4).joined(separator: " "))
    }

    static func kategorie(in text: String) -> Belegkategorie? {
        let klein = " " + text.lowercased()
            .replacingOccurrences(of: "ü", with: "ue")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ß", with: "ss") + " "
        return zuordnungen.first { klein.contains($0.stichwort) }?.kategorie
    }
}
