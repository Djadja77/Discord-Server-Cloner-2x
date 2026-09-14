import Foundation

/// Die vollstaendige Steuerschaetzung fuer ein Jahr - vom Gewinn bis zur Nachzahlung.
///
/// Rechenweg (vereinfachtes Schema des § 2 EStG):
/// ```
///   Gewinn aus selbstaendiger Arbeit / Gewerbebetrieb
/// + weitere Einkuenfte
/// = Gesamtbetrag der Einkuenfte
/// - Vorsorgeaufwendungen
/// - uebrige Sonderausgaben (mindestens der Pauschbetrag)
/// - aussergewoehnliche Belastungen
/// = zu versteuerndes Einkommen
/// -> Einkommensteuer nach § 32a EStG
/// - Anrechnung der Gewerbesteuer (§ 35 EStG)
/// + Solidaritaetszuschlag + Kirchensteuer
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

        init(steuerjahr: Steuerjahr, gewinn: Decimal) {
            self.steuerjahr = steuerjahr
            self.gewinn = gewinn
        }

        /// Baut die Eingaben aus dem gespeicherten Profil - eine Quelle der Wahrheit.
        init(profil: Steuerprofil, gewinn: Decimal, steuerjahr: Steuerjahr) {
            self.steuerjahr = steuerjahr
            self.gewinn = gewinn
            self.weitereEinkuenfte = profil.weitereEinkuenfte
            self.taetigkeitsart = profil.taetigkeitsart
            self.veranlagungsart = profil.veranlagungsart
            self.kirchensteuersatz = profil.kirchensteuersatz
            self.gewerbesteuerHebesatz = profil.gewerbesteuerHebesatz
            self.vorsorgeaufwendungen = profil.vorsorgeaufwendungen
            self.weitereSonderausgaben = profil.weitereSonderausgaben
            self.aussergewoehnlicheBelastungen = profil.aussergewoehnlicheBelastungen
            self.geleisteteVorauszahlungen = profil.geleisteteVorauszahlungen
        }
    }

    // MARK: - Ergebnis

    struct Ergebnis: Equatable {
        let jahr: Int
        let gewinn: Decimal
        let gesamtbetragDerEinkuenfte: Decimal
        let vorsorge: Vorsorgeaufwendungen.Ergebnis
        let uebrigeSonderausgaben: Decimal
        let aussergewoehnlicheBelastungen: Decimal
        let zuVersteuerndesEinkommen: Decimal

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

        let vorsorge = e.vorsorgeaufwendungen.abziehbar(
            steuerjahr: e.steuerjahr,
            splitting: splitting
        )
        let pauschbetrag = e.steuerjahr.sonderausgabenPauschbetrag * (splitting ? 2 : 1)
        let uebrigeSonderausgaben = max(e.weitereSonderausgaben.nichtNegativ, pauschbetrag)

        let zve = (gesamtbetrag
            - vorsorge.summe
            - uebrigeSonderausgaben
            - e.aussergewoehnlicheBelastungen.nichtNegativ
        ).nichtNegativ

        let tariflich = tarif.einkommensteuer(zuVersteuerndesEinkommen: zve, splitting: splitting)

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
        let soli = Solidaritaetszuschlag.betrag(
            einkommensteuer: festzusetzen,
            steuerjahr: e.steuerjahr,
            splitting: splitting
        )
        let kirche = Kirchensteuer.betrag(
            einkommensteuer: festzusetzen,
            satz: e.kirchensteuersatz
        )

        return Ergebnis(
            jahr: e.steuerjahr.jahr,
            gewinn: e.gewinn,
            gesamtbetragDerEinkuenfte: gesamtbetrag,
            vorsorge: vorsorge,
            uebrigeSonderausgaben: uebrigeSonderausgaben,
            aussergewoehnlicheBelastungen: e.aussergewoehnlicheBelastungen.nichtNegativ,
            zuVersteuerndesEinkommen: zve,
            tariflicheEinkommensteuer: tariflich,
            gewerbesteuer: gewerbe,
            angerechneteGewerbesteuer: angerechnet,
            festzusetzendeEinkommensteuer: festzusetzen,
            solidaritaetszuschlag: soli,
            kirchensteuer: kirche,
            geleisteteVorauszahlungen: e.geleisteteVorauszahlungen,
            durchschnittssteuersatz: tarif.durchschnittssteuersatz(
                zuVersteuerndesEinkommen: zve, splitting: splitting
            ),
            grenzsteuersatz: tarif.grenzsteuersatz(
                zuVersteuerndesEinkommen: zve, splitting: splitting
            )
        )
    }
}
