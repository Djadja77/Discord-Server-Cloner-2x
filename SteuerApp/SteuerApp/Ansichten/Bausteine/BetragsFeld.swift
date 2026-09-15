import SwiftUI

/// Eingabefeld für Geldbeträge - deutsche Schreibweise, Zifferntastatur mit Komma.
struct BetragsFeld: View {

    let titel: String
    @Binding var betrag: Decimal
    var hinweis: String? = nil

    @FocusState private var fokussiert: Bool

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
            TextField("0,00", value: $betrag, format: .currency(code: "EUR"))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .focused($fokussiert)
                .frame(maxWidth: 150)
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
