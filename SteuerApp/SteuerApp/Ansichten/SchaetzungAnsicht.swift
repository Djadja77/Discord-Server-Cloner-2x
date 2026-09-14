import SwiftUI
import SwiftData

/// Der vollstaendige Rechenweg vom Gewinn bis zur Nachzahlung - nachvollziehbar Zeile fuer Zeile.
///
/// Die Ansicht zeigt bewusst jeden Zwischenschritt: wer im Herbst wissen will, warum die
/// Nachzahlung so hoch ausfaellt, soll es hier ablesen koennen, statt einer Zahl vertrauen zu muessen.
struct SchaetzungAnsicht: View {

    @Binding var jahr: Int
    @Query private var belege: [Beleg]
    @Query private var profile: [Steuerprofil]

    private var profil: Steuerprofil { profile.first ?? Steuerprofil() }
    private var steuerjahr: Steuerjahr { Steuerjahr.fuer(jahr) }

    private var euer: EinnahmenUeberschussRechnung.Ergebnis {
        EinnahmenUeberschussRechnung.berechnen(
            belege: belege, jahr: jahr, kleinunternehmer: profil.kleinunternehmer
        )
    }

    private var ergebnis: Steuerschaetzung.Ergebnis {
        Steuerschaetzung.berechnen(
            Steuerschaetzung.Eingaben(profil: profil, gewinn: euer.gewinn, steuerjahr: steuerjahr)
        )
    }

    var body: some View {
        NavigationStack {
            List {
                ergebnisAbschnitt
                einkuenfteAbschnitt
                abzuegeAbschnitt
                steuerAbschnitt
                if profil.taetigkeitsart == .gewerblich { gewerbesteuerAbschnitt }
                saetzeAbschnitt
                rechtlicherHinweis
            }
            .navigationTitle("Schaetzung")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { JahresWaehler(jahr: $jahr) }
            }
        }
    }

    // MARK: - Abschnitte

    private var ergebnisAbschnitt: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(ergebnis.istErstattung ? "Voraussichtliche Erstattung" : "Voraussichtliche Nachzahlung")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Formatierung.euro(abs(ergebnis.offenerBetrag)))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(ergebnis.istErstattung ? Color.green : Color.orange)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .padding(.vertical, 6)
        }
    }

    private var einkuenfteAbschnitt: some View {
        Section("Einkuenfte") {
            ZeileMitBetrag(
                bezeichnung: profil.taetigkeitsart == .freiberuflich
                    ? "Gewinn aus selbstaendiger Arbeit" : "Gewinn aus Gewerbebetrieb",
                betrag: ergebnis.gewinn,
                unterzeile: "\(euer.anzahlBelege) Belege in \(String(jahr))"
            )
            if profil.weitereEinkuenfte != 0 {
                ZeileMitBetrag(bezeichnung: "Weitere Einkuenfte",
                               betrag: profil.weitereEinkuenfte)
            }
            ZeileMitBetrag(bezeichnung: "Gesamtbetrag der Einkuenfte",
                           betrag: ergebnis.gesamtbetragDerEinkuenfte,
                           hervorgehoben: true)
        }
    }

    private var abzuegeAbschnitt: some View {
        Section {
            ZeileMitBetrag(bezeichnung: "Altersvorsorge",
                           betrag: ergebnis.vorsorge.abziehbareAltersvorsorge,
                           unterzeile: hoechstbetragHinweis)
            ZeileMitBetrag(bezeichnung: "Kranken- und Pflegeversicherung",
                           betrag: ergebnis.vorsorge.abziehbareKrankenUndPflege)
            if ergebnis.vorsorge.abziehbareSonstige > 0 {
                ZeileMitBetrag(bezeichnung: "Sonstige Versicherungen",
                               betrag: ergebnis.vorsorge.abziehbareSonstige)
            }
            ZeileMitBetrag(bezeichnung: "Uebrige Sonderausgaben",
                           betrag: ergebnis.uebrigeSonderausgaben,
                           unterzeile: sonderausgabenHinweis)
            if ergebnis.aussergewoehnlicheBelastungen > 0 {
                ZeileMitBetrag(bezeichnung: "Aussergewoehnliche Belastungen",
                               betrag: ergebnis.aussergewoehnlicheBelastungen)
            }
            ZeileMitBetrag(bezeichnung: "Zu versteuerndes Einkommen",
                           betrag: ergebnis.zuVersteuerndesEinkommen,
                           hervorgehoben: true)
        } header: {
            Text("Abzuege")
        } footer: {
            Text("Die Betraege stammen aus dem Profil. Ohne Angaben rechnet die App nur mit dem Sonderausgaben-Pauschbetrag - die Schaetzung faellt dann deutlich zu hoch aus.")
        }
    }

    /// Faktor 2 bei Zusammenveranlagung - alle Hoechst- und Pauschbetraege verdoppeln sich.
    private var veranlagungsfaktor: Decimal {
        profil.veranlagungsart.splitting ? 2 : 1
    }

    private var sonderausgabenHinweis: String? {
        let pauschbetrag = steuerjahr.sonderausgabenPauschbetrag * veranlagungsfaktor
        return ergebnis.uebrigeSonderausgaben == pauschbetrag ? "Pauschbetrag" : nil
    }

    private var soliFreigrenzeHinweis: String {
        let freigrenze = steuerjahr.soliFreigrenze * veranlagungsfaktor
        return "unter der Freigrenze von \(Formatierung.euro(freigrenze, mitCent: false))"
    }

    private var hebesatzHinweis: String {
        "Hebesatz \(NSDecimalNumber(decimal: profil.gewerbesteuerHebesatz).intValue) %"
    }

    private var hoechstbetragHinweis: String? {
        let hoechst = steuerjahr.hoechstbetragAltersvorsorge * veranlagungsfaktor
        guard profil.beitragAltersvorsorge > hoechst else { return nil }
        return "gekuerzt auf den Hoechstbetrag von \(Formatierung.euro(hoechst, mitCent: false))"
    }

    private var steuerAbschnitt: some View {
        Section("Steuer") {
            ZeileMitBetrag(bezeichnung: "Einkommensteuer",
                           betrag: ergebnis.tariflicheEinkommensteuer,
                           unterzeile: profil.veranlagungsart.splitting
                               ? "Splittingtarif" : "Grundtarif")
            if ergebnis.angerechneteGewerbesteuer > 0 {
                ZeileMitBetrag(bezeichnung: "Anrechnung Gewerbesteuer",
                               betrag: -ergebnis.angerechneteGewerbesteuer,
                               unterzeile: "§ 35 EStG")
            }
            if ergebnis.solidaritaetszuschlag > 0 {
                ZeileMitBetrag(bezeichnung: "Solidaritaetszuschlag",
                               betrag: ergebnis.solidaritaetszuschlag)
            } else {
                ZeileMitBetrag(bezeichnung: "Solidaritaetszuschlag", betrag: 0,
                               unterzeile: soliFreigrenzeHinweis)
            }
            if ergebnis.kirchensteuer > 0 {
                ZeileMitBetrag(bezeichnung: "Kirchensteuer", betrag: ergebnis.kirchensteuer)
            }
            if ergebnis.gewerbesteuer.gewerbesteuer > 0 {
                ZeileMitBetrag(bezeichnung: "Gewerbesteuer",
                               betrag: ergebnis.gewerbesteuer.gewerbesteuer,
                               unterzeile: "davon \(Formatierung.euro(ergebnis.gewerbesteuer.restbelastung, mitCent: false)) echte Mehrbelastung")
            }
            ZeileMitBetrag(bezeichnung: "Gesamte Steuerlast",
                           betrag: ergebnis.gesamtbelastung, hervorgehoben: true)
            ZeileMitBetrag(bezeichnung: "Geleistete Vorauszahlungen",
                           betrag: -ergebnis.geleisteteVorauszahlungen,
                           unterzeile: "Einkommensteuer")
            ZeileMitBetrag(
                bezeichnung: ergebnis.istErstattung ? "Erstattung" : "Nachzahlung",
                betrag: ergebnis.offenerBetrag,
                hervorgehoben: true,
                mitVorzeichen: true
            )
        }
    }

    private var gewerbesteuerAbschnitt: some View {
        Section {
            ZeileMitBetrag(bezeichnung: "Gewerbeertrag",
                           betrag: ergebnis.gewerbesteuer.gewerbeertrag,
                           unterzeile: "abgerundet auf volle 100 Euro")
            ZeileMitBetrag(bezeichnung: "Freibetrag",
                           betrag: -steuerjahr.gewerbesteuerFreibetrag)
            ZeileMitBetrag(bezeichnung: "Steuermessbetrag",
                           betrag: ergebnis.gewerbesteuer.messbetrag,
                           unterzeile: "3,5 % Steuermesszahl")
            ZeileMitBetrag(bezeichnung: "Gewerbesteuer",
                           betrag: ergebnis.gewerbesteuer.gewerbesteuer,
                           unterzeile: hebesatzHinweis)
            ZeileMitBetrag(bezeichnung: "Davon angerechnet",
                           betrag: -ergebnis.angerechneteGewerbesteuer)
            ZeileMitBetrag(bezeichnung: "Restbelastung",
                           betrag: ergebnis.gewerbesteuer.restbelastung,
                           hervorgehoben: true)
        } header: {
            Text("Gewerbesteuer")
        } footer: {
            Text("Angerechnet wird das 3,8-fache des Messbetrags. Ab einem Hebesatz von rund 380 % bleibt eine echte Mehrbelastung.")
        }
    }

    private var saetzeAbschnitt: some View {
        Section("Steuersaetze") {
            HStack {
                Text("Durchschnittssatz")
                Spacer()
                Text(Formatierung.prozent(ergebnis.durchschnittssteuersatz))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Grenzsteuersatz")
                    Text("kostet der naechste verdiente Euro")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(Formatierung.prozent(ergebnis.grenzsteuersatz))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ruecklagenquote")
                    Text("Anteil des Gewinns fuer Steuern")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(Formatierung.prozent(ergebnis.ruecklagenquote, nachkommastellen: 0))
                    .monospacedDigit()
                    .foregroundStyle(.orange)
            }
        }
    }

    private var rechtlicherHinweis: some View {
        Section {
            Label {
                Text("Diese Schaetzung ersetzt keine Steuerberatung. Sie bildet die haeufigsten Faelle ab, nicht jede Besonderheit \u{2013} etwa Verlustvortraege, Kinderfreibetraege oder den Progressionsvorbehalt.")
            } icon: {
                Image(systemName: "info.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !steuerjahr.amtlichGeprueft {
                Label("Die Tarifwerte fuer \(String(steuerjahr.jahr)) sind noch nicht gegen die amtliche Tabelle geprueft.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SchaetzungAnsicht(jahr: .constant(Calendar.kalender.component(.year, from: Date())))
        .modelContainer(Datenbank.vorschauContainer())
}
