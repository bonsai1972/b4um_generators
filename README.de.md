[English](README.md) | Deutsch

# b4um Generators

b4um Generators ist eine Sammlung wiederverwendbarer Rails-Generatoren, Templates und Anwendungsvorgaben für
b4um-Rails-Projekte.

Das Gem stellt Generatoren für häufig benötigte Anwendungskomponenten wie Layouts, Controller, Scaffolds, Tabellen,
Pagination, Suche, Kommentare und Rich-Text-Bearbeitung bereit.

## Voraussetzungen

- Ruby >= 3.1
- Rails >= 8.0 und < 9.0

## Installation

b4um Generators wird während der Entwicklung derzeit als lokales Gem verwendet.

Füge das Gem zur `Gemfile` der Rails-Anwendung hinzu:

```ruby
gem "b4um_generators", "~> 0.1.0", path: "/path/to/b4um_generators"
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

Der Installer fügt der Rails-Anwendung die gemeinsame b4um-Anwendungsstruktur und -Konfiguration hinzu.

Während der Installation können optionale Komponenten wie Hero-Bereich, Footer, Footer-Sitemap und Cookie-Einwilligung
interaktiv ausgewählt werden.

Die zentrale b4um-Konfiguration wird gespeichert unter:

```text
config/b4um.yml
```

## Generatoren

Das Gem stellt derzeit folgende Generatoren bereit:

```text
b4um:install
b4um:scaffold
b4um:bento
b4um:table
b4um:controller
b4um:pagination
b4um:infinite_scroll
b4um:search
b4um:comments
b4um:trix
b4um:help
```

Ausführliche Informationen zur Verwendung und Beispiele erhältst du mit:

```bash
bin/rails generate b4um:help
```

## Footer und Sitemap

Der b4um-Footer ist optional und kann während der interaktiven Einrichtung installiert werden:

```text
Add a footer? (y/n)
```

Wenn der Footer installiert wird, kann b4um diesem optional eine Sitemap hinzufügen:

```text
Add a sitemap to the footer? (y/n)
```

Die Sitemap wird als separates Partial installiert und nur dann innerhalb des Footers gerendert, wenn sie bei der
Installation ausgewählt wurde.

Das erzeugte Sitemap-Partial befindet sich unter:

```text
app/views/shared/_sitemap.html.erb
```

Der zugehörige Stimulus-Controller befindet sich unter:

```text
app/javascript/controllers/sitemap_controller.js
```

### Sitemap-Spalten

Wenn die Sitemap aktiviert ist, kann während der Installation die Anzahl der Sitemap-Spalten ausgewählt werden:

```text
Number of sitemap columns [4]:
```

Die Sitemap unterstützt zwischen 2 und 5 Spalten. Drücke Enter, um die voreingestellten 4 Spalten zu verwenden.

Nach Auswahl der Spaltenanzahl fragt b4um nach dem Titel jeder ausgewählten Spalte.

Beispielsweise bei vier Spalten:

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

Drücke Enter, um den jeweils in Klammern angezeigten Standardtitel zu übernehmen.

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

Eine Sitemap mit zwei Spalten enthält nur `column_1` und `column_2`. Bei einer Sitemap mit fünf Spalten kommt zusätzlich
`column_5` hinzu.

Die Titel können später auch durch Bearbeiten von `config/b4um.yml` geändert werden.

Die Spaltenschlüssel (`column_1` bis `column_5`) identifizieren die Sitemap-Spalten und werden verwendet, wenn
generierte Seiten einer Spalte zugeordnet werden. Es sollten nur Schlüssel für Spalten verwendet werden, die in der
aktuellen Konfiguration vorhanden sind.

Auf größeren Bildschirmen werden die vorhandenen Sitemap-Spalten automatisch über den Footer verteilt. Auf kleineren
Bildschirmen bleibt die Sitemap responsiv und verwendet ihr einklappbares mobiles Layout.

### Seiten zur Sitemap hinzufügen

Controller-Actions können direkt einer Sitemap-Spalte zugeordnet werden:

```bash
bin/rails generate b4um:controller Pages faq support --sitemap=column_3
```

Die erzeugten Sitemap-Einträge werden der ausgewählten Spalte in `config/b4um.yml` hinzugefügt.

Sitemap-Links verwenden Rails-Route-Helper wie beispielsweise:

```yaml
links:
  - title: FAQ
    route: faq_path
```

Vom b4um-Sitemap-Helper werden nur gültige Rails-Path-Helper aufgelöst, die auf `_path` enden.

### Rechtliche Links

Rechtliche Seiten verwenden standardmäßig den separaten rechtlichen Bereich des Footers:

```yaml
legal_links:
  placement: footer
```

Alternativ können sie einer vorhandenen Sitemap-Spalte zugeordnet werden:

```yaml
legal_links:
  placement: column_4
```

Wenn rechtliche Seiten in einer Sitemap-Spalte platziert werden, werden sie nicht zusätzlich im separaten rechtlichen
Footer-Bereich angezeigt.

## Cookie-Einwilligung

Die Cookie-Einwilligung kann während der b4um-Einrichtung optional installiert werden:

```text
Add cookie consent? (y/n)
```

Wenn sie aktiviert wird, installiert b4um das Cookie-Consent-Partial und den zugehörigen Stimulus-Controller.

Die erzeugten Dateien sind:

```text
app/views/shared/_cookie_consent.html.erb
app/javascript/controllers/cookie_consent_controller.js
```

Die Einwilligungsentscheidung des Besuchers wird im Local Storage des Browsers gespeichert.

Wenn sowohl der Footer als auch die Cookie-Einwilligung installiert sind, fügt b4um dem Footer eine Schaltfläche
`Cookie-Einstellungen` hinzu. Darüber können Besucher das Cookie-Banner erneut öffnen und ihre Auswahl später ändern.

Die Cookie-Einwilligung kann auch ohne Footer installiert werden.

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

Das Gem kann lokal getestet werden, indem das Repository über `path:` in der `Gemfile` einer Rails-Anwendung eingebunden
wird.

## Version

Aktuelle Version: `0.1.0`

## Autor

Alexander Baum

b4um

https://www.b4um.com

## Lizenz

b4um Generators ist unter den Bedingungen der MIT-Lizenz verfügbar.
