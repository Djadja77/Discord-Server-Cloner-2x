import Foundation

/// Alle jahresabhängigen Steuerparameter an genau einer Stelle.
///
/// ## Pflege der Werte
/// Die Zahlen ändern sich jedes Jahr. Wenn ein neues Jahr gebraucht wird, genügt es,
/// unten einen weiteren `Steuerjahr`-Eintrag anzulegen - der Rest der App zieht automatisch nach.
/// `SteuerjahrKonsistenzTests` prüft jeden Eintrag gegen die im Tarif eingebauten
/// Stützstellen (Eckwerte der Grenzsteuersätze) und meldet Tippfehler.
///
/// ## Herkunft der Werte
/// Die Tarifkonstanten aller drei Jahre sind gegen den Wortlaut des § 32a Abs. 1 EStG
/// abgeglichen, für 2025 zusätzlich gegen das amtliche Einkommensteuer-Handbuch des
/// Bundesfinanzministeriums. `SteuerjahrTarifwerteTests` hält sie fest: wer hier eine
/// Zahl ändert, muss den Test mitändern und stolpert dabei über die Quellenangabe.
///
/// - Important: Die Höchstbeträge der Altersvorsorge folgen der Beitragsbemessungsgrenze
///   der knappschaftlichen Rentenversicherung und ändern sich jährlich. Für 2024 ist der
///   Wert aus der Bemessungsgrundlage abgeleitet und nicht gegen eine amtliche Quelle
///   geprüft - siehe README, Abschnitt "Stand der Prüfung".
struct Steuerjahr: Identifiable, Hashable, Sendable {

    // MARK: - Einkommensteuertarif (§ 32a Abs. 1 EStG)

    /// Die fünf Tarifzonen des Einkommensteuertarifs.
    struct Tarif: Hashable, Sendable {
        /// Zone 1 - bis einschließlich dieses Betrags fällt keine Steuer an.
        let grundfreibetrag: Decimal
        /// Obergrenze der ersten Progressionszone.
        let endeZone2: Decimal
        /// Obergrenze der zweiten Progressionszone (danach 42 % Grenzsteuersatz).
        let endeZone3: Decimal
        /// Obergrenze der Proportionalzone (danach 45 %, sog. "Reichensteuer").
        let endeZone4: Decimal

        /// Progressionsfaktor Zone 2: ESt = (faktorZone2 * y + 1400) * y
        let faktorZone2: Double
        /// Progressionsfaktor Zone 3: ESt = (faktorZone3 * z + 2397) * z + sockelZone3
        let faktorZone3: Double
        /// Konstanter Sockelbetrag der Zone 3.
        let sockelZone3: Double
        /// Abzugsbetrag der Zone 4: ESt = 0,42 * zvE - abzugZone4
        let abzugZone4: Double
        /// Abzugsbetrag der Zone 5: ESt = 0,45 * zvE - abzugZone5
        let abzugZone5: Double
    }

    // MARK: - Weitere Parameter

    /// Freigrenze des Solidaritaetszuschlags bei Einzelveranlagung (§ 3 SolZG).
    /// Bei Zusammenveranlagung gilt der doppelte Betrag.
    let soliFreigrenze: Decimal

    /// Höchstbetrag der Altersvorsorgeaufwendungen (§ 10 Abs. 3 EStG), Einzelveranlagung.
    let höchstbetragAltersvorsorge: Decimal

    /// Höchstbetrag der sonstigen Vorsorgeaufwendungen (§ 10 Abs. 4 EStG) für
    /// Selbständige, die ihre Krankenversicherung allein tragen.
    let höchstbetragSonstigeVorsorge: Decimal

    /// Sonderausgaben-Pauschbetrag (§ 10c EStG), Einzelveranlagung.
    let sonderausgabenPauschbetrag: Decimal

    /// Gewerbesteuerlicher Freibetrag für natürliche Personen (§ 11 Abs. 1 Nr. 1 GewStG).
    let gewerbesteuerFreibetrag: Decimal

    /// Kinderfreibetrag je Kind für beide Elternteile zusammen (§ 32 Abs. 6 EStG).
    let kinderfreibetrag: Decimal

    /// Freibetrag für Betreuung, Erziehung und Ausbildung je Kind, beide Elternteile.
    let betreuungsfreibetrag: Decimal

    /// Kindergeld je Kind und Monat - Vergleichsgröße der Günstigerprüfung (§ 31 EStG).
    let kindergeldProMonat: Decimal

    /// Sockelbetrag des Verlustvortrags bei Einzelveranlagung (§ 10d Abs. 2 EStG).
    /// Bis hierher ist der Verlustabzug unbeschränkt.
    let verlustvortragSockelbetrag: Decimal

    /// Anteil des den Sockelbetrag übersteigenden Gesamtbetrags der Einkünfte, der
    /// zusätzlich mit Verlusten verrechnet werden darf (sog. Mindestbesteuerung).
    /// Für die Veranlagungszeiträume 2024 bis 2027 auf 70 % angehoben, davor und danach 60 %.
    let verlustvortragQuote: Decimal

    /// Grenze für geringwertige Wirtschaftsgüter (§ 6 Abs. 2 EStG), netto.
    /// Bis zu diesem Betrag sind Anschaffungen sofort abziehbar statt abzuschreiben.
    let grenzeGeringwertigeWirtschaftsgüter: Decimal

    let jahr: Int
    let tarif: Tarif
    /// `false` = Werte noch nicht gegen die amtliche Tabelle geprüft; die App weist darauf hin.
    let amtlichGeprüft: Bool

    var id: Int { jahr }

    // MARK: - Hinterlegte Jahre

    static let jahr2024 = Steuerjahr(
        soliFreigrenze: 18_130,
        höchstbetragAltersvorsorge: 27_566,
        höchstbetragSonstigeVorsorge: 2_800,
        sonderausgabenPauschbetrag: 36,
        gewerbesteuerFreibetrag: 24_500,
        kinderfreibetrag: 6_612,
        betreuungsfreibetrag: 2_928,
        kindergeldProMonat: 250,
        verlustvortragSockelbetrag: 1_000_000,
        verlustvortragQuote: Decimal(70) / 100,
        grenzeGeringwertigeWirtschaftsgüter: 800,
        jahr: 2024,
        tarif: Tarif(
            grundfreibetrag: 11_784,
            endeZone2: 17_005,
            endeZone3: 66_760,
            endeZone4: 277_825,
            faktorZone2: 954.80,
            faktorZone3: 181.19,
            sockelZone3: 991.21,
            abzugZone4: 10_636.31,
            abzugZone5: 18_971.06
        ),
        amtlichGeprüft: true
    )

    static let jahr2025 = Steuerjahr(
        soliFreigrenze: 19_950,
        höchstbetragAltersvorsorge: 29_344,
        höchstbetragSonstigeVorsorge: 2_800,
        sonderausgabenPauschbetrag: 36,
        gewerbesteuerFreibetrag: 24_500,
        kinderfreibetrag: 6_672,
        betreuungsfreibetrag: 2_928,
        kindergeldProMonat: 255,
        verlustvortragSockelbetrag: 1_000_000,
        verlustvortragQuote: Decimal(70) / 100,
        grenzeGeringwertigeWirtschaftsgüter: 800,
        jahr: 2025,
        tarif: Tarif(
            grundfreibetrag: 12_096,
            endeZone2: 17_443,
            endeZone3: 68_480,
            endeZone4: 277_825,
            faktorZone2: 932.30,
            faktorZone3: 176.64,
            sockelZone3: 1_015.13,
            abzugZone4: 10_911.92,
            abzugZone5: 19_246.67
        ),
        amtlichGeprüft: true
    )

    static let jahr2026 = Steuerjahr(
        soliFreigrenze: 20_350,
        höchstbetragAltersvorsorge: 30_826,
        höchstbetragSonstigeVorsorge: 2_800,
        sonderausgabenPauschbetrag: 36,
        gewerbesteuerFreibetrag: 24_500,
        kinderfreibetrag: 6_828,
        betreuungsfreibetrag: 2_928,
        kindergeldProMonat: 259,
        verlustvortragSockelbetrag: 1_000_000,
        verlustvortragQuote: Decimal(70) / 100,
        grenzeGeringwertigeWirtschaftsgüter: 800,
        jahr: 2026,
        tarif: Tarif(
            grundfreibetrag: 12_348,
            endeZone2: 17_799,
            endeZone3: 69_878,
            endeZone4: 277_825,
            faktorZone2: 914.51,
            faktorZone3: 173.10,
            sockelZone3: 1_034.87,
            abzugZone4: 11_135.63,
            abzugZone5: 19_470.38
        ),
        amtlichGeprüft: true
    )

    static let alle: [Steuerjahr] = [jahr2024, jahr2025, jahr2026]

    /// Voller Kinderfreibetrag einschließlich Betreuungsanteil, je Kind und beide Elternteile.
    var kinderfreibetragGesamt: Decimal { kinderfreibetrag + betreuungsfreibetrag }

    /// Kindergeldanspruch je Kind und Jahr.
    var kindergeldProJahr: Decimal { kindergeldProMonat * 12 }

    /// Liefert das hinterlegte Jahr - oder das nächstgelegene, wenn das Jahr fehlt.
    /// So bleibt die App auch 2027 bedienbar, statt abzustuerzen.
    static func fuer(_ jahr: Int) -> Steuerjahr {
        if let treffer = alle.first(where: { $0.jahr == jahr }) { return treffer }
        return alle.min { abs($0.jahr - jahr) < abs($1.jahr - jahr) } ?? jahr2025
    }
}
