import SwiftUI

/// Der Start der App: eine Glaskarte legt sich über den Verlauf und füllt sich.
///
/// Die Reihenfolge ist dieselbe wie später auf der Übersicht - Marke, Name, Betrag,
/// Monatsbalken. Wer die App zum zehnten Mal öffnet, sieht deshalb nichts Fremdes,
/// sondern den Bildschirm dahinter beim Entstehen.
///
/// - Note: Bei eingeschaltetem "Bewegung reduzieren" erscheint dasselbe Bild ohne
///   Bewegung und deutlich kürzer.
struct Startbild: View {

    /// Wird gerufen, wenn die Animation durch ist oder der Nutzer sie wegtippt.
    let fertig: () -> Void

    @Environment(\.accessibilityReduceMotion) private var bewegungReduziert

    @State private var karteDa = false
    @State private var markeGesetzt = false
    @State private var nameSichtbar = false
    @State private var betrag: Double = 0
    @State private var betragSichtbar = false
    @State private var balkenhöhe: CGFloat = 0
    @State private var sichtbar = true

    /// Beispielverlauf für die Balken - die Form eines gewöhnlichen Jahres.
    private let verlauf: [CGFloat] = [0.32, 0.44, 0.38, 0.55, 0.49, 0.62,
                                      0.58, 0.71, 0.84, 0.66, 0.78, 0.94]
    private let zielbetrag: Double = 35_942.09

    var body: some View {
        ZStack {
            Verlaufsgrund()

            karte
                .frame(maxWidth: 340)
                .padding(.horizontal, 32)
                .scaleEffect(karteDa ? 1 : 0.92)
                .opacity(karteDa ? 1 : 0)
        }
        .opacity(sichtbar ? 1 : 0)
        .contentShape(Rectangle())
        .onTapGesture { abschließen() }
        .task { await ablaufSpielen() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Steuer - Belege, Einnahmen-Überschuss-Rechnung, Steuerschätzung")
    }

    // MARK: - Bausteine

    private var karte: some View {
        VStack(spacing: 0) {
            marke
            name.padding(.top, 18)
            betragszeile.padding(.top, 28)
            balken.padding(.top, 22)
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .alsGlas(radius: 32)
    }

    private var marke: some View {
        RoundedRectangle(cornerRadius: Stil.innenradius(außen: 32, polster: 6),
                         style: .continuous)
            .fill(Stil.akzent)
            .frame(width: 70, height: 70)
            .overlay(
                RoundedRectangle(cornerRadius: Stil.innenradius(außen: 32, polster: 6),
                                 style: .continuous)
                    .strokeBorder(Stil.kante, lineWidth: 1)
            )
            .overlay(
                Image(systemName: "eurosign")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(.white)
            )
            .scaleEffect(markeGesetzt ? 1 : 0.6)
            .opacity(markeGesetzt ? 1 : 0)
    }

    private var name: some View {
        VStack(spacing: 4) {
            Text("Steuer")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Stil.schrift)
            Text("Belege · EÜR · Schätzung")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Stil.schriftGedämpft)
        }
        .opacity(nameSichtbar ? 1 : 0)
        .offset(y: nameSichtbar ? 0 : 8)
    }

    private var betragszeile: some View {
        VStack(spacing: 5) {
            Text("GEWINN 2026")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(Stil.schriftLeise)

            ZählenderBetrag(
                wert: betrag,
                schrift: Stil.hauptzahl(34),
                farbe: Stil.haben,
                mitVorzeichen: true
            )
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
        .opacity(betragSichtbar ? 1 : 0)
    }

    private var balken: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(Array(verlauf.enumerated()), id: \.offset) { stelle, anteil in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(stelle == verlauf.count - 1
                          ? AnyShapeStyle(Stil.akzent)
                          : AnyShapeStyle(Color.white.opacity(0.16)))
                    .frame(height: max(58 * anteil * balkenhöhe, 2))
                    .animation(
                        bewegungReduziert
                            ? .none
                            : .spring(response: 0.5, dampingFraction: 0.78)
                                .delay(Double(stelle) * 0.035),
                        value: balkenhöhe
                    )
            }
        }
        .frame(height: 58, alignment: .bottom)
    }

    // MARK: - Ablauf

    @MainActor
    private func ablaufSpielen() async {
        guard !bewegungReduziert else {
            karteDa = true
            markeGesetzt = true
            nameSichtbar = true
            betragSichtbar = true
            betrag = zielbetrag
            balkenhöhe = 1
            try? await Task.sleep(for: .milliseconds(850))
            abschließen()
            return
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) { karteDa = true }

        try? await Task.sleep(for: .milliseconds(140))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) { markeGesetzt = true }

        try? await Task.sleep(for: .milliseconds(260))
        withAnimation(.easeOut(duration: 0.35)) { nameSichtbar = true }

        try? await Task.sleep(for: .milliseconds(300))
        withAnimation(.easeOut(duration: 0.25)) { betragSichtbar = true }
        withAnimation(.easeOut(duration: 0.85)) { betrag = zielbetrag }
        balkenhöhe = 1

        try? await Task.sleep(for: .milliseconds(1000))
        abschließen()
    }

    @MainActor
    private func abschließen() {
        guard sichtbar else { return }
        withAnimation(.easeIn(duration: 0.32)) { sichtbar = false }
        Task {
            try? await Task.sleep(for: .milliseconds(320))
            fertig()
        }
    }
}

#Preview {
    Startbild(fertig: {})
}
