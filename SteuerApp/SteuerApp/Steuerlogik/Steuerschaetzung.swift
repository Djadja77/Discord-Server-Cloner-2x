import Foundation

/// Die vollständige Steuerschaetzung für ein Jahr - vom Gewinn bis zur Nachzahlung.
///
/// Rechenweg (Schema des § 2 EStG):
/// ```
///   Gewinn aus selbständiger Arbeit / Gewerbebetrieb
/// + weitere Einkünfte
/// = Gesamtbetrag der Einkünfte
/// - Verlustabzug aus Vorjahren (§ 10d EStG)
/// - Vorsorgeaufwendungen
/// - übrige Sonderausgaben (mindestens der Pauschbetrag)
/// - außergewöhnliche Belastungen
/// = zu versteuerndes Einkommen
/// -> Einkommensteuer nach § 32a EStG, mit Günstigerprüfung für Kinder (§ 31 EStG)
/// - Anrechnung der Gewerbesteuer (§ 35 EStG)
/// + Solidaritätszuschlag + Kirchensteuer (bemessen nach § 51a EStG)
/// + Gewerbesteuer
/// - geleistete Vorauszahlungen
/// = Nachzahlung oder Erstattung
/// ```
struct Steuerschaetzung {

    // MARK: - Eingaben

    struct Eingaben {
        var steuerjahr: Steuerjahr
        var gewinn: Decimal
        var weitereEinkünfte: Decimal = 0
        var tätigkeitsart: Tätigkeitsart = .freiberuflich
        var veranlagungsart: Veranlagungsart = .einzel
        var kirchensteuersatz: Kirchensteuersatz = .keine
        var gewerbesteuerHebesatz: Decimal = 400
        var vorsorgeaufwendungen = Vorsorgeaufwendungen()
        var weitereSonderausgaben: Decimal = 0
        var außergewöhnlicheBelastungen: Decimal = 0
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
            self.tätigkeitsart = profil.tätigkeitsart
            self.veranlagungsart = profil.veranlagungsart
            self.kirchensteuersatz = profil.kirchensteuersatz
            self.gewerbesteuerHebesatz = profil.gewerbesteuerHebesatz
            self.weitereEinkünfte = jahresangaben.weitereEinkünfte
            self.vorsorgeaufwendungen = jahresangaben.vorsorgeaufwendungen
            self.weitereSonderausgaben = jahresangaben.weitereSonderausgaben
            self.außergewöhnlicheBelastungen = jahresangaben.außergewöhnlicheBelastungen
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
        let gesamtbetragDerEinkünfte: Decimal
        let verlustabzug: Verlustverrechnung.Ergebnis
        let vorsorge: Vorsorgeaufwendungen.Ergebnis
        let übrigeSonderausgaben: Decimal
        let außergewöhnlicheBelastungen: Decimal
        let zuVersteuerndesEinkommen: Decimal

        let kinder: Kinderfreibetrag.Ergebnis
        let tariflicheEinkommensteuer: Decimal
        let gewerbesteuer: Gewerbesteuer.Ergebnis
        let angerechneteGewerbesteuer: Decimal
        let festzusetzendeEinkommensteuer: Decimal
        let solidaritätszuschlag: Decimal
        let kirchensteuer: Decimal

        let geleisteteVorauszahlungen: Decimal

        let durchschnittssteuersatz: Double
        let grenzsteuersatz: Double

        /// Gesamte Steuerlast des Jahres.
        ///
        /// Angesetzt wird die **volle** Gewerbesteuer, nicht nur die Restbelastung: die
        /// Anrechnung nach § 35 EStG hat die Einkommensteuer bereits gemindert. Beide
        /// Entlastungen zu beruecksichtigen würde die Ermäßigung doppelt zählen.
        var gesamtbelastung: Decimal {
            festzusetzendeEinkommensteuer + solidaritätszuschlag + kirchensteuer
                + gewerbesteuer.gewerbesteuer
        }

        /// Positiv = Nachzahlung, negativ = Erstattung.
        var offenerBetrag: Decimal { gesamtbelastung - geleisteteVorauszahlungen }

        var istErstattung: Bool { offenerBetrag < 0 }

        /// Anteil des Gewinns, der für Steuern zurückgelegt werden sollte.
        var ruecklagenquote: Double {
            guard gewinn > 0 else { return 0 }
            return min(gesamtbelastung.alsDouble / gewinn.alsDouble, 1)
        }
    }

    // MARK: - Berechnung

    static func berechnen(_ e: Eingaben) -> Ergebnis {
        let splitting = e.veranlagungsart.splitting
        let tarif = Einkommensteuertarif(steuerjahr: e.steuerjahr)

        // Gewerbesteuer fällt nur bei gewerblicher Tätigkeit an.
        let gewerbe: Gewerbesteuer.Ergebnis = switch e.tätigkeitsart {
        case .freiberuflich: .keine
        case .gewerblich: Gewerbesteuer.berechnen(
            gewinn: e.gewinn,
            hebesatzProzent: e.gewerbesteuerHebesatz,
            steuerjahr: e.steuerjahr
        )
        }

        let gesamtbetrag = e.gewinn + e.weitereEinkünfte

        let verlust = Verlustverrechnung.anwenden(
            gesamtbetragDerEinkünfte: gesamtbetrag,
            verlustvortrag: e.verlustvortragAusVorjahren,
            steuerjahr: e.steuerjahr,
            splitting: splitting
        )

        let vorsorge = e.vorsorgeaufwendungen.abziehbar(
            steuerjahr: e.steuerjahr,
            splitting: splitting
        )
        let pauschbetrag = e.steuerjahr.sonderausgabenPauschbetrag * (splitting ? 2 : 1)
        let übrigeSonderausgaben = max(e.weitereSonderausgaben.nichtNegativ, pauschbetrag)

        let zve = (gesamtbetrag
            - verlust.abgezogen
            - vorsorge.summe
            - übrigeSonderausgaben
            - e.außergewöhnlicheBelastungen.nichtNegativ
        ).nichtNegativ

        let kinder = Kinderfreibetrag.prüfen(
            zuVersteuerndesEinkommen: zve,
            anzahlKinder: e.anzahlKinder,
            vollerFreibetrag: e.vollerKinderfreibetrag,
            steuerjahr: e.steuerjahr,
            splitting: splitting
        )
        let tariflich = kinder.tariflicheEinkommensteuer

        // § 35 EStG: angerechnet wird höchstens der Teil der Einkommensteuer, der auf die
        // gewerblichen Einkünfte entfällt. Der Anteil wird hier über das Verhältnis der
        // positiven Einkünfte bestimmt - das entspricht dem Ermäßigungshöchstbetrag,
        // solange keine Verluste aus anderen Einkunftsarten im Spiel sind.
        let angerechnet: Decimal
        if gewerbe.anrechnungsvolumen > 0, gesamtbetrag > 0 {
            let anteilGewerbe = e.gewinn.nichtNegativ / max(gesamtbetrag, 1)
            let höchstbetrag = (tariflich * anteilGewerbe).gerundet()
            angerechnet = min(gewerbe.anrechnungsvolumen, höchstbetrag)
        } else {
            angerechnet = 0
        }

        let festzusetzen = (tariflich - angerechnet).nichtNegativ

        // § 51a EStG: Zuschlagsteuern bemessen sich stets nach der Steuer mit
        // Kinderfreibeträgen - auch dann, wenn die Günstigerprüfung zugunsten des
        // Kindergelds ausgegangen ist. Die Gewerbesteuer-Anrechnung mindert sie ebenso.
        let bemessungZuschlagsteuern = (kinder.bemessungZuschlagsteuern - angerechnet).nichtNegativ

        let soli = Solidaritätszuschlag.betrag(
            einkommensteuer: bemessungZuschlagsteuern,
            steuerjahr: e.steuerjahr,
            splitting: splitting
        )
        let kirche = Kirchensteuer.betrag(
            einkommensteuer: bemessungZuschlagsteuern,
            satz: e.kirchensteuersatz
        )

        // Grenzsteuersatz an der Stelle, an der tatsächlich versteuert wird.
        let maßgeblichesEinkommen = kinder.freibeträgeAngesetzt
            ? (zve - kinder.freibetrag).nichtNegativ
            : zve

        let gesamtbelastung = festzusetzen + soli + kirche + gewerbe.gewerbesteuer
        let durchschnitt = gesamtbetrag > 0
            ? min(gesamtbelastung.alsDouble / gesamtbetrag.alsDouble, 1)
            : 0

        return Ergebnis(
            jahr: e.steuerjahr.jahr,
            gewinn: e.gewinn,
            gesamtbetragDerEinkünfte: gesamtbetrag,
            verlustabzug: verlust,
            vorsorge: vorsorge,
            übrigeSonderausgaben: übrigeSonderausgaben,
            außergewöhnlicheBelastungen: e.außergewöhnlicheBelastungen.nichtNegativ,
            zuVersteuerndesEinkommen: zve,
            kinder: kinder,
            tariflicheEinkommensteuer: tariflich,
            gewerbesteuer: gewerbe,
            angerechneteGewerbesteuer: angerechnet,
            festzusetzendeEinkommensteuer: festzusetzen,
            solidaritätszuschlag: soli,
            kirchensteuer: kirche,
            geleisteteVorauszahlungen: e.geleisteteVorauszahlungen,
            // Anteil der gesamten Steuerlast am Gesamtbetrag der Einkünfte - das ist die
            // Zahl, die zählt, wenn man wissen will, was vom Verdienten übrig bleibt.
            durchschnittssteuersatz: durchschnitt,
            grenzsteuersatz: tarif.grenzsteuersatz(
                zuVersteuerndesEinkommen: maßgeblichesEinkommen, splitting: splitting
            )
        )
    }
}
