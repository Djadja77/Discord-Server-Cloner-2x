import SwiftUI

/// Der Start der App: die Kennzahlkarte baut sich vor den Augen auf.
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
            Stil.grund.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                marke
                name.padding(.top, 20)

                betragszeile.padding(.top, 34)
                balken.padding(.top, 26)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 44)
            .frame(maxWidth: 460)
        }
        .opacity(sichtbar ? 1 : 0)
        .contentShape(Rectangle())
        .onTapGesture { abschließen() }
        .task { await ablaufSpielen() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Steuer - Belege, Einnahmen-Überschuss-Rechnung, Steuerschätzung")
    }

    // MARK: - Bausteine

    private var marke: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Stil.akzent)
            .frame(width: 74, height: 74)
            .overlay(
                Image(systemName: "eurosign")
                    .font(.system(size: 33, weight: .bold))
                    .foregroundStyle(.white)
            )
            .scaleEffect(markeGesetzt ? 1 : 0.55)
            .opacity(markeGesetzt ? 1 : 0)
    }

    private var name: some View {
        VStack(spacing: 5) {
            Text("Steuer")
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(Stil.schrift)
            Text("Belege · EÜR · Schätzung")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Stil.schriftGedämpft)
        }
        .opacity(nameSichtbar ? 1 : 0)
        .offset(y: nameSichtbar ? 0 : 8)
    }

    private var betragszeile: some View {
        VStack(spacing: 6) {
            Text("GEWINN 2026")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(Stil.schriftLeise)

            ZählenderBetrag(
                wert: betrag,
                schrift: Stil.hauptzahl(38),
                farbe: Stil.haben,
                mitVorzeichen: true
            )
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
        .opacity(betragSichtbar ? 1 : 0)
    }

    private var balken: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(verlauf.enumerated()), id: \.offset) { stelle, anteil in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(stelle == verlauf.count - 1 ? Stil.akzent : Stil.flächeHoch)
                    .frame(height: max(66 * anteil * balkenhöhe, 2))
                    .animation(
                        bewegungReduziert
                            ? .none
                            : .spring(response: 0.5, dampingFraction: 0.78)
                                .delay(Double(stelle) * 0.035),
                        value: balkenhöhe
                    )
            }
        }
        .frame(height: 66, alignment: .bottom)
    }

    // MARK: - Ablauf

    @MainActor
    private func ablaufSpielen() async {
        guard !bewegungReduziert else {
            markeGesetzt = true
            nameSichtbar = true
            betragSichtbar = true
            betrag = zielbetrag
            balkenhöhe = 1
            try? await Task.sleep(for: .milliseconds(850))
            abschließen()
            return
        }

        withAnimation(.spring(response: 0.55, dampingFraction: 0.66)) { markeGesetzt = true }

        try? await Task.sleep(for: .milliseconds(280))
        withAnimation(.easeOut(duration: 0.35)) { nameSichtbar = true }

        try? await Task.sleep(for: .milliseconds(320))
        withAnimation(.easeOut(duration: 0.25)) { betragSichtbar = true }
        withAnimation(.easeOut(duration: 0.85)) { betrag = zielbetrag }
        balkenhöhe = 1

        try? await Task.sleep(for: .milliseconds(1000))
        abschließen()
    }

    @MainActor
    private func abschließen() {
        guard sichtbar else { return }
        withAnimation(.easeIn(duration: 0.3)) { sichtbar = false }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            fertig()
        }
    }
}

#Preview {
    Startbild(fertig: {})
}
