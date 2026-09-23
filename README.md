# B4UM Generators

B4UM Generators is a collection of reusable Rails generators, templates and application defaults for B4UM Rails
projects.

The gem provides generators for common application components such as layouts, controllers, scaffolds, tables,
pagination, search, comments and rich-text editing.

## Requirements

- Ruby >= 3.1
- Rails >= 8.0 and < 9.0

## Installation

B4UM Generators is currently used as a local gem during development.

Add the gem to the Rails application's `Gemfile`:

```ruby
gem "b4um_generators", "~> 0.1.0", path: "/path/to/b4um_generators"
```

Then run:

```bash
bundle install
```

## Getting Started

Install the B4UM application defaults:

```bash
bin/rails generate b4um:install
```

The installer adds the shared B4UM application structure and configuration to the Rails application.

The central B4UM configuration is stored in:

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

## Sitemap and Footer

The B4UM footer supports configurable sitemap columns through `config/b4um.yml`.

Example:

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
```

Controller actions can be assigned directly to a sitemap column:

```bash
bin/rails generate b4um:controller Pages faq support --sitemap=column_3
```

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

B4UM

https://www.b4um.com

## License

B4UM Generators is available under the terms of the MIT License.
