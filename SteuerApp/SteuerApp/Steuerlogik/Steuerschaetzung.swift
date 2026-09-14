import Foundation

/// Die vollstaendige Steuerschaetzung fuer ein Jahr - vom Gewinn bis zur Nachzahlung.
///
/// Rechenweg (Schema des § 2 EStG):
/// ```
///   Gewinn aus selbstaendiger Arbeit / Gewerbebetrieb
/// + weitere Einkuenfte
/// = Gesamtbetrag der Einkuenfte
/// - Verlustabzug aus Vorjahren (§ 10d EStG)
/// - Vorsorgeaufwendungen
/// - uebrige Sonderausgaben (mindestens der Pauschbetrag)
/// - aussergewoehnliche Belastungen
/// = zu versteuerndes Einkommen
/// -> Einkommensteuer nach § 32a EStG, mit Guenstigerpruefung fuer Kinder (§ 31 EStG)
/// - Anrechnung der Gewerbesteuer (§ 35 EStG)
/// + Solidaritaetszuschlag + Kirchensteuer (bemessen nach § 51a EStG)
/// + Gewerbesteuer
/// - geleistete Vorauszahlungen
/// = Nachzahlung oder Erstattung
/// ```
struct Steuerschaetzung {

    // MARK: - Eingaben

    struct Eingaben {
        var steuerjahr: Steuerjahr
        var gewinn: Decimal
        var weitereEinkuenfte: Decimal = 0
        var taetigkeitsart: Taetigkeitsart = .freiberuflich
        var veranlagungsart: Veranlagungsart = .einzel
        var kirchensteuersatz: Kirchensteuersatz = .keine
        var gewerbesteuerHebesatz: Decimal = 400
        var vorsorgeaufwendungen = Vorsorgeaufwendungen()
        var weitereSonderausgaben: Decimal = 0
        var aussergewoehnlicheBelastungen: Decimal = 0
        var geleisteteVorauszahlungen: Decimal = 0
        var verlustvortragAusVorjahren: Decimal = 0
        var anzahlKinder: Int = 0
        var vollerKinderfreibetrag: Bool = false

        init(steuerjahr: Steuerjahr, gewinn: Decimal) {
            self.steuerjahr = steuerjahr
            self.gewinn = gewinn
        }

        /// Baut die Eingaben aus Profil und Jahresangaben - eine Quelle der Wahrheit.
        init(
            profil: Steuerprofil,
            jahresangaben: Jahresangaben,
            gewinn: Decimal,
            steuerjahr: Steuerjahr
        ) {
            self.steuerjahr = steuerjahr
            self.gewinn = gewinn
            self.taetigkeitsart = profil.taetigkeitsart
            self.veranlagungsart = profil.veranlagungsart
            self.kirchensteuersatz = profil.kirchensteuersatz
            self.gewerbesteuerHebesatz = profil.gewerbesteuerHebesatz
            self.weitereEinkuenfte = jahresangaben.weitereEinkuenfte
            self.vorsorgeaufwendungen = jahresangaben.vorsorgeaufwendungen
            self.weitereSonderausgaben = jahresangaben.weitereSonderausgaben
            self.aussergewoehnlicheBelastungen = jahresangaben.aussergewoehnlicheBelastungen
            self.geleisteteVorauszahlungen = jahresangaben.geleisteteVorauszahlungen
            self.verlustvortragAusVorjahren = jahresangaben.verlustvortragAusVorjahren
            self.anzahlKinder = jahresangaben.anzahlKinder
            self.vollerKinderfreibetrag = jahresangaben.vollerKinderfreibetrag
        }
    }

    // MARK: - Ergebnis

    struct Ergebnis: Equatable {
        let jahr: Int
        let gewinn: Decimal
        let gesamtbetragDerEinkuenfte: Decimal
        let verlustabzug: Verlustverrechnung.Ergebnis
        let vorsorge: Vorsorgeaufwendungen.Ergebnis
        let uebrigeSonderausgaben: Decimal
        let aussergewoehnlicheBelastungen: Decimal
        let zuVersteuerndesEinkommen: Decimal

        let kinder: Kinderfreibetrag.Ergebnis
        let tariflicheEinkommensteuer: Decimal
        let gewerbesteuer: Gewerbesteuer.Ergebnis
        let angerechneteGewerbesteuer: Decimal
        let festzusetzendeEinkommensteuer: Decimal
        let solidaritaetszuschlag: Decimal
        let kirchensteuer: Decimal

        let geleisteteVorauszahlungen: Decimal

        let durchschnittssteuersatz: Double
        let grenzsteuersatz: Double

        /// Gesamte Steuerlast des Jahres.
        ///
        /// Angesetzt wird die **volle** Gewerbesteuer, nicht nur die Restbelastung: die
        /// Anrechnung nach § 35 EStG hat die Einkommensteuer bereits gemindert. Beide
        /// Entlastungen zu beruecksichtigen wuerde die Ermaessigung doppelt zaehlen.
        var gesamtbelastung: Decimal {
            festzusetzendeEinkommensteuer + solidaritaetszuschlag + kirchensteuer
                + gewerbesteuer.gewerbesteuer
        }

        /// Positiv = Nachzahlung, negativ = Erstattung.
        var offenerBetrag: Decimal { gesamtbelastung - geleisteteVorauszahlungen }

        var istErstattung: Bool { offenerBetrag < 0 }

        /// Anteil des Gewinns, der fuer Steuern zurueckgelegt werden sollte.
        var ruecklagenquote: Double {
            guard gewinn > 0 else { return 0 }
            return min(gesamtbelastung.alsDouble / gewinn.alsDouble, 1)
        }
    }

    // MARK: - Berechnung

    static func berechnen(_ e: Eingaben) -> Ergebnis {
        let splitting = e.veranlagungsart.splitting
        let tarif = Einkommensteuertarif(steuerjahr: e.steuerjahr)

        // Gewerbesteuer faellt nur bei gewerblicher Taetigkeit an.
        let gewerbe: Gewerbesteuer.Ergebnis = switch e.taetigkeitsart {
        case .freiberuflich: .keine
        case .gewerblich: Gewerbesteuer.berechnen(
            gewinn: e.gewinn,
            hebesatzProzent: e.gewerbesteuerHebesatz,
            steuerjahr: e.steuerjahr
        )
        }

        let gesamtbetrag = e.gewinn + e.weitereEinkuenfte

        let verlust = Verlustverrechnung.anwenden(
            gesamtbetragDerEinkuenfte: gesamtbetrag,
            verlustvortrag: e.verlustvortragAusVorjahren,
            steuerjahr: e.steuerjahr,
            splitting: splitting
        )

        let vorsorge = e.vorsorgeaufwendungen.abziehbar(
            steuerjahr: e.steuerjahr,
            splitting: splitting
        )
        let pauschbetrag = e.steuerjahr.sonderausgabenPauschbetrag * (splitting ? 2 : 1)
        let uebrigeSonderausgaben = max(e.weitereSonderausgaben.nichtNegativ, pauschbetrag)

        let zve = (gesamtbetrag
            - verlust.abgezogen
            - vorsorge.summe
            - uebrigeSonderausgaben
            - e.aussergewoehnlicheBelastungen.nichtNegativ
        ).nichtNegativ

        let kinder = Kinderfreibetrag.pruefen(
            zuVersteuerndesEinkommen: zve,
            anzahlKinder: e.anzahlKinder,
            vollerFreibetrag: e.vollerKinderfreibetrag,
            steuerjahr: e.steuerjahr,
            splitting: splitting
        )
        let tariflich = kinder.tariflicheEinkommensteuer

        // § 35 EStG: angerechnet wird hoechstens der Teil der Einkommensteuer, der auf die
        // gewerblichen Einkuenfte entfaellt. Der Anteil wird hier ueber das Verhaeltnis der
        // positiven Einkuenfte bestimmt - das entspricht dem Ermaessigungshoechstbetrag,
        // solange keine Verluste aus anderen Einkunftsarten im Spiel sind.
        let angerechnet: Decimal
        if gewerbe.anrechnungsvolumen > 0, gesamtbetrag > 0 {
            let anteilGewerbe = e.gewinn.nichtNegativ / max(gesamtbetrag, 1)
            let hoechstbetrag = (tariflich * anteilGewerbe).gerundet()
            angerechnet = min(gewerbe.anrechnungsvolumen, hoechstbetrag)
        } else {
            angerechnet = 0
        }

        let festzusetzen = (tariflich - angerechnet).nichtNegativ

        // § 51a EStG: Zuschlagsteuern bemessen sich stets nach der Steuer mit
        // Kinderfreibetraegen - auch dann, wenn die Guenstigerpruefung zugunsten des
        // Kindergelds ausgegangen ist. Die Gewerbesteuer-Anrechnung mindert sie ebenso.
        let bemessungZuschlagsteuern = (kinder.bemessungZuschlagsteuern - angerechnet).nichtNegativ

        let soli = Solidaritaetszuschlag.betrag(
            einkommensteuer: bemessungZuschlagsteuern,
            steuerjahr: e.steuerjahr,
            splitting: splitting
        )
        let kirche = Kirchensteuer.betrag(
            einkommensteuer: bemessungZuschlagsteuern,
            satz: e.kirchensteuersatz
        )

        // Grenzsteuersatz an der Stelle, an der tatsaechlich versteuert wird.
        let massgeblichesEinkommen = kinder.freibetraegeAngesetzt
            ? (zve - kinder.freibetrag).nichtNegativ
            : zve

        let gesamtbelastung = festzusetzen + soli + kirche + gewerbe.gewerbesteuer
        let durchschnitt = gesamtbetrag > 0
            ? min(gesamtbelastung.alsDouble / gesamtbetrag.alsDouble, 1)
            : 0

        return Ergebnis(
            jahr: e.steuerjahr.jahr,
            gewinn: e.gewinn,
            gesamtbetragDerEinkuenfte: gesamtbetrag,
            verlustabzug: verlust,
            vorsorge: vorsorge,
            uebrigeSonderausgaben: uebrigeSonderausgaben,
            aussergewoehnlicheBelastungen: e.aussergewoehnlicheBelastungen.nichtNegativ,
            zuVersteuerndesEinkommen: zve,
            kinder: kinder,
            tariflicheEinkommensteuer: tariflich,
            gewerbesteuer: gewerbe,
            angerechneteGewerbesteuer: angerechnet,
            festzusetzendeEinkommensteuer: festzusetzen,
            solidaritaetszuschlag: soli,
            kirchensteuer: kirche,
            geleisteteVorauszahlungen: e.geleisteteVorauszahlungen,
            // Anteil der gesamten Steuerlast am Gesamtbetrag der Einkuenfte - das ist die
            // Zahl, die zaehlt, wenn man wissen will, was vom Verdienten uebrig bleibt.
            durchschnittssteuersatz: durchschnitt,
            grenzsteuersatz: tarif.grenzsteuersatz(
                zuVersteuerndesEinkommen: massgeblichesEinkommen, splitting: splitting
            )
        )
    }
}
