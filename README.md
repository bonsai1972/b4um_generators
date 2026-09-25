English | [Deutsch](README.de.md)

# b4um Generators

b4um Generators is a collection of reusable Rails generators, templates, components and application defaults for b4um
Rails projects.

The gem provides a consistent starting point for Rails applications and includes generators for scaffolds, controllers,
Bento layouts, tables, pagination, infinite scrolling, search, comments and rich-text editing.

Generated components share the same b4um styling and are designed to work together.

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

The installer adds the shared b4um application structure, stylesheets, JavaScript controllers, helpers and configuration
to the Rails application.

During installation, optional features can be selected interactively:

- bcrypt for password support
- Active Storage for image attachments
- Hero section
- Footer
- Footer sitemap
- Cookie consent

The sitemap is available when the footer is installed.

If an optional gem is selected and is not already available, b4um adds it to the `Gemfile` and runs `bundle install`.

If Active Storage is selected and has not already been installed, b4um installs Active Storage and runs the required
database migration.

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

For a detailed command reference and additional examples, run:

```bash
bin/rails generate b4um:help
```

## Scaffold Generator

Generate a Rails resource using the b4um views and components:

```bash
bin/rails generate b4um:scaffold MODEL ATTRIBUTES
```

Example:

```bash
bin/rails generate b4um:scaffold Product name:string description:text price:decimal status:string
```

The scaffold generator provides:

- b4um forms
- Index, show, new and edit views
- Bento index layout by default
- Optional table index layout
- Automatic navigation entry
- Active navigation state
- Form validation errors
- Flash messages
- Password field support
- Optional readable URL parameters

### Bento Index

The default scaffold index uses the responsive b4um Bento card layout.

### Table Index

To generate a table-based index instead, use:

```bash
bin/rails generate b4um:scaffold Product name:string description:text price:decimal status:string --layout=table
```

Table layouts automatically provide:

- Responsive b4um table styling
- Text fields shortened to 100 characters
- Status fields displayed as b4um badges
- Actions column
- Empty-state handling

### Readable URL Parameters

A scaffold can generate readable URLs while keeping the database ID in the URL.

Use:

```text
--param=ATTRIBUTE
```

Example:

```bash
bin/rails generate b4um:scaffold Article title:string body:text --param=title
```

This creates URLs such as:

```text
/articles/17-my-first-article
```

The ID remains part of the URL, so the standard Rails resource lookup continues to work.

The readable part is generated from the selected attribute and changes automatically when that attribute changes.

## Bento and Cards

b4um includes a responsive card system that can be used independently of the generators.

Basic example:

```html
<div class="b4um-grid">
  <article class="b4um-card">...</article>
</div>
```

Available card variants include:

```text
b4um-card
b4um-card--wide
b4um-card--large
b4um-card--full
b4um-card--soft
```

Common card content classes include:

```text
b4um-card__eyebrow
b4um-card__title
b4um-card__text
b4um-card__actions
b4um-card__media
b4um-card__image
```

The card grid automatically adapts to tablet and mobile layouts.

### Bento Generator

Generate a reusable layout for an existing model:

```bash
bin/rails generate b4um:bento Product
```

The default layout is `grid`.

Available layouts are:

```bash
bin/rails generate b4um:bento Product --layout=grid
bin/rails generate b4um:bento Product --layout=list
bin/rails generate b4um:bento Product --layout=alternating
bin/rails generate b4um:bento Product --layout=bento
```

The layouts provide:

- `grid` — responsive three-column card grid
- `list` — compact horizontal list
- `alternating` — spacious alternating content layout
- `bento` — classic Bento layout with mixed card sizes

The model and its resource partial must already exist.

For a `Product` model, the generated partial is stored at:

```text
app/views/products/_bento.html.erb
```

Render it with:

```erb
<%= render "bento", products: @products %>
```

The partial uses a local collection and can therefore also be reused with another collection:

```erb
<%= render "products/bento", products: @featured_products %>
```

## Table Generator

Generate a reusable b4um table for an existing model:

```bash
bin/rails generate b4um:table MODEL FIELDS
```

Example:

```bash
bin/rails generate b4um:table Product name:string description:text price:decimal status:string
```

The model must already exist.

For a `Product` model, the generated partial is stored at:

```text
app/views/products/_table.html.erb
```

The generated table provides:

- Responsive table layout
- Typed field definitions
- Text fields shortened to 100 characters
- Status fields displayed as b4um badges
- Actions column with a Show button
- Empty-state handling

Render it with:

```erb
<%= render "table", products: @products %>
```

The partial can also be reused with another collection:

```erb
<%= render "products/table", products: @featured_products %>
```

## Controller Generator

Generate a controller and its actions using:

```bash
bin/rails generate b4um:controller NAME ACTIONS
```

Example:

```bash
bin/rails generate b4um:controller Pages home about impressum agb
```

The controller generator:

- Uses the standard Rails controller generator
- Creates the requested actions and views
- Adds regular action links to the b4um navigation
- Adds supported legal pages to the b4um footer
- Keeps legal pages out of the main navigation

Recognized German legal pages include:

```text
impressum
datenschutz
agb
```

Recognized English legal pages include:

```text
imprint
privacy
privacy_policy
terms
terms_and_conditions
```

Footer links require the b4um footer to be installed.

Controller actions can also be assigned directly to a sitemap column:

```bash
bin/rails generate b4um:controller Pages faq support --sitemap=column_3
```

## Password Support

For password authentication, define a `password_digest` attribute:

```bash
bin/rails generate b4um:scaffold User name:string email:string password_digest:string
```

The scaffold generator automatically creates password fields instead of exposing `password_digest` directly.

Password support requires bcrypt.

bcrypt can be selected during:

```bash
bin/rails generate b4um:install
```

If necessary, b4um adds bcrypt to the application's `Gemfile` and installs it.

## Active Storage and Images

Image attachments use Rails Active Storage.

Active Storage can be selected during:

```bash
bin/rails generate b4um:install
```

If Active Storage is not already installed, b4um installs it and runs the required migration.

### Single Image

Use:

```text
image:attachment
```

Example:

```bash
bin/rails generate b4um:scaffold Article title:string image:attachment
```

### Multiple Images

Use:

```text
images:attachments
```

Example:

```bash
bin/rails generate b4um:scaffold Gallery title:string images:attachments
```

Image support includes:

- Active Storage integration
- Image preview before saving
- Existing image preview while editing
- Adding new images without removing existing images
- Removing individual existing images
- Image lightbox
- Previous and next navigation
- Mouse and touch swipe
- Keyboard navigation

## Pagination

Add server-side pagination to an existing resource:

```bash
bin/rails generate b4um:pagination Product
```

By default, 20 records are displayed per page.

Use a custom page size with:

```bash
bin/rails generate b4um:pagination Product --per-page=50
```

The model, controller and index view must already exist.

Pagination provides:

- Server-side pagination using Active Record `limit` and `offset`
- No additional pagination gem
- Previous and Next navigation
- Numbered page navigation
- Preservation of existing query parameters
- Integration with Bento and Table layouts
- Safe handling of invalid or excessive page numbers

## Infinite Scroll

Add automatic infinite scrolling to an existing resource:

```bash
bin/rails generate b4um:infinite_scroll Product
```

By default, 20 records are loaded per page.

A custom page size can be specified with:

```bash
bin/rails generate b4um:infinite_scroll Product --per-page=50
```

The model, controller and index view must already exist.

Infinite Scroll provides:

- Automatic loading while scrolling
- Server-side pagination using Active Record `limit` and `offset`
- No additional pagination gem
- Integration with Bento and Table layouts
- Preservation of existing query parameters
- Automatic stopping after the final page
- Replacement of existing b4um pagination navigation
- Safe repeated generator runs

## Search

Add database-backed search to an existing resource:

```bash
bin/rails generate b4um:search Product
```

The model, controller and index view must already exist.

Search provides:

- Search across string and text columns
- Case-insensitive partial matching
- Safe escaping of search terms
- Complete collection for blank searches
- Integration with Bento and Table layouts
- Integration with Pagination and Infinite Scroll
- Preservation of the search query while navigating pages
- No additional search gem
- Safe repeated generator runs

## Comments

Add polymorphic comments to an existing model:

```bash
bin/rails generate b4um:comments Article
```

The comments generator provides:

- Polymorphic `Comment` model
- Comment association on the selected model
- Nested create and destroy routes
- Comments controller
- Comment list and form
- Delete confirmation
- b4um form and card styling
- Support for multiple commentable models
- Safe repeated generator runs

Additional models can use the same comments system:

```bash
bin/rails generate b4um:comments Product
```

Existing b4um comments controllers are extended automatically.

Unknown custom comments controllers are left unchanged and cause the generator to stop instead of overwriting custom
code.

## Trix and Rich Text

Add Rails Action Text with Trix to an existing b4um resource:

```bash
bin/rails generate b4um:trix MODEL ATTRIBUTE
```

Example:

```bash
bin/rails generate b4um:trix Article content
```

The model and form must already exist.

The generator adds:

```ruby
has_rich_text :content
```

and replaces the selected form field with a rich-text editor:

```ruby
form.rich_text_area :content
```

The b4um Trix integration provides:

- Automatic Action Text installation when required
- Rich-text model association
- Replacement of only the selected form field
- Compact plain-text previews in Bento cards
- Image lightbox
- Previous and next image navigation
- Mouse and touch swipe
- Keyboard navigation
- Responsive image galleries
- Sticky Trix toolbar
- Headings H1 through H6
- Left, center and right text alignment
- Text and background colors
- Horizontal rules
- Editable `DIV`, `SECTION` and `ARTICLE` containers with IDs
- Editable container formatting
- Removal of active container wrappers
- Safe repeated generator runs

## Hero Section

The installer can optionally create a hero section.

Select it when running:

```bash
bin/rails generate b4um:install
```

The generated partial is stored at:

```text
app/views/shared/_hero.html.erb
```

The hero works without an image by default and contains examples for:

- Hero title and text
- Optional action link
- Optional hero image

Hero CSS classes use the `b4um-hero` prefix.

## Footer and Sitemap

The b4um footer is optional and can be installed during the interactive setup:

```text
Add a footer? (y/n)
```

The generated footer is stored at:

```text
app/views/shared/_footer.html.erb
```

It provides:

- Automatic current year
- Application name placeholder
- Automatic legal page links generated by `b4um:controller`
- Optional sitemap
- Optional cookie settings control

If the footer is installed, b4um can optionally add a sitemap:

```text
Add a sitemap to the footer? (y/n)
```

The sitemap is installed as a separate partial and rendered inside the footer only when selected.

The generated sitemap partial is stored at:

```text
app/views/shared/_sitemap.html.erb
```

Its Stimulus controller is stored at:

```text
app/javascript/controllers/sitemap_controller.js
```

### Sitemap Columns

When the sitemap is enabled, the number of sitemap columns can be selected during installation:

```text
Number of sitemap columns [4]:
```

The sitemap supports between 2 and 5 columns.

Press Enter to use the default of 4 columns.

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

The titles can be changed later by editing `config/b4um.yml`.

The keys `column_1` through `column_5` identify sitemap columns independently of their visible titles.

Only keys for columns that exist in the current configuration should be used.

On larger screens, the configured sitemap columns are distributed automatically across the footer. On smaller screens,
the sitemap uses its responsive collapsible layout.

### Adding Pages to the Sitemap

Controller actions can be assigned directly to a sitemap column:

```bash
bin/rails generate b4um:controller Pages faq support --sitemap=column_3
```

When `--sitemap` is used, the generated actions are added to the selected sitemap column instead of the main navigation.

The entries are stored in `config/b4um.yml`.

Sitemap links use Rails route helpers:

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

When legal pages are assigned to a sitemap column, b4um adds them to that column automatically and does not duplicate
them in the separate legal footer area.

The placement uses the sitemap column key rather than its visible title, allowing column titles to be changed freely.

## Cookie Consent

Cookie consent can optionally be installed during the b4um setup:

```text
Add cookie consent? (y/n)
```

Cookie consent can be installed independently of the footer.

When enabled, b4um creates:

```text
app/views/shared/_cookie_consent.html.erb
app/javascript/controllers/cookie_consent_controller.js
```

The visitor's consent choice is stored in the browser's local storage.

If both the footer and cookie consent are installed, b4um automatically adds a `Cookie-Einstellungen` control to the
footer.

This allows visitors to reopen the cookie consent banner and change their choice later.

When cookie consent is installed without a footer, the banner still works, but no cookie settings control is added to
the footer.

## Help

For the complete built-in overview of generators, options and features, run:

```bash
bin/rails generate b4um:help
```

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

Check patches for whitespace errors with:

```bash
git diff --check
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
