# Pflichtenheft – Beauty of Fractals

Stand: 12. Juli 2026

Dokumentstatus: Lebendes Produktdokument

Aktuelle Produktlinie: 2.9

## 1. Zweck des Dokuments

Dieses Pflichtenheft beschreibt die fachlichen und technischen Anforderungen an
**Beauty of Fractals** für macOS und iOS. Es hält bestehende Funktionen,
Qualitätsziele und geplante Erweiterungen nachvollziehbar fest.

Das Dokument wird gemeinsam mit dem Produkt weiterentwickelt. Neue Anforderungen
erhalten eine eindeutige Kennung und ein prüfbares Abnahmekriterium.

## 2. Produktvision

Beauty of Fractals macht mathematische Unendlichkeit unmittelbar erfahrbar. Die
App soll komplexe Fraktale schnell, präzise und ästhetisch darstellen, ohne die
Nutzer mit der zugrunde liegenden Rechentechnik zu belasten.

Die Bedienung folgt drei Leitgedanken:

1. **Entdecken:** Zoomen und Verschieben sollen direkt und spielerisch wirken.
2. **Verstehen:** Renderstatus, Präzisionsmodus und Iterationen bleiben bei Bedarf
   sichtbar und nachvollziehbar.
3. **Bewahren:** Fundstellen lassen sich speichern, synchronisieren und in hoher
   Qualität exportieren.

## 3. Zielplattformen

- macOS als eigenständige Desktop-App
- iPhone und iPad als gemeinsame iOS-App
- Apple Watch als ergänzende Oberfläche, soweit im jeweiligen Release vorgesehen
- iCloud zur Synchronisierung geeigneter nutzerbezogener Inhalte

Plattformspezifische Bedienkonzepte dürfen voneinander abweichen. Mathematische
Ergebnisse und gespeicherte Ansichten sollen plattformübergreifend kompatibel
bleiben, soweit die jeweilige Funktion unterstützt wird.

## 4. Status- und Prioritätsmodell

### Status

- **Umgesetzt:** Bestandteil der aktuellen Produktlinie
- **In Arbeit:** Implementierung oder Abnahme läuft
- **Geplant:** Fachlich beschlossen, noch nicht umgesetzt
- **Idee:** Noch nicht verbindlich spezifiziert

### Priorität

- **Muss:** Für den vorgesehenen Release erforderlich
- **Soll:** Hoher Produktnutzen, Umsetzung nach den Muss-Anforderungen
- **Kann:** Optionale Erweiterung

## 5. Funktionale Anforderungen

### 5.1 Fraktaldarstellung und Navigation

| ID | Anforderung | Priorität | Status | Abnahmekriterium |
|---|---|---:|---|---|
| FR-001 | Die App stellt Mandelbrot und die im Modusmenü angebotenen weiteren Fraktaltypen dar. | Muss | Umgesetzt | Jeder angebotene Modus kann ausgewählt und ohne Absturz gerendert werden. |
| FR-002 | Nutzer können per Maus, Trackpad oder Touch zoomen und den Bildausschnitt verschieben. | Muss | Umgesetzt | Navigation reagiert unmittelbar und aktualisiert Mittelpunkt und Skalierung korrekt. |
| FR-003 | Die aktuelle Ansicht kann auf die Standardansicht des gewählten Fraktals zurückgesetzt werden. | Muss | Umgesetzt | Reset stellt Mittelpunkt und Skalierung des Modus wieder her. |
| FR-004 | Navigationsschritte können rückgängig gemacht werden. | Muss | Umgesetzt | Der vorherige Zoom-, Pan- oder Reset-Zustand wird vollständig wiederhergestellt. |
| FR-005 | Der aktuelle Zoomfaktor wird in der App angezeigt, ohne in Bildexporte übernommen zu werden. | Soll | Umgesetzt | Anzeige stimmt mit der aktuellen Skalierung überein; exportierte PNGs enthalten sie nicht. |
| FR-006 | Die App bietet eine Power-of-n-Fraktalfamilie mit ganzzahligem Exponenten von 2 bis 12. | Muss | Umgesetzt | Der Exponent kann per Slider gewählt werden; Darstellung und Modusname reagieren ohne Absturz. |
| FR-007 | Der gewählte Power-of-n-Exponent bleibt in Favoriten und Exportbezeichnungen erhalten. | Muss | Umgesetzt | Wiederöffnen eines Favoriten reproduziert den Exponenten; der Exportdateiname enthält ihn. |

### 5.2 Rendering und Präzision

| ID | Anforderung | Priorität | Status | Abnahmekriterium |
|---|---|---:|---|---|
| FR-100 | Normale Ansichten werden GPU-beschleunigt mit Metal gerendert. | Muss | Umgesetzt | Interaktive Ansichten verwenden den Metal-Renderer. |
| FR-101 | Bei tiefen Zoomstufen wechselt die App automatisch in eine geeignete Hochpräzisionsmethode. | Muss | Umgesetzt | Die Darstellung bleibt über die Grenze normaler Double-Präzision hinaus stabil. |
| FR-102 | Nutzer können Renderqualität, maximale Iterationen und die angebotene Deep-Render-Methode wählen. | Muss | Umgesetzt | Änderungen führen zu einer Neuberechnung mit den gewählten Parametern. |
| FR-103 | Ein Renderstatus zeigt Fortschritt, Iterationen und verstrichene Zeit. | Soll | Umgesetzt | Das Panel aktualisiert sich während eines Renders und zeigt einen abgeschlossenen Zustand. |
| FR-104 | Der Renderstatus kann über Oberfläche und `Shift–Cmd–P` geöffnet oder geschlossen werden. | Soll | Umgesetzt | Button und Tastaturkürzel schalten dasselbe Panel. |
| FR-105 | Technische Renderdiagnosen können bei Bedarf eingeblendet werden. | Soll | Umgesetzt | Diagnoseansicht zeigt die für den aktuellen Render verfügbaren Werte. |
| FR-106 | Für Zoomtiefen oberhalb der zuverlässig nutzbaren Double-Double-Präzision steht ein Triple-/Double-Refinement zur Verfügung. | Soll | Geplant | Eine definierte Referenzmenge tiefer Zoompunkte wird ohne Koordinatensprung und mit gegenüber Double-Double nachweisbar höherer stabiler Präzision gerendert. |
| FR-107 | Die App wählt Triple-/Double-Refinement nur dann, wenn die günstigeren Präzisionsmethoden nicht mehr ausreichen. | Muss | Geplant | Die automatische Methodenwahl bleibt bei flacheren Zooms auf der schnellsten nachweislich stabilen Methode und wechselt reproduzierbar an einer dokumentierten Präzisionsgrenze. |
| FR-108 | Ein Triple-/Double-Refinement beginnt mit einer schnellen Vorschau und verfeinert sie anschließend sichtbarkeitsarm zum Endergebnis. | Soll | Geplant | Während der Berechnung bleibt eine nutzbare Vorschau sichtbar; das Endergebnis enthält keine Naht-, Kachel- oder Methodenwechselartefakte. |
| FR-109 | Renderstatus und Diagnosen weisen die tatsächlich verwendete Präzisions- und Refinement-Methode aus. | Soll | Geplant | Bei einem Triple-/Double-Render sind Methode, Refinement-Phase und relevante Präzisionsdaten eindeutig erkennbar. |

#### Offene Festlegung zum Triple-/Double-Refinement

Vor Beginn der Implementierung wird in einem technischen Konzept festgelegt, ob
„Triple/Double“ eine Triple-Double-Arithmetik, ein mehrstufiges Refinement aus
Double- und Double-Double-Ergebnissen oder eine Kombination mit Perturbation und
Referenzorbits bezeichnet. Das Konzept muss Fehlergrenzen, Umschaltschwellen,
Speicherbedarf und erwartete Laufzeit anhand gemeinsamer Referenzpunkte vergleichen.

### 5.3 Paletten und Erscheinungsbild

| ID | Anforderung | Priorität | Status | Abnahmekriterium |
|---|---|---:|---|---|
| FR-200 | Nutzer können zwischen den angebotenen Farbpaletten wechseln. | Muss | Umgesetzt | Die aktive Ansicht wird mit der gewählten Palette neu dargestellt. |
| FR-201 | Die Bedienoberfläche passt Material, Kontrast und Lesbarkeit an den Bildinhalt und die Plattform an. | Soll | Umgesetzt | Controls bleiben auf hellen und dunklen Fraktalbereichen erkennbar. |
| FR-202 | Die macOS-Hauptbedienung erscheint als kompakte, schwebende Kontrollleiste. | Soll | Umgesetzt | Navigation, Modus, Renderfunktionen, Favoriten, Export und Hilfe sind erreichbar. |
| FR-203 | Die Palette Pearl stellt Fraktale in Weiß-, Elfenbein-, Silber- und Graphitabstufungen dar. | Soll | Umgesetzt | GPU-Vorschau und CPU-Export zeigen eine konsistente monochrome Abstufung mit hellem Innenkörper. |
| FR-204 | Auric färbt die Innenkörper der Power-of-n-Familie gold. | Soll | Umgesetzt | Für jeden Exponenten von 2 bis 12 ist der Innenkörper in Vorschau und Export nicht schwarz, sondern goldfarben. |

### 5.4 Favoriten und iCloud

| ID | Anforderung | Priorität | Status | Abnahmekriterium |
|---|---|---:|---|---|
| FR-300 | Eine aktuelle Fraktalansicht kann mit Koordinaten, Zoom, Parametern und Vorschaubild als Favorit gespeichert werden. | Muss | Umgesetzt | Öffnen des Favoriten reproduziert die gespeicherte Ansicht. |
| FR-301 | Favoriten können benannt, umbenannt, sortiert und gelöscht werden. | Soll | Umgesetzt | Jede Aktion bleibt nach einem Neustart erhalten. |
| FR-302 | Favoriten werden über den konfigurierten iCloud-Container synchronisiert. | Muss | Umgesetzt | Auf demselben iCloud-Konto gespeicherte Favoriten erscheinen auf unterstützten Geräten. |
| FR-303 | Eine fehlende oder vorübergehend nicht erreichbare iCloud-Verbindung darf lokale Favoriten nicht unbeabsichtigt überschreiben. | Muss | Umgesetzt | Ein leerer oder fehlgeschlagener Cloud-Lesevorgang löscht keine lokalen Daten. |
| FR-304 | Nutzer können ausgewählte oder alle Favoriten in eine portable Datei exportieren. | Soll | Geplant | Die Exportdatei enthält die für eine vollständige Wiederherstellung erforderlichen Ansichtsparameter, Metadaten und – soweit gewählt – Vorschaubilder. |
| FR-305 | Eine portable Favoritendatei kann unabhängig vom verwendeten iCloud-Konto importiert werden. | Soll | Geplant | Valide Favoriten erscheinen nach dem Import lokal und können anschließend über das aktuell angemeldete iCloud-Konto synchronisiert werden. |
| FR-306 | Vor einem Import zeigt die App Anzahl, Herkunft beziehungsweise Dateiversion und mögliche Konflikte an. | Muss | Geplant | Der Nutzer kann den Import vor jeder dauerhaften Änderung prüfen und abbrechen. |
| FR-307 | Der Import unterstützt ein sicheres Zusammenführen mit vorhandenen Favoriten. | Muss | Geplant | Bestehende Favoriten werden nicht stillschweigend überschrieben; Dubletten werden erkannt und als Überspringen, Duplizieren oder Ersetzen behandelt. |
| FR-308 | Das Austauschformat ist versioniert und vorwärts erweiterbar. | Muss | Geplant | Dateien enthalten eine Formatversion; unbekannte neuere Pflichtfelder führen zu einer verständlichen Fehlermeldung statt zu Datenverlust. |
| FR-309 | Fehlerhafte oder manipulierte Importdateien dürfen weder bestehende Favoriten beschädigen noch unkontrolliert Dateien außerhalb des vorgesehenen Imports lesen oder schreiben. | Muss | Geplant | Validierung erfolgt vor dem Merge; bei einem Fehler bleibt der bestehende Datenbestand unverändert. |

#### Vorgaben für das portable Favoritenformat

- Das Format ist unabhängig von Apple-ID, iCloud-Container und lokalem Dateipfad.
- Koordinaten werden ohne vermeidbaren Präzisionsverlust gespeichert; Deep-Zoom-
  Favoriten verwenden ihre hochpräzise Darstellung und nicht nur gerundete
  `Double`-Werte.
- Fraktalmodus, Mittelpunkt, Skalierung, Iterationen, Renderqualität, Palette,
  Name und Erstellungsdatum gehören zu den wiederherstellbaren Kerndaten.
- Vorschaubilder können eingebettet oder als Bestandteil eines Paketformats
  mitgeführt werden; das endgültige Dateiformat wird vor Implementierung festgelegt.
- Der Export darf keine iCloud-internen URLs, Sicherheits-Token oder
  gerätespezifischen Sandbox-Pfade enthalten.

### 5.5 Export

| ID | Anforderung | Priorität | Status | Abnahmekriterium |
|---|---|---:|---|---|
| FR-400 | Ansichten können in den angebotenen Auflösungen als PNG exportiert werden. | Muss | Umgesetzt | Das gespeicherte PNG besitzt die gewählte Pixelgröße und enthält keine UI-Overlays. |
| FR-401 | Für geeignete Ansichten steht ein höher aufgelöster Ultra-Export zur Verfügung. | Soll | Umgesetzt | Das Ergebnis wird mit dem angebotenen Supersampling gerendert. |
| FR-402 | Während des Exports zeigt die Kontrollleiste einen eindeutigen Arbeitszustand. | Soll | Umgesetzt | Das Export-Symbol wird während der Berechnung als Sanduhr dargestellt und ist nicht erneut auslösbar. |
| FR-403 | Erfolg oder Fehler eines Exports wird nachvollziehbar angezeigt. | Muss | Umgesetzt | Nach Abschluss ist der Ergebniszustand sichtbar und schließt sich gemäß UI-Konzept wieder. |

### 5.6 Animierte Zoomreise

Die animierte Zoomreise überführt gespeicherte Einzelansichten in eine fließende
„Reise in die Unendlichkeit“.

| ID | Anforderung | Priorität | Status | Abnahmekriterium |
|---|---|---:|---|---|
| FR-500 | Nutzer können zwei benachbarte, kompatible Favoriten als Start und Ziel einer Zoomreise wählen. | Soll | Geplant | Die App akzeptiert zwei Ansichten desselben Fraktalmodus und meldet inkompatible Paare verständlich. |
| FR-501 | Mittelpunkt und Skalierung werden zwischen Start und Ziel kontinuierlich interpoliert. | Muss | Geplant | Die Animation besitzt keine sichtbaren Sprünge in Position oder Zoomstufe. |
| FR-502 | Die Skalierung wird logarithmisch interpoliert, damit die wahrgenommene Zoomgeschwindigkeit gleichmäßig bleibt. | Muss | Geplant | Gleiche Zeitabschnitte entsprechen gleichmäßigen relativen Zoomschritten. |
| FR-503 | Renderparameter und Palette werden für die Reise eindeutig festgelegt. | Muss | Geplant | Eine Reise liefert bei gleicher Konfiguration reproduzierbare Zwischenbilder. |
| FR-504 | Zwischenbilder verwenden automatisch die für ihre Zoomtiefe erforderliche Präzisionsmethode. | Muss | Geplant | Die Reise überschreitet Präzisionsgrenzen ohne Koordinatensprung oder sichtbaren Methodenbruch. |
| FR-505 | Dauer, Bildrate und Bewegungscharakteristik können vor dem Start gewählt werden. | Soll | Geplant | Mindestens Dauer und Bildrate sind konfigurierbar; Standardwerte erzeugen eine ruhige Reise. |
| FR-506 | Eine Vorschau kann gestartet, pausiert und abgebrochen werden. | Soll | Geplant | Alle drei Aktionen reagieren ohne Verlust gespeicherter Favoriten. |
| FR-507 | Die Reise kann als Videodatei exportiert werden. | Soll | Geplant | Das Video besitzt die gewählte Auflösung, Bildrate und Dauer und enthält keine Bedienelemente. |
| FR-508 | Optional kann eine Reise aus mehr als zwei aufeinanderfolgenden Favoriten zusammengesetzt werden. | Kann | Idee | Mehrere Teilstrecken werden ohne sichtbare Unterbrechung abgespielt. |

#### Fachliche Regeln für kompatible Reisepunkte

- Start und Ziel verwenden denselben Fraktalmodus.
- Beide Punkte enthalten vollständige, valide Koordinaten und Skalierungswerte.
- Bei Mandelbrot-Deep-Zooms werden hochpräzise Koordinaten verwendet.
- Ein Palettenwechsel während einer Teilstrecke findet nur statt, wenn dafür ein
  eigenes Übergangskonzept beschlossen wird.
- „Benachbart“ bezeichnet zunächst zwei bewusst aufeinanderfolgend ausgewählte
  Favoriten; eine automatische geometrische Nachbarschaftserkennung ist nicht
  Voraussetzung der ersten Version.

## 6. Nichtfunktionale Anforderungen

| ID | Anforderung | Priorität | Abnahmekriterium |
|---|---|---:|---|
| NF-001 | Die interaktive Navigation soll unmittelbar reagieren. | Muss | Während Eingaben wird eine angemessene Vorschau gezeigt; Verfeinerung darf anschließend erfolgen. |
| NF-002 | Lange Render- und Exportvorgänge dürfen die Oberfläche nicht dauerhaft blockieren. | Muss | Statusänderungen und Abbruchmöglichkeiten bleiben, soweit vorgesehen, bedienbar. |
| NF-003 | Mathematische Präzision hat bei tiefen Zooms Vorrang vor kurzfristiger Geschwindigkeit. | Muss | Die App zeigt keinen wissentlich falschen Bildausschnitt als fertiges Ergebnis. |
| NF-004 | Gespeicherte Favoriten dürfen bei Synchronisations- oder Lesefehlern nicht verloren gehen. | Muss | Fehlerfälle bewahren die letzte valide lokale Datenbasis. |
| NF-005 | Bedienelemente verwenden verständliche Symbole, Tooltips und etablierte Tastaturkürzel. | Soll | Zentrale Funktionen sind ohne Dokumentation auffindbar und per Hilfe erläuterbar. |
| NF-006 | Exporte sind frei von Fenstern, Statusanzeigen und Kontrollleisten. | Muss | Pixelprüfung eines Exports zeigt ausschließlich das Fraktalbild. |
| NF-007 | Änderungen werden für die betroffene Plattform als Release-Konfiguration gebaut und geprüft. | Muss | Der relevante Release-Build ist erfolgreich; `git diff --check` meldet keine Fehler. |

## 7. Datenschutz und Datenspeicherung

- Favoriten und zugehörige Vorschaubilder werden nur für die Produktfunktion
  gespeichert.
- iCloud-Daten liegen im für Beauty of Fractals konfigurierten Container.
- Bildexporte werden ausschließlich auf ausdrückliche Nutzeraktion erzeugt.
- Die App soll keine Analyse- oder Trackingdaten ohne eine gesondert beschlossene
  und dokumentierte Anforderung übertragen.

## 8. Abgrenzung

Folgende Punkte sind derzeit nicht Bestandteil einer verbindlichen Anforderung:

- soziale Netzwerke oder öffentliche Favoritengalerien
- serverseitiges Rendern
- automatische Veröffentlichung von Exporten
- Änderung der Fraktalparameter während einer Zoomreise
- verlustfreie Echtzeit-Videoberechnung bei beliebiger Deep-Zoom-Tiefe

## 9. Release-Leitlinie

### Produktlinie 2.9

- Stabilisierung und Verfeinerung der bestehenden macOS- und iOS-Funktionen
- kompakte macOS-Kontrollleiste
- direkter Zugriff auf Renderstatus, Diagnose, Favoriten und Export
- verlässliche iCloud-Favoriten und klare Render-/Exportzustände
- Power-of-n-Fraktalfamilie mit Exponenten von 2 bis 12
- neue Pearl-Palette sowie Auric-Innenfärbung für Power of n

### Nachfolgende Produktlinien

- animierte Reise zwischen zwei benachbarten Zoomfavoriten
- Videoexport der Reise
- bei Bedarf mehrteilige Reisen über eine Favoritensequenz
- Import und Export portabler Favoriten über iCloud- und Apple-ID-Grenzen hinweg
- zusätzliche Deep-Zoom-Stufe durch Triple-/Double-Refinement

Die konkrete Versionszuordnung geplanter Anforderungen wird erst bei Aufnahme in
einen Release festgelegt.

## 10. Änderungsprozess

1. Neue Produktideen werden zunächst als **Idee** ergänzt.
2. Nach fachlicher Entscheidung werden Umfang, Priorität und Abnahmekriterium
   festgelegt; der Status wechselt zu **Geplant**.
3. Mit Beginn der Implementierung wechselt der Status zu **In Arbeit**.
4. Nach erfolgreichem Release-Build und fachlicher Abnahme wechselt der Status zu
   **Umgesetzt**.
5. Änderungen an Anforderungen werden gemeinsam mit der zugehörigen
   Implementierung versioniert.
