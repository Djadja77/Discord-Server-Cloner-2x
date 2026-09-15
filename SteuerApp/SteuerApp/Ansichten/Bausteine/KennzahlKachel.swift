import SwiftUI

/// Eine einzelne Zahl mit Beschriftung - der Grundbaustein der Übersicht.
struct KennzahlKachel: View {

    let titel: String
    let wert: String
    var hinweis: String? = nil
    var farbe: Color = .primary
    var symbol: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(titel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(wert)
                .font(.title2.weight(.semibold))
                .foregroundStyle(farbe)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            if let hinweis {
                Text(hinweis)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Zeile aus Bezeichnung und Betrag - für alle Aufstellungen in der App.
struct ZeileMitBetrag: View {

    let bezeichnung: String
    let betrag: Decimal
    var unterzeile: String? = nil
    var hervorgehoben: Bool = false
    var mitVorzeichen: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(bezeichnung)
                    .font(hervorgehoben ? .body.weight(.semibold) : .body)
                if let unterzeile {
                    Text(unterzeile)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            Text(mitVorzeichen
                 ? Formatierung.euroMitVorzeichen(betrag)
                 : Formatierung.euro(betrag))
                .font(hervorgehoben ? .body.weight(.semibold).monospacedDigit()
                                    : .body.monospacedDigit())
                .foregroundStyle(mitVorzeichen && betrag < 0 ? Color.green : .primary)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        HStack(spacing: 12) {
            KennzahlKachel(titel: "Gewinn", wert: Formatierung.euro(42_350),
                           hinweis: "vor Steuern", symbol: "chart.line.uptrend.xyaxis")
            KennzahlKachel(titel: "Rücklage", wert: Formatierung.euro(12_705),
                           hinweis: "30 % des Gewinns", farbe: .orange, symbol: "banknote")
        }
        List {
            ZeileMitBetrag(bezeichnung: "Umsatzerlöse", betrag: 52_000, unterzeile: "12 Belege")
            ZeileMitBetrag(bezeichnung: "Gewinn", betrag: 42_350, hervorgehoben: true)
        }
    }
    .padding()
}
