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

    /// Tab- und Navigationsleiste auf den Seitengrund setzen.
    ///
    /// SwiftUI bietet dafür keinen eigenen Weg - ohne diesen Umweg über UIKit bleiben
    /// beide Leisten im Systemgrau stehen und setzen helle Streifen über und unter
    /// jeden Bildschirm.
    private static func leistenGestalten() {
        let tableiste = UITabBarAppearance()
        tableiste.configureWithOpaqueBackground()
        tableiste.backgroundColor = UIColor(Stil.grund)
        tableiste.shadowColor = UIColor(Stil.trenner)
        UITabBar.appearance().standardAppearance = tableiste
        UITabBar.appearance().scrollEdgeAppearance = tableiste

        let navileiste = UINavigationBarAppearance()
        navileiste.configureWithOpaqueBackground()
        navileiste.backgroundColor = UIColor(Stil.grund)
        // Kein Schlagschatten: die Karten darunter setzen die Kante selbst.
        navileiste.shadowColor = .clear
        navileiste.titleTextAttributes = [.foregroundColor: UIColor(Stil.schrift)]
        navileiste.largeTitleTextAttributes = [
            .foregroundColor: UIColor(Stil.schrift),
            .font: UIFont.systemFont(ofSize: 30, weight: .bold)
        ]
        UINavigationBar.appearance().standardAppearance = navileiste
        UINavigationBar.appearance().scrollEdgeAppearance = navileiste
        UINavigationBar.appearance().compactAppearance = navileiste
    }
}

#Preview {
    HauptAnsicht()
        .modelContainer(Datenbank.vorschauContainer())
}
