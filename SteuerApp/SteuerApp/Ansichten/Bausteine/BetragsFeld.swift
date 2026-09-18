import SwiftUI

/// Eingabefeld für Geldbeträge - deutsche Schreibweise, Zifferntastatur mit Komma.
///
/// Das Feld führt zwei verschiedene Texte, und das ist der ganze Punkt:
///
/// - **Während getippt wird** steht dort nur die nackte Zahl: "1500,5". Kein
///   Währungszeichen, keine Tausenderpunkte.
/// - **Sobald es die Eingabe verlässt** steht dort der fertige Betrag: "1.500,50 €".
///
/// Vorher hing an dem Feld `format: .currency(code: "EUR")`. SwiftUI formatiert damit
/// auch mitten im Tippen: im Feld stand "3,00 €", die nächste getippte Ziffer landete
/// dahinter, und heraus kam "3,00 €00". Löschen half nicht, weil das Währungszeichen
/// mit im Weg stand und die Zifferntastatur es nicht wieder herstellen kann.
struct BetragsFeld: View {

    let titel: String
    @Binding var betrag: Decimal
    var hinweis: String? = nil

    /// Ob der Betrag schon beim Tippen übernommen wird.
    ///
    /// `true` gehört an Felder, die in einen Entwurf im Arbeitsspeicher schreiben und
    /// deren Bildschirm einen Sichern-Knopf hat. Der Knopf kann jederzeit gedrückt
    /// werden, auch mit offener Tastatur - dann muss der zuletzt getippte Betrag
    /// schon drinstehen.
    ///
    /// `false` gehört an Felder, die direkt in die Datenbank schreiben. Dort zieht
    /// jede Änderung alle `@Query`-Abfragen und damit den ganzen Bildschirm neu nach
    /// sich. Bei jedem Tastendruck wird die App davon so zäh, dass sich die Tastatur
    /// nicht mehr schliessen lässt - genau das ist einmal passiert. Diese Bildschirme
    /// haben keinen Sichern-Knopf; übernommen wird, sobald das Feld die Eingabe
    /// verlässt.
    var sofortÜbernehmen = false

    @FocusState private var fokussiert: Bool
    @State private var text = ""

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(titel)
                if let hinweis {
                    Text(hinweis)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            TextField("0,00 €", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .focused($fokussiert)
                .frame(maxWidth: 150)
        }
        .onAppear { text = Formatierung.euro(betrag) }
        // Von aussen geänderte Beträge - Jahreswechsel, Texterkennung nach dem Scan.
        // Nur, wenn gerade niemand tippt: sonst schriebe es einem in die Eingabe.
        .onChange(of: betrag) { if !fokussiert { text = Formatierung.euro(betrag) } }
        .onChange(of: text) {
            if fokussiert && sofortÜbernehmen {
                betrag = Formatierung.betragAusEingabe(text)
            }
        }
        .onChange(of: fokussiert) { _, jetztAmZug in
            if jetztAmZug { text = Formatierung.zumBearbeiten(betrag) } else { übernehmen() }
        }
        // Wird der Bildschirm mit offener Tastatur verlassen, kommt kein Fokuswechsel
        // mehr - ohne das hier wäre der zuletzt getippte Betrag weg.
        .onDisappear { if fokussiert { übernehmen() } }
        .toolbar {
            // Die Zifferntastatur hat keine Eingabetaste - ohne "Fertig" bleibt sie
            // offen. Dasselbe leistet `tastaturFertig()` für die Textfelder; hier steht
            // es ausgeschrieben, weil das Feld seinen Fokus für den Betrag ohnehin
            // selbst führt und zwei Fokusbindungen an einem Feld nicht gutgehen.
            ToolbarItemGroup(placement: .keyboard) {
                if fokussiert {
                    Spacer()
                    Button("Fertig") { fokussiert = false }
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        }
    }

    /// Übernimmt den getippten Text und stellt die Anzeige auf den fertigen Betrag um.
    private func übernehmen() {
        let gelesen = Formatierung.betragAusEingabe(text)
        if gelesen != betrag { betrag = gelesen }
        text = Formatierung.euro(gelesen)
    }
}

/// Auswahl des Steuerjahres - in mehreren Ansichten oben eingeblendet.
///
/// - Note: Hülle um `Jahrespille` aus der Gestaltungsschicht.
struct JahresWähler: View {

    @Binding var jahr: Int

    var body: some View {
        Jahrespille(jahr: $jahr)
    }
}
