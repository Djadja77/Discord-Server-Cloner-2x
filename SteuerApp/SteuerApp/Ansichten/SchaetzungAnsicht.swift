import SwiftUI
import SwiftData

/// Der vollständige Rechenweg vom Gewinn bis zur Nachzahlung - nachvollziehbar Zeile für Zeile.
///
/// Die Ansicht zeigt bewusst jeden Zwischenschritt: wer im Herbst wissen will, warum die
/// Nachzahlung so hoch ausfällt, soll es hier ablesen können, statt einer Zahl vertrauen zu müssen.
struct SchätzungAnsicht: View {

    @Binding var jahr: Int
    @Query private var belege: [Beleg]
    @Query private var profile: [Steuerprofil]
    @Query private var alleJahresangaben: [Jahresangaben]
    @Query private var wirtschaftsgüter: [Wirtschaftsgut]

    private var profil: Steuerprofil { profile.first ?? Steuerprofil() }
    private var angaben: Jahresangaben {
        alleJahresangaben.first { $0.jahr == jahr } ?? Jahresangaben(jahr: jahr)
    }
    private var steuerjahr: Steuerjahr { Steuerjahr.fuer(jahr) }

    private var euer: EinnahmenÜberschussRechnung.Ergebnis {
        EinnahmenÜberschussRechnung.berechnen(
            belege: belege, wirtschaftsgüter: wirtschaftsgüter,
            jahr: jahr, kleinunternehmer: profil.kleinunternehmer
        )
    }

    private var ergebnis: Steuerschaetzung.Ergebnis {
        Steuerschaetzung.berechnen(Steuerschaetzung.Eingaben(
            profil: profil, jahresangaben: angaben,
            gewinn: euer.gewinn, steuerjahr: steuerjahr
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                ergebnisAbschnitt
                einkünfteAbschnitt
                if ergebnis.verlustabzug.verfügbarerVortrag > 0 { verlustAbschnitt }
                abzügeAbschnitt
                if ergebnis.kinder.anzahlKinder > 0 { kinderAbschnitt }
                steuerAbschnitt
                if profil.tätigkeitsart == .gewerblich { gewerbesteuerAbschnitt }
                sätzeAbschnitt
                rechtlicherHinweis
            }
            .alsListe()
            .navigationTitle("Schätzung")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { JahresWähler(jahr: $jahr) }
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

    private var einkünfteAbschnitt: some View {
        Section("Einkünfte") {
            ZeileMitBetrag(
                bezeichnung: profil.tätigkeitsart == .freiberuflich
                    ? "Gewinn aus selbständiger Arbeit" : "Gewinn aus Gewerbebetrieb",
                betrag: ergebnis.gewinn,
                unterzeile: "\(euer.anzahlBelege) Belege in \(String(jahr))"
            )
            if angaben.weitereEinkuenfte != 0 {
                ZeileMitBetrag(bezeichnung: "Weitere Einkünfte",
                               betrag: angaben.weitereEinkuenfte)
            }
            ZeileMitBetrag(bezeichnung: "Gesamtbetrag der Einkünfte",
                           betrag: ergebnis.gesamtbetragDerEinkünfte,
                           hervorgehoben: true)
        }
    }

    private var verlustAbschnitt: some View {
        Section {
            ZeileMitBetrag(bezeichnung: "Vortrag aus Vorjahren",
                           betrag: ergebnis.verlustabzug.verfügbarerVortrag)
            ZeileMitBetrag(bezeichnung: "In \(String(jahr)) verrechnet",
                           betrag: -ergebnis.verlustabzug.abgezogen)
            ZeileMitBetrag(bezeichnung: "Rest für Folgejahre",
                           betrag: ergebnis.verlustabzug.verbleibenderVortrag,
                           hervorgehoben: true)
        } header: {
            Text("Verlustabzug")
        } footer: {
            Text(ergebnis.verlustabzug.wurdeBegrenzt
                 ? "Die Mindestbesteuerung nach § 10d Abs. 2 EStG begrenzt den Abzug in diesem Jahr. Der Rest bleibt erhalten und wird vorgetragen."
                 : "Der Verlustvortrag mindert den Gesamtbetrag der Einkünfte, bevor Sonderausgaben abgezogen werden.")
        }
    }

    private var kinderAbschnitt: some View {
        Section {
            ZeileMitBetrag(bezeichnung: "Kinderfreibeträge",
                           betrag: ergebnis.kinder.freibetrag,
                           unterzeile: "\(ergebnis.kinder.anzahlKinder) Kinder, einschließlich Betreuungsanteil")
            ZeileMitBetrag(bezeichnung: "Steuerersparnis durch Freibeträge",
                           betrag: ergebnis.kinder.entlastung)
            ZeileMitBetrag(bezeichnung: "Kindergeldanspruch",
                           betrag: ergebnis.kinder.kindergeldanspruch)

            Label(günstigerprüfung, systemImage: ergebnis.kinder.freibeträgeAngesetzt
                  ? "checkmark.circle" : "eurosign.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Günstigerprüfung")
        } footer: {
            Text("Solidaritätszuschlag und Kirchensteuer werden unabhängig vom Ergebnis dieser Prüfung immer mit Kinderfreibeträgen bemessen (§ 51a EStG).")
        }
    }

    private var günstigerprüfung: String {
        ergebnis.kinder.freibeträgeAngesetzt
            ? "Die Freibeträge sind günstiger. Sie werden angesetzt, das Kindergeld wird der Steuer hinzugerechnet."
            : "Das Kindergeld ist günstiger. Es bleibt bei der Steuer ohne Kinderfreibeträge."
    }

    private var abzügeAbschnitt: some View {
        Section {
            ZeileMitBetrag(bezeichnung: "Altersvorsorge",
                           betrag: ergebnis.vorsorge.abziehbareAltersvorsorge,
                           unterzeile: höchstbetragHinweis)
            ZeileMitBetrag(bezeichnung: "Kranken- und Pflegeversicherung",
                           betrag: ergebnis.vorsorge.abziehbareKrankenUndPflege)
            if ergebnis.vorsorge.abziehbareSonstige > 0 {
                ZeileMitBetrag(bezeichnung: "Sonstige Versicherungen",
                               betrag: ergebnis.vorsorge.abziehbareSonstige)
            }
            ZeileMitBetrag(bezeichnung: "Übrige Sonderausgaben",
                           betrag: ergebnis.übrigeSonderausgaben,
                           unterzeile: sonderausgabenHinweis)
            if ergebnis.aussergewoehnlicheBelastungen > 0 {
                ZeileMitBetrag(bezeichnung: "Außergewöhnliche Belastungen",
                               betrag: ergebnis.aussergewoehnlicheBelastungen)
            }
            ZeileMitBetrag(bezeichnung: "Zu versteuerndes Einkommen",
                           betrag: ergebnis.zuVersteuerndesEinkommen,
                           hervorgehoben: true)
        } header: {
            Text("Abzüge")
        } footer: {
            Text("Die Beträge stammen aus dem Profil. Ohne Angaben rechnet die App nur mit dem Sonderausgaben-Pauschbetrag - die Schätzung fällt dann deutlich zu hoch aus.")
        }
    }

    /// Faktor 2 bei Zusammenveranlagung - alle Höchst- und Pauschbeträge verdoppeln sich.
    private var veranlagungsfaktor: Decimal {
        profil.veranlagungsart.splitting ? 2 : 1
    }

    private var sonderausgabenHinweis: String? {
        let pauschbetrag = steuerjahr.sonderausgabenPauschbetrag * veranlagungsfaktor
        return ergebnis.übrigeSonderausgaben == pauschbetrag ? "Pauschbetrag" : nil
    }

    private var soliFreigrenzeHinweis: String {
        let freigrenze = steuerjahr.soliFreigrenze * veranlagungsfaktor
        return "unter der Freigrenze von \(Formatierung.euro(freigrenze, mitCent: false))"
    }

    private var tarifHinweis: String {
        let tarifart = profil.veranlagungsart.splitting ? "Splittingtarif" : "Grundtarif"
        guard ergebnis.kinder.freibeträgeAngesetzt else { return tarifart }
        return tarifart + ", mit Kinderfreibeträgen und hinzugerechnetem Kindergeld"
    }

    private var hebesatzHinweis: String {
        "Hebesatz \(NSDecimalNumber(decimal: profil.gewerbesteuerHebesatz).intValue) %"
    }

    private var höchstbetragHinweis: String? {
        let höchst = steuerjahr.höchstbetragAltersvorsorge * veranlagungsfaktor
        guard angaben.beitragAltersvorsorge > höchst else { return nil }
        return "gekürzt auf den Höchstbetrag von \(Formatierung.euro(höchst, mitCent: false))"
    }

    private var steuerAbschnitt: some View {
        Section("Steuer") {
            ZeileMitBetrag(bezeichnung: "Einkommensteuer",
                           betrag: ergebnis.tariflicheEinkommensteuer,
                           unterzeile: tarifHinweis)
            if ergebnis.angerechneteGewerbesteuer > 0 {
                ZeileMitBetrag(bezeichnung: "Anrechnung Gewerbesteuer",
                               betrag: -ergebnis.angerechneteGewerbesteuer,
                               unterzeile: "§ 35 EStG")
            }
            if ergebnis.solidaritätszuschlag > 0 {
                ZeileMitBetrag(bezeichnung: "Solidaritätszuschlag",
                               betrag: ergebnis.solidaritätszuschlag)
            } else {
                ZeileMitBetrag(bezeichnung: "Solidaritätszuschlag", betrag: 0,
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

    private var sätzeAbschnitt: some View {
        Section("Steuersätze") {
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
                    Text("kostet der nächste verdiente Euro")
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
                    Text("Rücklagenquote")
                    Text("Anteil des Gewinns für Steuern")
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
                Text("Diese Schätzung ersetzt keine Steuerberatung. Sie bildet die häufigsten Fälle ab, nicht jede Besonderheit \u{2013} etwa Verlustvorträge, Kinderfreibeträge oder den Progressionsvorbehalt.")
            } icon: {
                Image(systemName: "info.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !steuerjahr.amtlichGeprüft {
                Label("Die Tarifwerte für \(String(steuerjahr.jahr)) sind noch nicht gegen die amtliche Tabelle geprüft.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SchätzungAnsicht(jahr: .constant(Calendar.kalender.component(.year, from: Date())))
        .modelContainer(Datenbank.vorschauContainer())
}
