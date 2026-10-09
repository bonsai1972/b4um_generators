[English](README.md) | Deutsch

# b4um Generators

b4um Generators ist eine Sammlung wiederverwendbarer Rails-Generatoren, Templates, Komponenten und Anwendungsvorgaben
für b4um-Rails-Projekte.

Das Gem bietet eine einheitliche Grundlage für Rails-Anwendungen und enthält Generatoren für Scaffolds, Controller,
Bento-Layouts, Tabellen, Pagination, Infinite Scroll, Suche, Kommentare, Authentifizierung, Attachments und
Rich-Text-Bearbeitung.

Die generierten Komponenten verwenden ein gemeinsames b4um-Styling und sind darauf ausgelegt, miteinander zu
funktionieren.

## Voraussetzungen

- Ruby >= 3.1
- Rails >= 8.0 und < 9.0

## Installation

b4um Generators wird während der Entwicklung derzeit als lokales Gem verwendet.

Füge das Gem zur `Gemfile` der Rails-Anwendung hinzu:

```ruby
gem "b4um_generators", "~> 0.2.0", path: "/pfad/zu/b4um_generators"
```

Führe anschließend aus:

```bash
bundle install
```

## Erste Schritte

Installiere die b4um-Anwendungsvorgaben:

```bash
bin/rails generate b4um:install
```

Der Installer fügt der Rails-Anwendung die gemeinsame b4um-Anwendungsstruktur, Stylesheets, JavaScript-Controller,
Helper und Konfiguration hinzu.

Während der Installation können optionale Funktionen interaktiv ausgewählt werden:

- bcrypt für Passwort-Unterstützung
- Active Storage für Bildanhänge
- Hero-Bereich
- Footer
- Footer-Sitemap
- Cookie-Einwilligung

Die Sitemap steht zur Verfügung, wenn der Footer installiert wird.

Wenn ein optionales Gem ausgewählt wird und noch nicht vorhanden ist, fügt b4um es zur `Gemfile` hinzu und führt
`bundle install` aus.

Wenn Active Storage ausgewählt wird und noch nicht installiert ist, installiert b4um Active Storage und führt die
erforderliche Datenbankmigration aus.

Die zentrale b4um-Konfiguration befindet sich unter:

```text
config/b4um.yml
```

## Generatoren

Das Gem stellt derzeit folgende Generatoren bereit:

```text
b4um:install
b4um:scaffold
b4um:attachment
b4um:bento
b4um:table
b4um:controller
b4um:pagination
b4um:infinite_scroll
b4um:search
b4um:comments
b4um:in_place
b4um:authentication
b4um:trix
b4um:readable
b4um:help
```

Für eine ausführliche Befehlsübersicht und zusätzliche Beispiele:

```bash
bin/rails generate b4um:help
```

## Scaffold-Generator

Erzeuge eine Rails-Ressource mit den b4um-Views und -Komponenten:

```bash
bin/rails generate b4um:scaffold MODEL ATTRIBUTES
```

Beispiel:

```bash
bin/rails generate b4um:scaffold Product name:string description:text price:decimal status:string
```

Der Scaffold-Generator bietet:

- b4um-Formulare
- Index-, Show-, New- und Edit-Views
- Standardmäßig ein Bento-Index-Layout
- Optionales Tabellen-Index-Layout
- Select-Felder mit eigenen Anzeigebezeichnungen
- Radio-Felder mit eigenen Anzeigebezeichnungen
- Automatischen Navigationseintrag
- Aktiven Navigationszustand
- Anzeige von Formular-Validierungsfehlern
- Flash-Meldungen
- Unterstützung für Passwortfelder
- Optionale lesbare URL-Parameter

### Select- und Radio-Felder

Der Scaffold-Generator kann String-Attribute als Select- oder Radio-Felder mit eigenen Anzeigebezeichnungen erzeugen.

Für ein Select-Feld verwende:

```text
--select='FIELD:VALUE=LABEL,VALUE=LABEL'
```

Beispiel:

```bash
bin/rails generate b4um:scaffold Product name:string status:string --select='status:Active=Aktiv,Inactive=Inaktiv'
```

Für Radio-Buttons verwende:

```text
--radio='FIELD:VALUE=LABEL,VALUE=LABEL'
```

Beispiel:

```bash
bin/rails generate b4um:scaffold Product name:string condition:string --radio='condition:new=Neu,used=Gebraucht,refurbished=Generalüberholt'
```

Beide Optionen können für unterschiedliche Felder miteinander kombiniert werden:

```bash
bin/rails generate b4um:scaffold Product name:string status:string condition:string --select='status:Active=Aktiv,Inactive=Inaktiv' --radio='condition:new=Neu,used=Gebraucht'
```

Die konfigurierten Werte werden in der Datenbank gespeichert. In Formularen, Ressourcen-Views und Tabellen-Layouts
werden dagegen die zugehörigen Anzeigebezeichnungen dargestellt.

Dasselbe Feld kann nicht gleichzeitig `--select` und `--radio` verwenden.

### Bento-Index

Der standardmäßige Scaffold-Index verwendet das responsive b4um-Bento-Kartenlayout.

### Tabellen-Index

Um stattdessen einen tabellenbasierten Index zu erzeugen, verwende:

```bash
bin/rails generate b4um:scaffold Product name:string description:text price:decimal status:string --layout=table
```

Tabellen-Layouts bieten automatisch:

- Responsives b4um-Tabellen-Styling
- Kürzung von Textfeldern auf 100 Zeichen
- Darstellung von Statusfeldern als b4um-Badges
- Aktionsspalte
- Empty-State-Darstellung

### Lesbare URL-Parameter

Ein Scaffold kann lesbare URLs erzeugen und dabei die Datenbank-ID in der URL beibehalten.

Verwende:

```text
--param=ATTRIBUTE
```

Beispiel:

```bash
bin/rails generate b4um:scaffold Article title:string body:text --param=title
```

Dadurch entstehen URLs wie:

```text
/articles/17-my-first-article
```

Die ID bleibt Bestandteil der URL, sodass die normale Rails-Ressourcensuche weiterhin verwendet werden kann.

Der lesbare Teil wird aus dem ausgewählten Attribut erzeugt und ändert sich automatisch, wenn sich dieses Attribut
ändert.

Lesbare URLs können auch später zu einem bestehenden Modell hinzugefügt werden:

```bash
bin/rails generate b4um:readable Product name
```

## Bento und Karten

b4um enthält ein responsives Kartensystem, das auch unabhängig von den Generatoren verwendet werden kann.

Grundlegendes Beispiel:

```html
<div class="b4um-grid">
  <article class="b4um-card">...</article>
</div>
```

Verfügbare Kartenvarianten:

```text
b4um-card
b4um-card--wide
b4um-card--large
b4um-card--full
b4um-card--soft
```

Häufig verwendete Klassen für Karteninhalte:

```text
b4um-card__eyebrow
b4um-card__title
b4um-card__text
b4um-card__actions
b4um-card__media
b4um-card__image
```

Das Kartenraster passt sich automatisch an Tablet- und Mobil-Layouts an.

### Bento-Generator

Erzeuge ein wiederverwendbares Layout für ein bestehendes Modell:

```bash
bin/rails generate b4um:bento Product
```

Das Standardlayout ist `grid`.

Verfügbare Layouts:

```bash
bin/rails generate b4um:bento Product --layout=grid
bin/rails generate b4um:bento Product --layout=list
bin/rails generate b4um:bento Product --layout=alternating
bin/rails generate b4um:bento Product --layout=bento
```

Die Layouts:

- `grid` — responsives Kartenraster mit drei Spalten
- `list` — kompaktes horizontales Listenlayout
- `alternating` — großzügiges, abwechselndes Inhaltslayout
- `bento` — klassisches Bento-Layout mit unterschiedlichen Kartengrößen

Das Modell und das zugehörige Ressourcen-Partial müssen bereits vorhanden sein.

Für ein `Product`-Modell wird das generierte Partial hier gespeichert:

```text
app/views/products/_bento.html.erb
```

Einbindung:

```erb
<%= render "bento", products: @products %>
```

Das Partial verwendet eine lokale Collection und kann daher auch mit einer anderen Collection wiederverwendet werden:

```erb
<%= render "products/bento", products: @featured_products %>
```

## Tabellen-Generator

Erzeuge eine wiederverwendbare b4um-Tabelle für ein bestehendes Modell:

```bash
bin/rails generate b4um:table MODEL [FIELDS]
```

Das Modell muss bereits vorhanden sein.

Die Felder sind optional. Werden keine Felder angegeben, erkennt der Generator automatisch die Datenbankfelder des
Modells, Action-Text-Felder und Active-Storage-Anhänge. `id`, `created_at` und `updated_at` werden automatisch
ausgeschlossen.

Empfohlen:

```bash
bin/rails generate b4um:table Product
```

Felder können weiterhin ausdrücklich angegeben werden:

```bash
bin/rails generate b4um:table Product name price status
```

Konfigurierte Select- und Radio-Werte können mit ihren Beschriftungen dargestellt werden:

```bash
bin/rails generate b4um:table Product \
  --select="status:active=Aktiv,inactive=Inaktiv" \
  --radio="condition:new=Neu,used=Gebraucht"
```

Für ein `Product`-Modell wird das generierte Partial hier gespeichert:

```text
app/views/products/_table.html.erb
```

Die generierte Tabelle bietet:

- Automatische Felderkennung aus dem bestehenden Modell
- Responsives Tabellenlayout
- Erkennung der tatsächlichen Feldtypen des Modells
- Kürzung von Textfeldern auf 100 Zeichen
- Formatierung von Dezimalwerten mit zwei Nachkommastellen
- Darstellung von Statusfeldern als b4um-Badges
- Beschriftungen für konfigurierte `--select`- und `--radio`-Werte
- Action-Text-/Trix-Inhalte
- Lightbox für Bilder innerhalb von Rich Text
- Übernahme von Trix-Bildbeschriftungen in die Lightbox
- Active-Storage-`has_one_attached`-Bilder
- Active-Storage-`has_many_attached`-Galerien
- Vorschaubilder, Lightbox-Navigation und Ziehen/Wischen
- Aktionsspalte mit Show-Button
- Empty-State-Darstellung

Beim Aufruf des Tabellen-Generators wird eine vorhandene b4um-Index-Ansicht automatisch auf das Tabellen-Partial
umgestellt:

```erb
<%= render "table", products: @products %>
```

Wird später `b4um:bento Product` ausgeführt, stellt der Generator den Index wieder auf das Bento-Partial zurück. Das
gilt auch für die Bento-Layouts `grid`, `list` und `alternating`.

Das Tabellen-Partial kann auch mit einer anderen Collection verwendet werden:

```erb
<%= render "products/table", products: @featured_products %>
```

## Controller-Generator

Erzeuge einen Controller und seine Actions mit:

```bash
bin/rails generate b4um:controller NAME ACTIONS
```

Beispiel:

```bash
bin/rails generate b4um:controller Pages home about impressum agb
```

Der Controller-Generator:

- Verwendet den Standard-Rails-Controller-Generator
- Erstellt die gewünschten Actions und Views
- Fügt reguläre Action-Links automatisch zur b4um-Navigation hinzu
- Fügt unterstützte rechtliche Seiten automatisch zum b4um-Footer hinzu
- Hält rechtliche Seiten aus der Hauptnavigation heraus

Erkannte deutsche rechtliche Seiten:

```text
impressum
datenschutz
agb
```

Erkannte englische rechtliche Seiten:

```text
imprint
privacy
privacy_policy
terms
terms_and_conditions
```

Footer-Links setzen voraus, dass der b4um-Footer installiert ist.

Controller-Actions können außerdem direkt einer Sitemap-Spalte zugewiesen werden:

```bash
bin/rails generate b4um:controller Pages faq support --sitemap=column_3
```

## Passwort-Unterstützung

Definiere für die Passwort-Authentifizierung ein `password_digest`-Attribut:

```bash
bin/rails generate b4um:scaffold User name:string email:string password_digest:string
```

Der Scaffold-Generator erzeugt automatisch Passwortfelder, anstatt `password_digest` direkt anzuzeigen.

Die Passwort-Unterstützung benötigt bcrypt.

bcrypt kann während der Installation ausgewählt werden:

```bash
bin/rails generate b4um:install
```

Falls erforderlich, fügt b4um bcrypt zur `Gemfile` der Anwendung hinzu und installiert es.

## Authentifizierung

Füge einem bestehenden Modell eine sitzungsbasierte Authentifizierung hinzu:

```bash
bin/rails generate b4um:authentication MODEL
```

Beispiel:

```bash
bin/rails generate b4um:authentication User
```

Das Authentifizierungsmodell kann einen beliebigen Namen haben, zum Beispiel:

```text
User
Admin
Member
```

Das ausgewählte Modell muss:

- Bereits vorhanden sein
- `has_secure_password` verwenden
- Eine `password_digest`-Spalte besitzen
- bcrypt verwenden

Für die Anmeldung verwendet die Authentifizierung ein `email`-Attribut.

Ein vollständiges Beispiel:

```bash
bin/rails generate b4um:scaffold User name:string email:string password_digest:string
bin/rails generate b4um:authentication User
```

Der Authentifizierungs-Generator fügt Folgendes hinzu:

- Sessions-Controller
- Anmeldeformular
- Login- und Logout-Routen
- Sitzungsbasierten Helper für das aktuell angemeldete Konto
- `logged_in?`-Helper
- `require_login`-Helper
- Login- und Logout-Elemente in der Navigation

Der Name des generierten Helpers richtet sich nach dem ausgewählten Modell.

Für `User`:

```ruby
current_user
```

Für `Admin`:

```ruby
current_admin
```

### Controller schützen

Bestehende Controller können bei der Einrichtung der Authentifizierung optional geschützt werden.

Verwende `--protect` mit dem Namen des Controllers:

```bash
bin/rails generate b4um:authentication User --protect=Products
```

Der Generator fügt dem ausgewählten Controller folgende Authentifizierungsanforderung hinzu:

```ruby
before_action :require_login, except: [:index, :show]
```

Dadurch bleiben `index` und `show` öffentlich erreichbar. Für Aktionen wie `new`, `create`, `edit`, `update` und
`destroy` ist dagegen eine Anmeldung erforderlich.

Mehrere Controller können gleichzeitig geschützt werden, indem ihre Namen durch Kommas getrennt werden:

```bash
bin/rails generate b4um:authentication User --protect=Products,Articles
```

Weitere Controller können auch später geschützt werden, indem der Authentifizierungs-Generator erneut ausgeführt wird:

```bash
bin/rails generate b4um:authentication User --protect=Comments
```

Die bereits vorhandene Authentifizierung wird dabei weiterverwendet. Authentifizierungs-Helper, Routen,
Navigationselemente und Controller-Schutz werden nicht dupliziert.

Der Generator prüft die angegebenen Controller, bevor Änderungen an der Anwendung vorgenommen werden. Existiert ein
angeforderter Controller nicht, bricht der Generator mit einer Fehlermeldung ab, bevor Dateien verändert werden.

Der Generator prüft außerdem seine Authentifizierungsvoraussetzungen, bevor Änderungen an der Anwendung vorgenommen
werden. Fehlt eine erforderliche Voraussetzung, bricht der Generator mit einer hilfreichen Fehlermeldung und einem
passenden Vorschlag für einen b4um-Scaffold-Befehl ab.

Bei wiederholter Ausführung werden Authentifizierungs-Helper, Routen, Navigationselemente und Controller-Schutz nicht
dupliziert.

## Active Storage und Bilder

Bildanhänge verwenden Rails Active Storage.

Active Storage kann während der Installation ausgewählt werden:

```bash
bin/rails generate b4um:install
```

Wenn Active Storage noch nicht installiert ist, installiert b4um es und führt die erforderliche Migration aus.

### Einzelnes Bild in einem neuen Scaffold

Verwende:

```text
image:attachment
```

Beispiel:

```bash
bin/rails generate b4um:scaffold Article title:string image:attachment
```

### Mehrere Bilder in einem neuen Scaffold

Verwende:

```text
images:attachments
```

Beispiel:

```bash
bin/rails generate b4um:scaffold Gallery title:string images:attachments
```

### Attachment-Generator

Attachments können auch später zu einer bestehenden b4um-Ressource hinzugefügt werden.

Für ein einzelnes Attachment:

```bash
bin/rails generate b4um:attachment MODEL ATTACHMENT
```

Beispiel:

```bash
bin/rails generate b4um:attachment Admin avatar
```

Dadurch wird hinzugefügt:

```ruby
has_one_attached :avatar
```

Für mehrere Attachments verwende `--multiple`:

```bash
bin/rails generate b4um:attachment MODEL ATTACHMENT --multiple
```

Beispiel:

```bash
bin/rails generate b4um:attachment Product images --multiple
```

Dadurch wird hinzugefügt:

```ruby
has_many_attached :images
```

Wenn die entsprechenden b4um-Dateien vorhanden sind, aktualisiert der Attachment-Generator außerdem:

- Das bestehende Modell
- Das bestehende b4um-Formular
- Die Controller-Parameter
- Das bestehende b4um-Ressourcen-Partial

Mehrere Attachments unterstützen zusätzlich:

- Hinzufügen neuer Bilder, ohne bestehende Bilder zu ersetzen
- Entfernen einzelner bestehender Bilder
- Vorschau mehrerer Bilder
- Bildergalerie mit Lightbox-Navigation

Bei wiederholter Ausführung wird eine bestehende Attachment-Konfiguration nicht dupliziert.

Die Bildunterstützung umfasst:

- Active-Storage-Integration
- Bildvorschau vor dem Speichern
- Vorschau bestehender Bilder beim Bearbeiten
- Hinzufügen neuer Bilder, ohne bestehende Bilder zu entfernen
- Entfernen einzelner bestehender Bilder
- Bild-Lightbox
- Vorher-/Weiter-Navigation
- Maus- und Touch-Swipe
- Tastaturnavigation

## Pagination

Füge einer bestehenden Ressource serverseitige Pagination hinzu:

```bash
bin/rails generate b4um:pagination Product
```

Standardmäßig werden 20 Datensätze pro Seite angezeigt.

Eine eigene Seitengröße kann angegeben werden:

```bash
bin/rails generate b4um:pagination Product --per-page=50
```

Modell, Controller und Index-View müssen bereits vorhanden sein.

Pagination bietet:

- Serverseitige Pagination mit Active Record `limit` und `offset`
- Kein zusätzliches Pagination-Gem erforderlich
- Vorher-/Weiter-Navigation
- Nummerierte Seitennavigation
- Beibehaltung bestehender Query-Parameter
- Integration mit Bento- und Tabellen-Layouts
- Sichere Behandlung ungültiger oder zu großer Seitennummern

## Infinite Scroll

Füge einer bestehenden Ressource automatisches Infinite Scrolling hinzu:

```bash
bin/rails generate b4um:infinite_scroll Product
```

Standardmäßig werden 20 Datensätze pro Seite geladen.

Eine eigene Seitengröße kann angegeben werden:

```bash
bin/rails generate b4um:infinite_scroll Product --per-page=50
```

Modell, Controller und Index-View müssen bereits vorhanden sein.

Infinite Scroll bietet:

- Automatisches Nachladen beim Scrollen
- Serverseitige Pagination mit Active Record `limit` und `offset`
- Kein zusätzliches Pagination-Gem erforderlich
- Integration mit Bento- und Tabellen-Layouts
- Beibehaltung bestehender Query-Parameter
- Automatisches Beenden nach der letzten Seite
- Ersetzen einer bestehenden b4um-Pagination-Navigation
- Sichere wiederholte Ausführung des Generators

## Suche

Füge einer bestehenden Ressource eine datenbankgestützte Suche hinzu:

```bash
bin/rails generate b4um:search Product
```

Modell, Controller und Index-View müssen bereits vorhanden sein.

Die Suche bietet:

- Suche über String- und Text-Spalten
- Groß-/Kleinschreibung ignorierende Teiltreffer
- Sicheres Escaping von Suchbegriffen
- Vollständige Collection bei leerer Suche
- Integration mit Bento- und Tabellen-Layouts
- Integration mit Pagination und Infinite Scroll
- Beibehaltung des Suchbegriffs beim Navigieren zwischen Seiten
- Kein zusätzliches Such-Gem erforderlich
- Sichere wiederholte Ausführung des Generators

## Kommentare

Füge einem bestehenden Modell polymorphe Kommentare hinzu:

```bash
bin/rails generate b4um:comments Article
```

Der Kommentar-Generator bietet:

- Polymorphes `Comment`-Modell
- Kommentar-Verknüpfung am ausgewählten Modell
- Verschachtelte Create- und Destroy-Routen
- Comments-Controller
- Kommentarliste und Formular
- Löschbestätigung
- b4um-Formular- und Karten-Styling
- Unterstützung mehrerer kommentierbarer Modelle
- Sichere wiederholte Ausführung des Generators

Weitere Modelle können dasselbe Kommentarsystem verwenden:

```bash
bin/rails generate b4um:comments Product
```

Bestehende b4um-Comments-Controller werden automatisch erweitert.

Unbekannte benutzerdefinierte Comments-Controller bleiben unverändert und führen dazu, dass der Generator abbricht,
anstatt eigenen Code zu überschreiben.

## In-place Editing

Füge Feldern einer bestehenden b4um-Ressource eine direkte Bearbeitung hinzu:

```bash
bin/rails generate b4um:in_place MODEL FIELD [FIELD ...]
```

Beispiel für ein einzelnes Feld:

```bash
bin/rails generate b4um:in_place Product name
```

Mehrere Felder können in einem Durchlauf hinzugefügt werden:

```bash
bin/rails generate b4um:in_place Product name price status
```

Modell, Controller und Resource-Routen müssen bereits vorhanden sein.

Der Generator erkennt die vorhandenen Feldtypen automatisch und erstellt die passenden Editoren.

Unterstützte Felder sind:

- String- und Text-Felder
- Numerische und Decimal-Felder
- Boolean-Felder
- Action-Text-Rich-Text-Felder
- Einzelne Active-Storage-Bild-Attachments
- Mehrere Active-Storage-Bild-Attachments

### Select-Felder

Ein Feld kann mit `--select` als Auswahlliste dargestellt werden:

```bash
bin/rails generate b4um:in_place Product status --select='status:Active=Aktiv,Inactive=Inaktiv'
```

Der Wert vor `=` wird in der Datenbank gespeichert. Der optionale Wert nach `=` wird als sichtbare Beschriftung
verwendet.

Zum Beispiel speichert `Active=Aktiv` den Wert `Active`, während `Aktiv` angezeigt wird.

### Radio-Felder

Ein Feld kann mit `--radio` als Gruppe von Radio-Buttons dargestellt werden:

```bash
bin/rails generate b4um:in_place Product condition --radio='condition:new=Neu,used=Gebraucht,refurbished=Generalüberholt'
```

Für Radio-Felder gilt dieselbe Wert- und Beschriftungssyntax wie für `--select`.

### Verhalten der In-place-Bearbeitung

Die generierte In-place-Bearbeitung bietet:

- Bearbeitung mit Turbo Frames ohne zusätzliches In-place-Editing-Gem
- Direkte Bearbeitung innerhalb des bestehenden Ressourcen-Layouts
- Speichern von Text- und Rich-Text-Feldern beim Klick außerhalb des Editors
- Sofortiges Speichern von Select-, Radio- und Boolean-Feldern
- Bearbeitung einzelner und mehrerer Bild-Attachments
- Entfernen vorhandener Bild-Attachments
- Validierungsfehler direkt im Editor
- Sofortige Aktualisierung der Flash-Meldung nach erfolgreicher Änderung
- Mehrere Felder in einem Generator-Durchlauf
- Nachträgliches Hinzufügen weiterer Felder
- Sichere wiederholte Ausführung des Generators

### Authentifizierung

Die In-place-Bearbeitung integriert sich automatisch in die b4um-Authentifizierung.

Ohne Authentifizierung können die generierten In-place-Felder bearbeitet werden.

Wenn die b4um-Authentifizierung installiert ist, wird die In-place-Bearbeitung auf angemeldete Benutzer beschränkt und
die zugehörigen Controller-Actions werden mit `require_login` geschützt.

Die Authentifizierung kann vor oder nach der In-place-Bearbeitung installiert werden. Die Generatoren aktualisieren die
Integration in beiden Installationsreihenfolgen automatisch.

## Trix und Rich Text

Füge einer bestehenden b4um-Ressource Rails Action Text mit Trix hinzu:

```bash
bin/rails generate b4um:trix MODEL ATTRIBUTE
```

Beispiel:

```bash
bin/rails generate b4um:trix Article content
```

Modell und Formular müssen bereits vorhanden sein.

Der Generator fügt hinzu:

```ruby
has_rich_text :content
```

und ersetzt das ausgewählte Formularfeld durch einen Rich-Text-Editor:

```ruby
form.rich_text_area :content
```

Die b4um-Trix-Integration bietet:

- Automatische Installation von Action Text, falls erforderlich
- Rich-Text-Verknüpfung im Modell
- Austausch ausschließlich des ausgewählten Formularfeldes
- Kompakte Plain-Text-Vorschauen in Bento-Karten
- Bild-Lightbox
- Vorher-/Weiter-Navigation für Bilder
- Maus- und Touch-Swipe
- Tastaturnavigation
- Responsive Bildergalerien
- Sticky Trix Toolbar
- Überschriften H1 bis H6
- Linke, zentrierte und rechte Textausrichtung
- Text- und Hintergrundfarben
- Horizontale Trennlinien
- Editierbare `DIV`-, `SECTION`- und `ARTICLE`-Container mit IDs
- Editierbare Container-Formatierung
- Entfernen aktiver Container-Wrapper
- Sichere wiederholte Ausführung des Generators

## Hero-Bereich

Der Installer kann optional einen Hero-Bereich erstellen.

Wähle ihn bei der Ausführung von:

```bash
bin/rails generate b4um:install
```

Das generierte Partial befindet sich unter:

```text
app/views/shared/_hero.html.erb
```

Der Hero funktioniert standardmäßig auch ohne Bild und enthält Beispiele für:

- Hero-Titel und Text
- Optionalen Aktionslink
- Optionales Hero-Bild

Die Hero-CSS-Klassen verwenden das Präfix `b4um-hero`.

## Footer und Sitemap

Der b4um-Footer ist optional und kann während der interaktiven Installation ausgewählt werden:

```text
Add a footer? (y/n)
```

Der generierte Footer befindet sich unter:

```text
app/views/shared/_footer.html.erb
```

Er bietet:

- Automatisches aktuelles Jahr
- Platzhalter für den Anwendungsnamen
- Automatische Links zu rechtlichen Seiten, die mit `b4um:controller` erzeugt wurden
- Optionale Sitemap
- Optionale Cookie-Einstellungen

Wenn der Footer installiert wird, kann b4um optional eine Sitemap hinzufügen:

```text
Add a sitemap to the footer? (y/n)
```

Die Sitemap wird als separates Partial installiert und nur dann im Footer gerendert, wenn sie ausgewählt wurde.

Das generierte Sitemap-Partial befindet sich unter:

```text
app/views/shared/_sitemap.html.erb
```

Der zugehörige Stimulus-Controller befindet sich unter:

```text
app/javascript/controllers/sitemap_controller.js
```

### Sitemap-Spalten

Wenn die Sitemap aktiviert wird, kann während der Installation die Anzahl der Sitemap-Spalten ausgewählt werden:

```text
Number of sitemap columns [4]:
```

Die Sitemap unterstützt zwischen 2 und 5 Spalten.

Drücke Enter, um den Standardwert von 4 Spalten zu verwenden.

Nach Auswahl der Spaltenanzahl fragt b4um nach dem Titel jeder ausgewählten Spalte.

Beispiel mit vier Spalten:

```text
Sitemap column 1 title [Kontakt]:
Sitemap column 2 title [Inhalte]:
Sitemap column 3 title [Service]:
Sitemap column 4 title [Mehr]:
```

Bei fünf Spalten steht eine zusätzliche Spalte zur Verfügung:

```text
Sitemap column 5 title [Weitere]:
```

Drücke Enter, um den jeweils in Klammern angezeigten Standardtitel beizubehalten.

Nur die ausgewählte Anzahl von Spalten wird in `config/b4um.yml` geschrieben.

Die Standardkonfiguration mit vier Spalten sieht beispielsweise so aus:

```yaml
sitemap:
  - key: column_1
    title: Kontakt
  - key: column_2
    title: Inhalte
  - key: column_3
    title: Service
  - key: column_4
    title: Mehr

legal_links:
  placement: footer
```

Eine Sitemap mit zwei Spalten enthält nur `column_1` und `column_2`. Eine Sitemap mit fünf Spalten enthält zusätzlich
`column_5`.

Die Titel können später durch Bearbeiten von `config/b4um.yml` geändert werden.

Die Schlüssel `column_1` bis `column_5` identifizieren die Sitemap-Spalten unabhängig von ihren sichtbaren Titeln.

Es sollten nur Schlüssel für Spalten verwendet werden, die in der aktuellen Konfiguration tatsächlich vorhanden sind.

Auf größeren Bildschirmen werden die konfigurierten Sitemap-Spalten automatisch über den Footer verteilt. Auf kleineren
Bildschirmen verwendet die Sitemap ihr responsives, einklappbares Layout.

### Seiten zur Sitemap hinzufügen

Controller-Actions können direkt einer Sitemap-Spalte zugewiesen werden:

```bash
bin/rails generate b4um:controller Pages faq support --sitemap=column_3
```

Wenn `--sitemap` verwendet wird, werden die generierten Actions der ausgewählten Sitemap-Spalte hinzugefügt und nicht
der Hauptnavigation.

Die Einträge werden in `config/b4um.yml` gespeichert.

Sitemap-Links verwenden Rails-Route-Helper:

```yaml
links:
  - title: FAQ
    route: faq_path
```

Nur gültige Rails-Path-Helper, die auf `_path` enden, werden vom b4um-Sitemap-Helper aufgelöst.

### Rechtliche Links

Rechtliche Seiten verwenden standardmäßig den separaten rechtlichen Bereich des Footers:

```yaml
legal_links:
  placement: footer
```

Alternativ können sie einer bestehenden Sitemap-Spalte zugewiesen werden:

```yaml
legal_links:
  placement: column_4
```

Wenn rechtliche Seiten einer Sitemap-Spalte zugewiesen sind, fügt b4um sie automatisch dieser Spalte hinzu und
dupliziert sie nicht zusätzlich im separaten rechtlichen Footer-Bereich.

Für die Platzierung wird der Sitemap-Spaltenschlüssel und nicht der sichtbare Titel verwendet. Dadurch können die
Spaltentitel frei geändert werden.

## Cookie-Einwilligung

Die Cookie-Einwilligung kann während der b4um-Installation optional aktiviert werden:

```text
Add cookie consent? (y/n)
```

Die Cookie-Einwilligung kann unabhängig vom Footer installiert werden.

Wenn sie aktiviert wird, erstellt b4um:

```text
app/views/shared/_cookie_consent.html.erb
app/javascript/controllers/cookie_consent_controller.js
```

Die Einwilligungsentscheidung des Besuchers wird im Local Storage des Browsers gespeichert.

Wenn sowohl Footer als auch Cookie-Einwilligung installiert sind, fügt b4um dem Footer automatisch eine
`Cookie-Einstellungen`-Schaltfläche hinzu.

Damit können Besucher das Cookie-Banner erneut öffnen und ihre Auswahl später ändern.

Wenn die Cookie-Einwilligung ohne Footer installiert wird, funktioniert das Banner weiterhin. Es wird lediglich keine
Schaltfläche für die Cookie-Einstellungen im Footer hinzugefügt.

## Hilfe

Für die vollständige integrierte Übersicht der Generatoren, Optionen und Funktionen:

```bash
bin/rails generate b4um:help
```

## Entwicklung

Installiere nach dem Auschecken des Repositorys zunächst die Abhängigkeiten:

```bash
bin/setup
```

Führe die vollständige Testsuite aus mit:

```bash
bundle exec rspec
```

Führe RuboCop aus mit:

```bash
bundle exec rubocop
```

Prüfe Änderungen auf Whitespace-Fehler mit:

```bash
git diff --check
```

Das Gem kann lokal getestet werden, indem das Repository über `path:` in der `Gemfile` einer Rails-Anwendung eingebunden
wird.

## Version

Aktuelle Version: `0.2.17`

## Autor

Alexander Baum

b4um

https://www.b4um.com

## Lizenz

b4um Generators ist unter den Bedingungen der MIT-Lizenz verfügbar.
