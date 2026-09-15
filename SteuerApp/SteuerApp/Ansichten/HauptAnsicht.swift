import SwiftUI
import SwiftData

/// Die fünf Bereiche der App. Bewusst flach gehalten: Belege erfassen ist der häufigste
/// Vorgang und darf nie mehr als einen Fingertipp entfernt sein.
struct HauptAnsicht: View {

    @Environment(\.modelContext) private var kontext

    @AppStorage("ausgewaehltesJahr") private var jahr: Int = Calendar.kalender
        .component(.year, from: Date())

    init() {
        Self.leistenGestalten()
    }

    var body: some View {
        TabView {
            UebersichtAnsicht(jahr: $jahr)
                .tabItem { Label("Übersicht", systemImage: "square.grid.2x2.fill") }

            BelegeAnsicht(jahr: $jahr)
                .tabItem { Label("Belege", systemImage: "list.bullet") }

            SchätzungAnsicht(jahr: $jahr)
                .tabItem { Label("Schätzung", systemImage: "chart.bar.fill") }

            EuerAnsicht(jahr: $jahr)
                .tabItem { Label("Auswertung", systemImage: "doc.text.fill") }

            EinstellungenAnsicht(jahr: $jahr)
                .tabItem { Label("Profil", systemImage: "person.fill") }
        }
        .tint(Stil.akzent)
        .task { stammdatenSicherstellen() }
        // Jeder Jahreswechsel braucht einen eigenen Satz Jahresangaben - sonst landen
        // Beiträge und Vorauszahlungen des einen Jahres im anderen.
        .onChange(of: jahr) { stammdatenSicherstellen() }
    }

    private func stammdatenSicherstellen() {
        Datenbank.profilSicherstellen(in: kontext)
        Datenbank.jahresangabenSicherstellen(fuer: jahr, in: kontext)
    }

    /// Die Tableiste auf den Seitengrund setzen.
    ///
    /// SwiftUI bietet dafür keinen eigenen Weg - ohne diesen Umweg über UIKit bleibt die
    /// Leiste im Systemgrau stehen und setzt einen hellen Streifen unter jeden Bildschirm.
    private static func leistenGestalten() {
        let leiste = UITabBarAppearance()
        leiste.configureWithOpaqueBackground()
        leiste.backgroundColor = UIColor(Stil.grund)
        leiste.shadowColor = UIColor(Stil.trenner)
        UITabBar.appearance().standardAppearance = leiste
        UITabBar.appearance().scrollEdgeAppearance = leiste
    }
}

#Preview {
    HauptAnsicht()
        .modelContainer(Datenbank.vorschauContainer())
}
