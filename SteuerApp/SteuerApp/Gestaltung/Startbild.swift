import SwiftUI

/// Der Start der App: ein Suchrahmen stellt scharf, eine Scanlinie fährt durch.
///
/// Das Bild zeigt, was die App tut - einen Beleg erfassen. Vorher stand hier eine
/// Gewinnzahl, die aber erfunden war und so tat, als wäre sie die des Nutzers. Eine
/// Zahl, die nicht stimmt, gehört auf keinen Bildschirm dieser App, am wenigsten auf
/// den ersten.
///
/// Der Ablauf ist der einer Dokumentenkamera: der Rahmen fährt von außen herein und
/// rastet ein, die Linie tastet ab, und was sie überstreicht, wird sichtbar.
///
/// - Note: Bei eingeschaltetem "Bewegung reduzieren" erscheint dasselbe Bild ohne
///   Bewegung und deutlich kürzer.
struct Startbild: View {

    /// Wird gerufen, wenn die Animation durch ist oder der Nutzer sie wegtippt.
    let fertig: () -> Void

    @Environment(\.accessibilityReduceMotion) private var bewegungReduziert

    @State private var rahmenEingerastet = false
    @State private var abtastung: CGFloat = 0
    @State private var markeSichtbar = false
    @State private var nameSichtbar = false
    @State private var sichtbar = true

    private let rahmengröße: CGFloat = 138
    private let eckenlänge: CGFloat = 30

    var body: some View {
        ZStack {
            Verlaufsgrund()

            VStack(spacing: 0) {
                suchrahmen
                name.padding(.top, 30)
            }
        }
        .opacity(sichtbar ? 1 : 0)
        .contentShape(Rectangle())
        .onTapGesture { abschließen() }
        .task { await ablaufSpielen() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Steuer - Belege, Einnahmen-Überschuss-Rechnung, Steuerschätzung")
    }

    // MARK: - Bausteine

    /// Die vier Ecken einer Dokumentenkamera, dazwischen die Marke und die Scanlinie.
    private var suchrahmen: some View {
        ZStack {
            ecke(drehung: 0, ausrichtung: .topLeading)
            ecke(drehung: 90, ausrichtung: .topTrailing)
            ecke(drehung: 180, ausrichtung: .bottomTrailing)
            ecke(drehung: 270, ausrichtung: .bottomLeading)

            marke
            scanlinie
        }
        .frame(width: rahmengröße, height: rahmengröße)
        // Der ganze Rahmen fährt von außen herein und rastet ein - eine Feder mit
        // wenig Dämpfung, damit es sich wie ein Einrasten anfühlt und nicht wie ein
        // Einblenden.
        .scaleEffect(rahmenEingerastet ? 1 : 1.35)
        .opacity(rahmenEingerastet ? 1 : 0)
    }

    private func ecke(drehung: Double, ausrichtung: Alignment) -> some View {
        Eckwinkel()
            .stroke(
                Stil.akzent,
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )
            .frame(width: eckenlänge, height: eckenlänge)
            .rotationEffect(.degrees(drehung))
            .frame(width: rahmengröße, height: rahmengröße, alignment: ausrichtung)
    }

    private var marke: some View {
        Image(systemName: "eurosign")
            .font(.system(size: 46, weight: .bold))
            .foregroundStyle(Stil.schrift)
            .opacity(markeSichtbar ? 1 : 0)
            .scaleEffect(markeSichtbar ? 1 : 0.86)
    }

    /// Die Linie, die den Rahmen abtastet.
    ///
    /// Ein schmaler Streifen mit Schein nach oben und unten - so liest man ihn als
    /// Licht, nicht als Strich. Sie läuft von der oberen Kante zur unteren und
    /// verschwindet dort.
    private var scanlinie: some View {
        let weg = rahmengröße - 8
        return Rectangle()
            .fill(
                LinearGradient(
                    colors: [Stil.akzent.opacity(0), Stil.akzent, Stil.akzent.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 16)
            .overlay(
                Rectangle()
                    .fill(Stil.akzent)
                    .frame(height: 1.5)
            )
            .offset(y: -weg / 2 + weg * abtastung)
            .opacity(abtastung > 0 && abtastung < 1 ? 1 : 0)
            .frame(width: rahmengröße - 16, height: rahmengröße)
            .clipped()
    }

    private var name: some View {
        VStack(spacing: 5) {
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

    // MARK: - Ablauf

    @MainActor
    private func ablaufSpielen() async {
        guard !bewegungReduziert else {
            rahmenEingerastet = true
            markeSichtbar = true
            nameSichtbar = true
            try? await Task.sleep(for: .milliseconds(800))
            abschließen()
            return
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) {
            rahmenEingerastet = true
        }

        try? await Task.sleep(for: .milliseconds(320))
        withAnimation(.easeInOut(duration: 0.8)) { abtastung = 1 }

        // Die Marke erscheint, während die Linie über sie hinweggeht - nicht davor
        // und nicht danach, sonst löst sich der Zusammenhang auf.
        try? await Task.sleep(for: .milliseconds(340))
        withAnimation(.easeOut(duration: 0.3)) { markeSichtbar = true }

        try? await Task.sleep(for: .milliseconds(300))
        withAnimation(.easeOut(duration: 0.35)) { nameSichtbar = true }

        try? await Task.sleep(for: .milliseconds(700))
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

/// Ein Eckwinkel des Suchrahmens: zwei Striche, die sich in der Ecke treffen.
private struct Eckwinkel: Shape {

    func path(in rahmen: CGRect) -> Path {
        var weg = Path()
        weg.move(to: CGPoint(x: rahmen.minX, y: rahmen.maxY))
        weg.addLine(to: CGPoint(x: rahmen.minX, y: rahmen.minY))
        weg.addLine(to: CGPoint(x: rahmen.maxX, y: rahmen.minY))
        return weg
    }
}

#Preview {
    Startbild(fertig: {})
}
