import SwiftUI

/// So lange darf man weg sein, ohne sich neu ausweisen zu müssen.
///
/// Die Konstante steht außerhalb des Typs, nicht aus Geschmack: `Sperrschicht` ist
/// generisch, und generische Typen können in Swift keine gespeicherten statischen
/// Eigenschaften haben. Innen drin wäre es ein Übersetzungsfehler.
private let nachfrist: TimeInterval = 30

/// Legt die App hinter Face ID, Touch ID oder den Gerätecode.
///
/// Zwei verschiedene Dinge passieren hier, und beide sind nötig:
///
/// 1. **Der Sperrbildschirm**, solange nicht entsperrt ist. Er liegt über der App, statt
///    sie zu ersetzen - so bleiben Datenbank, Scrollstand und offene Masken am Leben,
///    und nach dem Entsperren steht man wieder dort, wo man war.
/// 2. **Der Vorhang**, sobald die App den Vordergrund verlässt. iOS fotografiert die App
///    in dem Moment für den Programmumschalter. Ohne Vorhang stünde der letzte
///    Bildschirm mit allen Beträgen in einer Vorschau, die jeder sieht, der zweimal auf
///    den Knopf tippt - ganz ohne die App zu öffnen.
///
/// Nach einer kurzen Abwesenheit wird nicht erneut gefragt. Wer eine Rechnung per Mail
/// verschickt, verlässt die App für ein paar Sekunden; ihn dabei jedes Mal nach dem
/// Gesicht zu fragen, macht die Sperre lästig und damit auf Dauer ausgeschaltet.

struct Sperrschicht<Inhalt: View>: View {

    @ViewBuilder let inhalt: Inhalt

    @AppStorage("appSperre") private var sperreAn = false
    @Environment(\.scenePhase) private var phase

    @State private var entsperrt = false
    @State private var prüfungLäuft = false
    @State private var abwesendSeit: Date?

    var body: some View {
        ZStack {
            inhalt
                .disabled(!offen)

            if sperreAn && !offen {
                sperrbildschirm
                    .transition(.opacity)
                    .zIndex(2)
            } else if sperreAn && phase != .active {
                vorhang
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.18), value: entsperrt)
        .task { if sperreAn { await entsperren() } }
        .onChange(of: phase) { _, neue in
            switch neue {
            case .background:
                abwesendSeit = Date()
            case .active:
                if let seit = abwesendSeit, Date().timeIntervalSince(seit) > nachfrist {
                    entsperrt = false
                }
                abwesendSeit = nil
                if sperreAn && !entsperrt { Task { await entsperren() } }
            default:
                break
            }
        }
        .onChange(of: sperreAn) { _, an in
            // Frisch eingeschaltet ist die App offen - man hat sie ja gerade in der Hand.
            if an { entsperrt = true }
        }
    }

    private var offen: Bool { !sperreAn || entsperrt }

    // MARK: - Bausteine

    private var sperrbildschirm: some View {
        ZStack {
            Verlaufsgrund()

            VStack(spacing: 22) {
                Image(systemName: Gerätesperre.symbol)
                    .font(.system(size: 46, weight: .light))
                    .foregroundStyle(Stil.akzent)

                VStack(spacing: 6) {
                    Text("Steuer ist gesperrt")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Stil.schrift)
                    Text("Entsperren mit \(Gerätesperre.art)")
                        .font(.system(size: 14))
                        .foregroundStyle(Stil.schriftGedämpft)
                }

                Button(prüfungLäuft ? "Wird geprüft …" : "Entsperren") {
                    Task { await entsperren() }
                }
                .buttonStyle(HauptknopfStil())
                .disabled(prüfungLäuft)
                .padding(.horizontal, 48)
                .padding(.top, 6)
            }
        }
    }

    /// Was im Programmumschalter zu sehen ist: das Symbol, sonst nichts.
    private var vorhang: some View {
        ZStack {
            Verlaufsgrund()
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Stil.akzent)
                Text("Steuer")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Stil.schrift)
            }
        }
    }

    // MARK: - Vorgang

    private func entsperren() async {
        guard sperreAn, !entsperrt, !prüfungLäuft else { return }
        prüfungLäuft = true
        entsperrt = await Gerätesperre.prüfen()
        prüfungLäuft = false
    }
}
