English | [Deutsch](README.de.md)

# b4um Generators

b4um Generators is a collection of reusable Rails generators, templates and application defaults for b4um Rails
projects.

The gem provides generators for common application components such as layouts, controllers, scaffolds, tables,
pagination, search, comments and rich-text editing.

## Requirements

- Ruby >= 3.1
- Rails >= 8.0 and < 9.0

## Installation

b4um Generators is currently used as a local gem during development.

Add the gem to the Rails application's `Gemfile`:

```ruby
gem "b4um_generators", "~> 0.1.0", path: "/path/to/b4um_generators"
```

Then run:

```bash
bundle install
```

## Getting Started

Install the b4um application defaults:

```bash
bin/rails generate b4um:install
```

The installer adds the shared b4um application structure and configuration to the Rails application.

During installation, optional components such as the hero section, footer, footer sitemap and cookie consent can be
selected interactively.

The central b4um configuration is stored in:

```text
config/b4um.yml
```

## Generators

The gem currently provides the following generators:

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

For detailed usage information and examples, run:

```bash
bin/rails generate b4um:help
```

## Footer and Sitemap

The b4um footer is optional and can be installed during the interactive setup:

```text
Add a footer? (y/n)
```

If the footer is installed, b4um can optionally add a sitemap to it:

```text
Add a sitemap to the footer? (y/n)
```

The sitemap is installed as a separate partial and rendered inside the footer only when it has been selected.

The generated sitemap partial is stored in:

```text
app/views/shared/_sitemap.html.erb
```

Its Stimulus controller is stored in:

```text
app/javascript/controllers/sitemap_controller.js
```

### Sitemap Columns

When the sitemap is enabled, the number of sitemap columns can be selected during installation:

```text
Number of sitemap columns [4]:
```

The sitemap supports between 2 and 5 columns. Press Enter to use the default of 4 columns.

After selecting the number of columns, b4um asks for the title of each selected column.

For example, with four columns:

```text
Sitemap column 1 title [Kontakt]:
Sitemap column 2 title [Inhalte]:
Sitemap column 3 title [Service]:
Sitemap column 4 title [Mehr]:
```

With five columns, an additional column is available:

```text
Sitemap column 5 title [Weitere]:
```

Press Enter to keep the default title shown in brackets.

Only the selected number of columns is written to `config/b4um.yml`.

For example, the default four-column configuration is:

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

A two-column sitemap contains only `column_1` and `column_2`, while a five-column sitemap additionally contains
`column_5`.

The titles can also be changed later by editing `config/b4um.yml`.

The column keys (`column_1` through `column_5`) identify the sitemap columns and are used when assigning generated pages
to a column. Only keys for columns that exist in the current configuration should be used.

On larger screens, the available sitemap columns are distributed automatically across the footer. On smaller screens,
the sitemap remains responsive and uses its collapsible mobile layout.

### Adding Pages to the Sitemap

Controller actions can be assigned directly to a sitemap column:

```bash
bin/rails generate b4um:controller Pages faq support --sitemap=column_3
```

The generated sitemap entries are added to the selected column in `config/b4um.yml`.

Sitemap links use Rails route helpers such as:

```yaml
links:
  - title: FAQ
    route: faq_path
```

Only valid Rails path helpers ending in `_path` are resolved by the b4um sitemap helper.

### Legal Links

Legal pages use the separate legal footer area by default:

```yaml
legal_links:
  placement: footer
```

They can alternatively be placed in an existing sitemap column:

```yaml
legal_links:
  placement: column_4
```

When legal pages are placed in a sitemap column, they are not duplicated in the separate legal footer area.

## Cookie Consent

Cookie consent can optionally be installed during the b4um setup:

```text
Add cookie consent? (y/n)
```

When enabled, b4um installs the cookie consent partial and its Stimulus controller.

The generated files are:

```text
app/views/shared/_cookie_consent.html.erb
app/javascript/controllers/cookie_consent_controller.js
```

The visitor's consent choice is stored in the browser's local storage.

If both the footer and cookie consent are installed, b4um adds a `Cookie-Einstellungen` control to the footer. This
allows visitors to reopen the cookie consent banner and change their choice later.

Cookie consent can also be installed without installing the footer.

## Development

After checking out the repository, install the dependencies:

```bash
bin/setup
```

Run the complete test suite with:

```bash
bundle exec rspec
```

Run RuboCop with:

```bash
bundle exec rubocop
```

The gem can be tested locally by referencing the repository with `path:` from a Rails application's `Gemfile`.

## Version

Current version: `0.1.0`

## Author

Alexander Baum

b4um

https://www.b4um.com

## License

b4um Generators is available under the terms of the MIT License.
