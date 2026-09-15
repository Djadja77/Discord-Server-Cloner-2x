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
- CSV-Export von Belegliste und Jahresauswertung für Excel oder die Steuerberatung

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

`SteuerjahrKonsistenzTests` prüft danach jeden Eintrag gegen die Eckwerte, die der Gesetzgeber
dem Tarif zugrunde legt: Der Grenzsteuersatz beträgt am Ende der ersten Progressionszone exakt
23,97 % und am Ende der zweiten exakt 42 %, und der Sockelbetrag der dritten Zone ist die Steuer
am Ende der zweiten. Diese Bedingungen verknüpfen die Tarifkonstanten miteinander – ein
Zahlendreher verletzt sie sofort. Das ist genau der Fehler, der beim jährlichen Nachtragen am
wahrscheinlichsten ist.

### Stand der Prüfung

| Jahr | Grundfreibetrag | Kindergeld | Status |
|------|-----------------|------------|--------|
| 2024 | 11.784 € | 250 €/Monat | intern konsistent, **nicht** gegen die amtliche Grundtabelle abgeglichen |
| 2025 | 12.096 € | 255 €/Monat | gegen die amtliche Grundtabelle geprüft |
| 2026 | 12.348 € | 259 €/Monat | intern konsistent, **nicht** gegen die amtliche Grundtabelle abgeglichen |

Kinderfreibeträge, Kindergeldsätze und Vorsorge-Höchstbeträge stehen in derselben Datei und
sind ebenfalls zu prüfen – der Konsistenztest deckt nur den Einkommensteuertarif ab.

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
