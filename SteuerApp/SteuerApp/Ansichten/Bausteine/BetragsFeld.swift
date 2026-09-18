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
///
/// Der Betrag wird trotzdem bei jedem Tastendruck übernommen, nicht erst beim
/// Verlassen - die Schätzung soll mitrechnen, während man tippt.
struct BetragsFeld: View {

    let titel: String
    @Binding var betrag: Decimal
    var hinweis: String? = nil

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
        .onChange(of: text) { if fokussiert { betrag = Formatierung.betragAusEingabe(text) } }
        .onChange(of: fokussiert) { _, jetztAmZug in
            text = jetztAmZug ? Formatierung.zumBearbeiten(betrag)
                              : Formatierung.euro(betrag)
        }
        .toolbar {
            // Die Zifferntastatur hat keine Return-Taste - ohne "Fertig" bleibt sie offen.
            ToolbarItemGroup(placement: .keyboard) {
                if fokussiert {
                    Spacer()
                    Button("Fertig") { fokussiert = false }
                }
            }
        }
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
