# Steuer – iOS-App für Selbständige und Freiberufler

Eine SwiftUI-App, die Belege sammelt, daraus die Einnahmen-Überschuss-Rechnung aufstellt und
laufend schätzt, wie viel Geld für das Finanzamt zurückgelegt werden muss.

Gebaut für den Fall, der im Alltag am meisten weh tut: Man verdient das Jahr über gut, legt zu
wenig zurück, und im Herbst kommt der Bescheid. Die App beantwortet jederzeit die eine Frage,
die dabei zählt – **wie viel von dem Geld auf dem Konto gehört mir eigentlich?**

## Funktionsumfang

**Belege erfassen**
- **Stapel scannen**: einen ganzen Packen Quittungen in einem Durchgang abfotografieren.
  Jede Seite wird zu einem eigenen Beleg, alle werden parallel ausgelesen und liegen
  danach zur Kontrolle nebeneinander
- Dokumentenkamera erkennt Belegkanten, entzerrt und schneidet zu
- Texterkennung schlägt **Händler, Betrag, Datum, Umsatzsteuersatz und Kategorie** vor –
  als Vorschlag, der immer überschreibbar ist
- Import aus der Fotomediathek für Rechnungen, die per E-Mail kommen
- Belegfoto in voller Größe, zoom- und verschiebbar
- 26 Kategorien in der Gliederung der Anlage EÜR, jeweils mit Hinweis auf die EÜR-Zeile
- Umsatzsteuersatz je Beleg (0 %, 7 %, 19 %)
- betrieblicher Anteil für gemischt genutzte Kosten wie Telefon oder Fahrzeug
- Suche, Monatsgruppierung, Filter nach Einnahmen, Ausgaben und fehlenden Belegfotos

### Was die Texterkennung leistet – und was nicht

Erkannt wird, was deutsche Belege üblicherweise zeigen. Der **Betrag** kommt bevorzugt aus
der Zeile mit einem Summenwort, sonst ist es der größte Betrag des Belegs. Der **Händler**
ist die erste Kopfzeile, die weder Überschrift noch Anschrift ist. Der **Steuersatz** wird
nur übernommen, wenn er eindeutig ist: steht nur ein Satz auf dem Beleg, ist die Sache klar;
stehen beide da, muss der ausgewiesene Steuerbetrag zur Summe passen. Bei einem echten
Mischbeleg – Speisen zu 7 %, Getränke zu 19 % – bleibt das Feld leer, statt zu raten.

Die **Kategorie** stammt aus einer Stichwortliste gängiger Anbieter. Verglichen wird auf
Teilzeichenketten, was ohne Sorgfalt danebengeht: „Espresso" enthält „esso", „Huber" enthält
„uber", „Notarzt" enthält „notar". Solche Stichworte tragen deshalb ein führendes Leerzeichen,
und `KategorievorschlagTests` prüft genau diese Fälle.

Jeder erkannte Wert füllt nur ein leeres Feld – eine Korrektur von Hand überschreibt die
Texterkennung nie. Ein erkanntes Datum wird zudem nur übernommen, wenn es ins bearbeitete
Steuerjahr fällt: ein falsch gelesenes Jahr sortierte den Beleg sonst unbemerkt aus der
Auswertung.

**Auswerten**
- Einnahmen-Überschuss-Rechnung nach § 4 Abs. 3 EStG, nach Kategorien aufgeschlüsselt
- Anlagenverzeichnis mit linearer Abschreibung (§ 7 EStG), zeitanteilig ab Anschaffungsmonat
- Umsatzsteuer-Voranmeldung monatlich oder vierteljährlich, mit Zahllast je Zeitraum
- **Vollständige Unterlagen als ZIP**: beide Auswertungen plus sämtliche Belegfotos, benannt
  nach Datum, Bezeichnung und Betrag. Die Belegliste nennt zu jeder Zeile die zugehörige
  Bilddatei, sodass sich jede Zahl ohne Suchen dem Papier zuordnen lässt
- alternativ nur die Zahlen als CSV für Excel oder Numbers

**Schätzen**
- Einkommensteuer nach § 32a EStG, Grund- und Splittingtarif
- Solidaritätszuschlag mit Freigrenze und Milderungszone
- Kirchensteuer 8 % / 9 %
- Gewerbesteuer inklusive Anrechnung nach § 35 EStG (für Gewerbetreibende)
- Vorsorgeaufwendungen als Sonderausgaben – für Selbständige der größte Abzugsposten
- Verlustvortrag aus Vorjahren inklusive Mindestbesteuerung (§ 10d Abs. 2 EStG)
- Kinderfreibeträge mit automatischer Günstigerprüfung gegen das Kindergeld (§ 31 EStG)
- Rücklagenquote und offener Betrag nach Abzug geleisteter Vorauszahlungen
- jeder Zwischenschritt einzeln sichtbar, damit die Zahl nachvollziehbar bleibt

## Bauen

```bash
open SteuerApp/SteuerApp.xcodeproj
```

- Xcode 16 oder neuer (das Projekt nutzt dateisystem-synchronisierte Gruppen)
- iOS 17.0 als Mindestversion (SwiftData, `ContentUnavailableView`)
- keine externen Abhängigkeiten

Vor dem ersten Start in den Zielangaben eine eigene Bundle-ID und ein Signaturteam eintragen.
Die Dokumentenkamera und die Texterkennung laufen nur auf einem echten Gerät, alles andere
funktioniert im Simulator.

Tests:

```bash
xcodebuild test -project SteuerApp/SteuerApp.xcodeproj \
  -scheme SteuerApp -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Kein Bilderkatalog – und warum das so bleibt

Das Projekt enthält keine `Assets.xcassets`. Der Grund ist dreimal belegt: auf zwei
Rechnern blieb der Bau ohne jede Fehlermeldung an derselben Stelle stehen –

```
ExecuteExternalTool .../actool --print-asset-tag-combinations .../Assets.xcassets
```

In Xcode heißt derselbe Schritt **„Compute asset tag combinations"**. `actool` wird
gestartet und kehrt nicht zurück; der Bau steht, und nichts im Protokoll weist darauf
hin. Der erste Vorfall kostete Stunden.

Drei Erklärungen wurden geprüft und sind alle widerlegt:

1. **Ein hängengebliebenes `actool` aus einem abgebrochenen Lauf.** Widerlegt: der
   zweite Vorfall trat auf einem frisch ausgepackten Projekt nach einem Neustart auf.
2. **Kaputte Dateien.** Widerlegt: `AppIcon.png` ist regulär (1024×1024, 8 Bit,
   Farbtyp 2, also RGB ohne Alphakanal, gültige Prüfsummen, keine Verschränkung), und
   `AccentColor.colorset` ist gültiges JSON mit einem Hell- und einem Dunkelwert.
3. **Das Quarantänemerkmal heruntergeladener Archive.** Widerlegt: auch nach
   `xattr -cr` blieb es beim dritten Versuch an derselben Stelle stehen.

Die Ursache liegt damit in `actool` selbst oder seinem Zwischenspeicher – außerhalb
dessen, was dieses Projekt beeinflussen kann. Ein App-Symbol ist Kosmetik; ein Bau,
der ohne Meldung hängt, kostet Stunden. Also bleibt der Katalog draußen, samt
`ASSETCATALOG_COMPILER_APPICON_NAME` und `..._GLOBAL_ACCENT_COLOR_NAME`.

Sichtbar fehlt nur das Symbol auf dem Home-Bildschirm. Die Farben der App kommen aus
`Gestaltung/Stil.swift`, nicht aus dem Katalog.

**Falls es jemand doch versuchen will:** nicht den Katalog aus diesem Projekt
hineinkopieren, sondern ihn von Xcode anlegen lassen – *File → New → File from
Template → Asset Catalog*, darin *AppIcon*, und
`Werkzeuge/appicon/AppIcon-1024.png` hineinziehen. Hängt der Bau danach wieder, ist
die Sache für diesen Rechner entschieden:

```bash
rm -rf <Projektordner>/SteuerApp/Assets.xcassets
```

Allgemein gilt: `xcodebuild` ohne `-quiet` laufen lassen und die Ausgabe mitschreiben,
sonst ist eine Blockade nicht von einem langen Übersetzungslauf zu unterscheiden.

```bash
xcodebuild … build 2>&1 | tee ~/Desktop/steuerapp-log.txt
```

### Prüfen ohne Xcode

Wer keinen Mac zur Hand hat, kommt mit `Werkzeuge/aufrufe_pruefen.py` ein Stück weit:

```bash
pip install tree_sitter tree_sitter_swift
cd SteuerApp && python3 Werkzeuge/aufrufe_pruefen.py
```

Das Skript parst alle Swift-Dateien mit einem echten Swift-Parser und vergleicht jeden
Aufruf mit der zugehörigen Deklaration – Argumentbeschriftungen, Reihenfolge, Existenz des
Mitglieds. Damit fällt die Fehlerklasse auf, die beim Schreiben ohne Compiler entsteht.

Es ersetzt den Compiler nicht: Argumenttypen, Sichtbarkeit, Protokollkonformität und alles
aus SwiftUI, Foundation und SwiftData bleiben ungeprüft. Ein sauberer Lauf heißt, dass die
Aufrufe zu den eigenen Deklarationen passen – nicht, dass das Projekt übersetzt.

## Aufbau

```
SteuerApp/
├── Modell/          SwiftData-Objekte und Belegentwurf
├── Steuerlogik/     reine Rechenlogik, ohne SwiftUI und ohne Datenbank
├── Ansichten/       SwiftUI-Oberfläche, fünf Bereiche
├── Dienste/         Formatierung, Belegarchiv, CSV-Export, Texterkennung, Kategorien
└── Werkzeuge/       Generator für das App-Icon (reines Python, ohne Abhängigkeiten)
```

Die Stammdaten sind bewusst zweigeteilt. `Steuerprofil` hält, was jahrelang gleich bleibt –
Rechtsform, Veranlagung, Kirchensteuer. `Jahresangaben` hält alles, was sich jährlich ändert:
Beiträge, Vorauszahlungen, Kinder, Verlustvortrag. Ohne diese Trennung würde ein Wechsel des
Steuerjahres die Zahlen des Vorjahres überschreiben.

Die Steuerlogik hängt von keiner Ansicht und keiner Datenbank ab. Sie nimmt Zahlen entgegen und
gibt Zahlen zurück – deshalb ist sie vollständig durch Tests abgedeckt, und deshalb lässt sich
ein Rechenweg prüfen, ohne die App zu starten.

Geldbeträge sind durchgehend `Decimal`. `Double` kommt nur innerhalb der Tarifpolynome vor,
wo § 32a EStG ohnehin auf volle Euro abrundet.

## Steuerliche Grundlagen

Hinterlegt sind die Veranlagungszeiträume **2024, 2025 und 2026**. Alle jahresabhängigen
Werte stehen in einer einzigen Datei: `Steuerlogik/Steuerjahr.swift`.

### Ein neues Jahr ergänzen

Einen weiteren `Steuerjahr`-Eintrag anlegen und in `Steuerjahr.alle` aufnehmen. Der Rest der App
zieht automatisch nach. Nötig sind die Werte aus § 32a Abs. 1 EStG, die Freigrenze des
Solidaritätszuschlags und die Höchstbeträge der Vorsorgeaufwendungen.

`SteuerjahrTarifwerteTests` und `SteuerjahrKonsistenzTests` prüfen danach jeden Eintrag. Der
zweite vergleicht ihn mit den Eckwerten, die der Gesetzgeber dem Tarif zugrunde legt: Der Grenzsteuersatz beträgt am Ende der ersten Progressionszone exakt
23,97 % und am Ende der zweiten exakt 42 %, und der Sockelbetrag der dritten Zone ist die Steuer
am Ende der zweiten. Diese Bedingungen verknüpfen die Tarifkonstanten miteinander – ein
Zahlendreher verletzt sie sofort. Das ist genau der Fehler, der beim jährlichen Nachtragen am
wahrscheinlichsten ist.

### Stand der Prüfung

| Jahr | Grundfreibetrag | Kindergeld | Tarifkonstanten |
|------|-----------------|------------|-----------------|
| 2024 | 11.784 € | 250 €/Monat | gegen § 32a EStG abgeglichen |
| 2025 | 12.096 € | 255 €/Monat | gegen § 32a EStG und das amtliche Einkommensteuer-Handbuch abgeglichen |
| 2026 | 12.348 € | 259 €/Monat | gegen § 32a EStG abgeglichen |

Ebenfalls geprüft: Freigrenzen des Solidaritätszuschlags, Kinderfreibeträge, Betreuungs-
freibetrag und Kindergeldsätze aller drei Jahre sowie die Höchstbeträge der Altersvorsorge
für 2025 und 2026.

Beim Abgleich fielen zwei Abweichungen auf, die inzwischen korrigiert sind: Die Abzugsbeträge
der oberen Tarifzonen für 2024 lauten **10.636,31 €** und **18.971,06 €** – rechnerisch aus
der Stetigkeit hergeleitet kommt man auf elf Cent weniger, und im Gesetz steht der
veröffentlichte Wert. Der Höchstbetrag der Altersvorsorge 2026 beträgt **30.826 €**.

Ein Wert bleibt abgeleitet statt belegt: der Höchstbetrag der Altersvorsorge für **2024**
(27.566 €) folgt aus 24,7 % der Beitragsbemessungsgrenze der knappschaftlichen
Rentenversicherung, ist aber nicht gegen eine amtliche Fundstelle geprüft.

Zwei Tests sichern das ab. `SteuerjahrTarifwerteTests` hält die Zahlen auf den
veröffentlichten Werten fest – wer eine ändert, muss den Test mitändern und stolpert dabei
über die Quellenangabe. `SteuerjahrKonsistenzTests` prüft zusätzlich, ob die Zahlen
zueinander passen. Der eine Test fängt falsche Werte, der andere Tippfehler.

Alle drei Jahre erfüllen die oben genannten gesetzlichen Eckwerte exakt. Für 2025 stimmen die
Ergebnisse zusätzlich mit veröffentlichten Werten der Einkommensteuer-Grundtabelle überein.
Für 2024 und 2026 steht dieser Abgleich noch aus – die App weist in der Übersicht und in der
Schätzung sichtbar darauf hin, und `amtlichGeprueft` im jeweiligen `Steuerjahr` schaltet den
Hinweis ab, sobald die Werte geprüft sind.

### Bewusste Vereinfachungen

Die App bildet die häufigen Fälle ab, nicht jede Besonderheit. Nicht berücksichtigt sind:

- der Verlustrücktrag ins Vorjahr (nur der Vortrag ist umgesetzt)
- Progressionsvorbehalt bei Lohnersatzleistungen
- Abgeltungsteuer auf Kapitalerträge
- die zumutbare Belastung bei außergewöhnlichen Belastungen (bitte vorab abziehen)
- degressive Abschreibung und Sammelposten – abgeschrieben wird linear
- der Entlastungsbetrag für Alleinerziehende

Zwei Punkte, bei denen die App bewusst anders rechnet als das amtliche Formular:

- **Nettomethode in der EÜR.** Umsatzsteuer und Vorsteuer bleiben aus der Gewinnermittlung
  heraus, weil sie wirtschaftlich durchlaufende Posten sind. Das Ergebnis entspricht der
  Bruttomethode, ist unterjährig aber aussagekräftiger. Beim Übertragen in die Anlage EÜR sind
  Umsatzsteuer und Vorsteuer wieder zu ergänzen.
- **Ist-Versteuerung.** Maßgeblich ist das erfasste Belegdatum. Wer nach vereinbarten Entgelten
  versteuert, trägt das Rechnungsdatum ein.

Korrekt abgebildet sind dagegen einige Details, die häufig untergehen: Bewirtungskosten sind nur
zu 70 % Betriebsausgabe, während die Vorsteuer voll abziehbar bleibt. Die Gewerbesteuer-
Anrechnung ist auf das 3,8-fache des Messbetrags **und** auf die tatsächlich gezahlte Steuer
gedeckelt. Die Gesamtbelastung setzt die volle Gewerbesteuer an, nicht nur die Restbelastung –
sonst würde die Anrechnung doppelt gutgeschrieben. Solidaritätszuschlag und Kirchensteuer
bemessen sich nach § 51a EStG immer nach der Steuer mit Kinderfreibeträgen, auch wenn die
Günstigerprüfung zugunsten des Kindergelds ausgeht. Und die Abschreibung setzt im letzten Jahr
den Restbuchwert an, damit sich die Jahresbeträge exakt auf die Anschaffungskosten summieren.

## App-Icon

Das Icon wird von `Werkzeuge/appicon_erzeugen.py` erzeugt – reines Python, keine
Bildbibliothek, kein Designprogramm:

```bash
python3 Werkzeuge/appicon_erzeugen.py
```

Farben und Geometrie stehen als Konstanten oben in der Datei. Wer das Motiv ändern will,
ändert die Zahlen und lässt das Skript neu laufen.

## Datenschutz

Alle Daten bleiben auf dem Gerät. Die App verschickt nichts, meldet nichts und bindet keine
fremden Dienste ein. Auch die Texterkennung läuft lokal über Apples Vision-Framework — kein
Beleg verlässt das Telefon. Belegfotos liegen als
Dateien in „Application Support“ und sind damit vom Geräte-Backup erfasst; die Datenbank
selbst bleibt dadurch klein.

## Haftungsausschluss

Diese App ist ein Rechenwerkzeug und ersetzt keine Steuerberatung. Die Schätzung ist eine
Schätzung. Verbindlich ist allein der Bescheid des Finanzamts.
