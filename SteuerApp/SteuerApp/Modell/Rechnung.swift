import Foundation
import SwiftData

/// Wo eine Rechnung in ihrem Leben steht.
enum Rechnungsstatus: String, CaseIterable, Codable, Identifiable, Sendable {
    /// Noch nicht gestellt - darf beliebig geändert und gelöscht werden.
    case entwurf
    /// Gestellt und verschickt, Zahlung steht aus. Ab hier ist sie unveränderlich.
    case offen
    case bezahlt
    /// Durch eine Stornorechnung aufgehoben. Bleibt bestehen, wird nie gelöscht.
    case storniert

    var id: String { rawValue }

    var bezeichnung: String {
        switch self {
        case .entwurf: "Entwurf"
        case .offen: "Offen"
        case .bezahlt: "Bezahlt"
        case .storniert: "Storniert"
        }
    }
}

/// Eine einzelne Zeile auf der Rechnung.
@Model
final class Rechnungsposten {

    var reihenfolge: Int = 0
    var bezeichnung: String = ""
    var menge: Decimal = Decimal(1)
    /// "Std.", "Stk.", "Tage" - oder leer für eine Pauschale.
    var einheit: String = ""
    /// Nettopreis je Einheit.
    var einzelpreis: Decimal = Decimal(0)
    var umsatzsteuersatzCode: String = Umsatzsteuersatz.regel.rawValue

    var rechnung: Rechnung?

    init(
        reihenfolge: Int = 0,
        bezeichnung: String = "",
        menge: Decimal = 1,
        einheit: String = "",
        einzelpreis: Decimal = 0,
        umsatzsteuersatz: Umsatzsteuersatz = .regel
    ) {
        self.reihenfolge = reihenfolge
        self.bezeichnung = bezeichnung
        self.menge = menge
        self.einheit = einheit
        self.einzelpreis = einzelpreis
        self.umsatzsteuersatzCode = umsatzsteuersatz.rawValue
    }

    var umsatzsteuersatz: Umsatzsteuersatz {
        get { Umsatzsteuersatz(rawValue: umsatzsteuersatzCode) ?? .regel }
        set { umsatzsteuersatzCode = newValue.rawValue }
    }

    var netto: Decimal { menge * einzelpreis }
}

/// Eine ausgehende Rechnung.
///
/// Der wichtigste Zug an diesem Modell sind die Abschriften: Anschrift des Empfängers,
/// eigene Anschrift, Steuernummer, Bankverbindung und die Kleinunternehmer-Eigenschaft
/// werden beim Stellen **in die Rechnung kopiert** statt aus Profil und Kunde gelesen.
///
/// Der Grund ist nicht Bequemlichkeit, sondern die Sache selbst: eine gestellte Rechnung
/// ist ein Dokument, das beim Empfänger liegt. Zieht man im nächsten Jahr um oder wird
/// regelbesteuert, darf sich das PDF von damals nicht rückwirkend ändern - die GoBD
/// verlangen genau das, und ein Prüfer, der zwei verschiedene Fassungen derselben
/// Rechnungsnummer findet, hat allen Grund, weiterzufragen.
///
/// - Note: Gespeicherte Eigenschaften ohne Umlaute, siehe `Steuerprofil`.
@Model
final class Rechnung {

    // MARK: - Nummer und Zeit

    /// Die vollständige Nummer, wie sie auf dem Papier steht: "2026-0042".
    var nummer: String = ""
    /// Jahr und laufende Nummer getrennt, damit sich der Kreis fortsetzen lässt.
    var jahr: Int = 0
    var laufendeNummer: Int = 0

    /// Ausstellungsdatum (§ 14 Abs. 4 Nr. 3 UStG).
    var datum: Date = Date()
    /// Leistungszeitraum. Ist nur `leistungVon` gesetzt, gilt der Tag als Leistungsdatum.
    var leistungVon: Date?
    var leistungBis: Date?
    var zahlbarBis: Date = Date()

    var statusCode: String = Rechnungsstatus.entwurf.rawValue
    var bezahltAm: Date?

    // MARK: - Inhalt

    @Relationship(deleteRule: .cascade, inverse: \Rechnungsposten.rechnung)
    var posten: [Rechnungsposten]? = []

    var kunde: Kunde?

    /// Mappe, in der die Rechnung liegt - frei benannt, siehe `Ordner`.
    var ordner: Ordner?

    /// Freier Text unter den Positionen - Dank, Hinweis, Bezug zum Auftrag.
    var fusstext: String = ""
    var notiz: String = ""

    /// Ob das Zahlungsziel überhaupt auf der Rechnung erscheint.
    ///
    /// Nicht jede Rechnung braucht eine Frist: bei Vorkasse, Lastschrift oder einer
    /// bereits bezahlten Leistung steht dort sonst eine Zeile, die nicht stimmt.
    var zahlungszielZeigen: Bool = true

    /// Der Satz zum Zahlungsziel, falls er anders lauten soll.
    ///
    /// Leer heißt: die App formuliert ihn selbst ("Zahlbar ohne Abzug bis zum ..."). Wer
    /// Skonto gewährt, per Lastschrift einzieht oder eine andere Frist vereinbart hat,
    /// schreibt hier hin, was tatsächlich gilt.
    var zahlungshinweis: String = ""

    /// Ob die Nummer von Hand vergeben wurde.
    ///
    /// Wer aus einem anderen Programm kommt, führt seinen Kreis dort fort und will nicht
    /// bei 0001 anfangen. Eine selbst vergebene Nummer lässt den Zähler der App
    /// unberührt - sie muss dann selbst darauf achten, dass keine zweimal vorkommt.
    var nummerVonHand: Bool = false

    // MARK: - Abschriften (siehe Klassenkommentar)

    // Der Empfänger steht in Einzelfeldern, nicht als ein Textblock. Das kostet ein
    // paar Zeilen mehr und ist trotzdem richtig: nur so lässt sich die Anschrift auf
    // dem Blatt sauber setzen, und nur so kann man sie für diese eine Rechnung ändern,
    // ohne den Kunden in der Liste anzufassen.
    var empfaengerName: String = ""
    var empfaengerZusatz: String = ""
    var empfaengerStrasse: String = ""
    var empfaengerPlz: String = ""
    var empfaengerOrt: String = ""
    var empfaengerLand: String = ""
    var empfaengerUstIdNr: String = ""
    var empfaengerLeitwegId: String = ""

    var absenderName: String = ""
    var absenderAnschrift: String = ""
    var absenderSteuernummer: String = ""
    var absenderUstIdNr: String = ""
    var absenderBank: String = ""

    /// Ob zum Zeitpunkt des Stellens die Kleinunternehmerregelung galt.
    var kleinunternehmer: Bool = false

    // MARK: - Storno

    /// Gesetzt, wenn diese Rechnung eine andere aufhebt.
    var stornoFuerNummer: String = ""
    /// Gesetzt, wenn diese Rechnung durch eine Stornorechnung aufgehoben wurde.
    var storniertDurchNummer: String = ""

    var angelegtAm: Date = Date()

    init(
        nummer: String = "",
        jahr: Int = Calendar.kalender.component(.year, from: Date()),
        laufendeNummer: Int = 0,
        datum: Date = Date(),
        zahlbarBis: Date = Date()
    ) {
        self.nummer = nummer
        self.jahr = jahr
        self.laufendeNummer = laufendeNummer
        self.datum = datum
        self.zahlbarBis = zahlbarBis
        self.posten = []
        self.angelegtAm = Date()
    }

    // MARK: - Typisierter Zugriff

    var status: Rechnungsstatus {
        get { Rechnungsstatus(rawValue: statusCode) ?? .entwurf }
        set { statusCode = newValue.rawValue }
    }

    /// Die Positionen in der Reihenfolge, in der sie auf dem Papier stehen.
    var postenGeordnet: [Rechnungsposten] {
        (posten ?? []).sorted { $0.reihenfolge < $1.reihenfolge }
    }

    // MARK: - Beträge

    var netto: Decimal {
        postenGeordnet.reduce(0) { $0 + $1.netto }
    }

    /// Umsatzsteuer je Satz - eine Rechnung darf mehrere Sätze enthalten, und das
    /// Entgelt ist danach aufzuschlüsseln (§ 14 Abs. 4 Nr. 8 UStG).
    var umsatzsteuerJeSatz: [(satz: Umsatzsteuersatz, netto: Decimal, steuer: Decimal)] {
        guard !kleinunternehmer else { return [] }
        let gruppen = Dictionary(grouping: postenGeordnet, by: \.umsatzsteuersatz)
        return gruppen
            .map { satz, posten in
                let summe = posten.reduce(Decimal(0)) { $0 + $1.netto }
                return (satz: satz, netto: summe, steuer: (summe * satz.satz).gerundet())
            }
            .filter { $0.netto != 0 }
            .sorted { $0.satz.satz > $1.satz.satz }
    }

    var umsatzsteuer: Decimal {
        umsatzsteuerJeSatz.reduce(0) { $0 + $1.steuer }
    }

    var brutto: Decimal { netto + umsatzsteuer }

    // MARK: - Zustand

    var istEntwurf: Bool { status == .entwurf }

    /// Offen und das Zahlungsziel ist vorbei.
    var istÜberfällig: Bool {
        status == .offen && zahlbarBis < Calendar.kalender.startOfDay(for: Date())
    }

    var tageÜberfällig: Int {
        guard istÜberfällig else { return 0 }
        let heute = Calendar.kalender.startOfDay(for: Date())
        return Calendar.kalender.dateComponents([.day], from: zahlbarBis, to: heute).day ?? 0
    }

    /// Die Empfängeranschrift als Zeilen, leere Angaben fallen weg.
    var empfaengerzeilen: [String] {
        [empfaengerName, empfaengerZusatz, empfaengerStrasse,
         [empfaengerPlz, empfaengerOrt].filter { !$0.isEmpty }.joined(separator: " "),
         empfaengerLand]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Dieselbe Anschrift als Block - so nimmt sie der Druck entgegen.
    var empfaengerAnschrift: String { empfaengerzeilen.joined(separator: "\n") }

    /// Pflicht sind Name, Straße und Ort (§ 14 Abs. 4 Nr. 1 UStG) - egal, ob sie aus
    /// der Kundenliste kommen oder von Hand getippt sind.
    var empfaengerVollständig: Bool {
        ![empfaengerName, empfaengerStrasse, empfaengerOrt]
            .contains { $0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Was fehlt, damit sich die Rechnung stellen lässt.
    ///
    /// Gibt Klartext zurück statt eines Wahrheitswerts: "geht nicht" ohne Begründung ist
    /// bei einer Rechnung besonders ärgerlich, weil man das Fehlende sonst suchen muss.
    var hindernisse: [String] {
        var fehlt: [String] = []
        if empfaengerName.trimmingCharacters(in: .whitespaces).isEmpty {
            fehlt.append("Name des Empfängers fehlt")
        } else if !empfaengerVollständig {
            fehlt.append("Anschrift des Empfängers ist unvollständig")
        }
        if nummerVonHand, nummer.trimmingCharacters(in: .whitespaces).isEmpty {
            fehlt.append("Rechnungsnummer fehlt")
        }
        if postenGeordnet.isEmpty { fehlt.append("Keine Position erfasst") }
        if postenGeordnet.contains(where: { $0.bezeichnung.trimmingCharacters(in: .whitespaces).isEmpty }) {
            fehlt.append("Eine Position hat keine Bezeichnung")
        }
        if netto == 0 { fehlt.append("Der Rechnungsbetrag ist null") }
        return fehlt
    }
}
