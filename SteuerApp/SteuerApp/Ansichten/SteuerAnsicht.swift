import SwiftUI

/// Alles, was einmal im Jahr drankommt - an einer Stelle.
///
/// Schätzung und Auswertung waren vorher zwei getrennte Bereiche der Leiste, obwohl
/// beide dieselbe Frage aus zwei Richtungen beantworten und beide nur zur
/// Steuererklärung gebraucht werden. Zusammengelegt ergeben sie einen Bereich mit
/// zwei Abschnitten - und machen unten Platz für das, was täglich gebraucht wird.
struct SteuerAnsicht: View {

    @Binding var jahr: Int
    /// `true`, wenn die Ansicht von "Stand" aus aufgerufen wird - dann stellt die
    /// Navigation den Rahmen, und der eigene Titel wäre einer zu viel.
    var eingebettet = false
    @State private var abschnitt: Abschnitt = .schätzung

    enum Abschnitt: String, CaseIterable, Identifiable {
        case schätzung, auswertung

        var id: String { rawValue }

        var titel: String {
            switch self {
            case .schätzung: "Schätzung"
            case .auswertung: "Auswertung"
            }
        }
    }

    var body: some View {
        if eingebettet {
            inhalt
                .navigationTitle("Steuer")
                .navigationBarTitleDisplayMode(.inline)
        } else {
            NavigationStack { inhalt.toolbar(.hidden, for: .navigationBar) }
        }
    }

    private var inhalt: some View {
        ZStack {
            Verlaufsgrund()

            VStack(spacing: 0) {
                if !eingebettet { kopfzeile }
                segmente

                switch abschnitt {
                case .schätzung:
                    SchätzungAnsicht(jahr: $jahr, eingebettet: true)
                case .auswertung:
                    EuerAnsicht(jahr: $jahr, eingebettet: true)
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private var kopfzeile: some View {
        HStack {
            Text("Steuer")
                .font(Stil.titel())
                .foregroundStyle(Stil.schrift)
            Spacer()
            Jahrespille(jahr: $jahr)
        }
        .padding(.horizontal, Stil.rand)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var segmente: some View {
        Picker("Abschnitt", selection: $abschnitt) {
            ForEach(Abschnitt.allCases) { Text($0.titel).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Stil.rand)
        .padding(.bottom, 10)
    }
}
