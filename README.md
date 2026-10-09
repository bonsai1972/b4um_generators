English | [Deutsch](README.de.md)

# b4um Generators

b4um Generators is a collection of reusable Rails generators, templates, components and application defaults for b4um
Rails projects.

The gem provides a consistent starting point for Rails applications and includes generators for scaffolds, controllers,
Bento layouts, tables, pagination, infinite scrolling, search, comments, authentication, attachments and rich-text
editing.

Generated components share the same b4um styling and are designed to work together.

## Requirements

- Ruby >= 3.1
- Rails >= 8.0 and < 9.0

## Installation

b4um Generators is currently used as a local gem during development.

Add the gem to the Rails application's `Gemfile`:

```ruby
gem "b4um_generators", "~> 0.2.0", path: "/path/to/b4um_generators"
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
- Select fields with custom labels
- Radio fields with custom labels
- Automatic navigation entry
- Active navigation state
- Form validation errors
- Flash messages
- Password field support
- Optional readable URL parameters

### Select and Radio Fields

The scaffold generator can render string attributes as select or radio fields with custom display labels.

For a select field, use:

```text
--select='FIELD:VALUE=LABEL,VALUE=LABEL'
```

Example:

```bash
bin/rails generate b4um:scaffold Product name:string status:string --select='status:Active=Aktiv,Inactive=Inaktiv'
```

For radio buttons, use:

```text
--radio='FIELD:VALUE=LABEL,VALUE=LABEL'
```

Example:

```bash
bin/rails generate b4um:scaffold Product name:string condition:string --radio='condition:new=Neu,used=Gebraucht,refurbished=Generalüberholt'
```

Both options can be combined for different fields:

```bash
bin/rails generate b4um:scaffold Product name:string status:string condition:string --select='status:Active=Aktiv,Inactive=Inaktiv' --radio='condition:new=Neu,used=Gebraucht'
```

The configured values are stored in the database, while the labels are displayed in forms, resource views and table
layouts.

A field cannot use both `--select` and `--radio`.

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

Readable URLs can also be added later to an existing model:

```bash
bin/rails generate b4um:readable Product name
```

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
bin/rails generate b4um:table MODEL [FIELDS]
```

The model must already exist.

Fields are optional. If no fields are supplied, the generator automatically detects the model's database fields, Action
Text fields and Active Storage attachments. `id`, `created_at` and `updated_at` are excluded automatically.

Recommended:

```bash
bin/rails generate b4um:table Product
```

Fields can also be specified explicitly:

```bash
bin/rails generate b4um:table Product name price status
```

Configured select and radio values can be displayed using their labels:

```bash
bin/rails generate b4um:table Product \
  --select="status:active=Active,inactive=Inactive" \
  --radio="condition:new=New,used=Used"
```

For a `Product` model, the generated partial is stored at:

```text
app/views/products/_table.html.erb
```

The generated table provides:

- Automatic field detection from the existing model
- Responsive table layout
- Model-aware field types
- Text fields shortened to 100 characters
- Decimal values formatted with two decimal places
- Status fields displayed as b4um badges
- Labels for configured `--select` and `--radio` values
- Action Text / Trix content
- Lightbox support for images embedded in rich text
- Trix image captions in the Lightbox
- Active Storage `has_one_attached` images
- Active Storage `has_many_attached` galleries
- Thumbnails, Lightbox navigation and drag/swipe support
- Actions column with a Show button
- Empty-state handling

Running the Table generator automatically switches an existing b4um index view to the table partial:

```erb
<%= render "table", products: @products %>
```

Running `b4um:bento Product` later switches the index back to the Bento partial. This also applies to the `grid`, `list`
and `alternating` Bento layouts.

The table partial can also be reused with another collection:

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

## Authentication

Add session-based authentication for an existing model:

```bash
bin/rails generate b4um:authentication MODEL
```

Example:

```bash
bin/rails generate b4um:authentication User
```

The authentication model can have any name, for example:

```text
User
Admin
Member
```

The selected model must:

- Already exist
- Use `has_secure_password`
- Have a `password_digest` column
- Use bcrypt

Authentication uses an `email` attribute for login.

A complete example:

```bash
bin/rails generate b4um:scaffold User name:string email:string password_digest:string
bin/rails generate b4um:authentication User
```

The authentication generator adds:

- Sessions controller
- Login form
- Login and logout routes
- Session-based current account helper
- `logged_in?` helper
- `require_login` helper
- Login and logout navigation controls

The generated helper name follows the selected model.

For `User`:

```ruby
current_user
```

For `Admin`:

```ruby
current_admin
```

### Protecting Controllers

Existing controllers can optionally be protected when authentication is installed.

Use `--protect` with the controller name:

```bash
bin/rails generate b4um:authentication User --protect=Products
```

The generator adds the following authentication requirement to the selected controller:

```ruby
before_action :require_login, except: [:index, :show]
```

This keeps `index` and `show` publicly accessible while requiring authentication for actions such as `new`, `create`,
`edit`, `update` and `destroy`.

Multiple controllers can be protected at the same time by separating their names with commas:

```bash
bin/rails generate b4um:authentication User --protect=Products,Articles
```

Additional controllers can also be protected later by running the authentication generator again:

```bash
bin/rails generate b4um:authentication User --protect=Comments
```

Existing authentication setup is reused. Authentication helpers, routes, navigation controls and controller protection
are not duplicated.

The generator validates protected controllers before changing the application. If a requested controller does not exist,
the generator stops with an error before making changes.

The generator also validates its authentication requirements before changing the application. If required authentication
setup is missing, the generator stops with a helpful error message and a suggested b4um scaffold command.

Repeated generator runs do not duplicate authentication helpers, routes, navigation controls or controller protection.

## Active Storage and Images

Image attachments use Rails Active Storage.

Active Storage can be selected during:

```bash
bin/rails generate b4um:install
```

If Active Storage is not already installed, b4um installs it and runs the required migration.

### Single Image in a New Scaffold

Use:

```text
image:attachment
```

Example:

```bash
bin/rails generate b4um:scaffold Article title:string image:attachment
```

### Multiple Images in a New Scaffold

Use:

```text
images:attachments
```

Example:

```bash
bin/rails generate b4um:scaffold Gallery title:string images:attachments
```

### Attachment Generator

Attachments can also be added later to an existing b4um resource.

For a single attachment:

```bash
bin/rails generate b4um:attachment MODEL ATTACHMENT
```

Example:

```bash
bin/rails generate b4um:attachment Admin avatar
```

This adds:

```ruby
has_one_attached :avatar
```

For multiple attachments, use `--multiple`:

```bash
bin/rails generate b4um:attachment MODEL ATTACHMENT --multiple
```

Example:

```bash
bin/rails generate b4um:attachment Product images --multiple
```

This adds:

```ruby
has_many_attached :images
```

When the corresponding b4um files exist, the attachment generator also updates:

- The existing model
- The existing b4um form
- The controller parameters
- The existing b4um resource partial

Multiple attachments additionally support:

- Adding new images without replacing existing images
- Removing individual existing images
- Multiple image preview
- Image gallery with lightbox navigation

Repeated generator runs do not duplicate existing attachment setup.

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

## In-place Editing

Add in-place editing to fields of an existing b4um resource:

```bash
bin/rails generate b4um:in_place MODEL FIELD [FIELD ...]
```

Example for a single field:

```bash
bin/rails generate b4um:in_place Product name
```

Multiple fields can be added in one run:

```bash
bin/rails generate b4um:in_place Product name price status
```

The model, controller and resource routes must already exist.

The generator detects the existing field types and creates the appropriate editors.

Supported fields include:

- String and text fields
- Numeric and decimal fields
- Boolean fields
- Action Text rich-text fields
- Active Storage single image attachments
- Active Storage multiple image attachments

### Select Fields

A field can be rendered as a select list with `--select`:

```bash
bin/rails generate b4um:in_place Product status --select='status:Active=Aktiv,Inactive=Inaktiv'
```

The value before `=` is stored in the database. The optional value after `=` is used as the displayed label.

For example, `Active=Aktiv` stores `Active` while displaying `Aktiv`.

### Radio Fields

A field can be rendered as radio buttons with `--radio`:

```bash
bin/rails generate b4um:in_place Product condition --radio='condition:new=Neu,used=Gebraucht,refurbished=Generalüberholt'
```

The same value and label syntax used by `--select` applies to radio fields.

### In-place Editing Behavior

Generated in-place editing provides:

- Turbo Frame based editing without an additional in-place editing gem
- Editing directly inside the existing resource layout
- Outside-click saving for text and rich-text fields
- Immediate saving for select, radio and boolean fields
- Single and multiple image attachment editing
- Removal of existing image attachments
- Inline validation errors
- Immediate flash-message updates after successful changes
- Multiple fields in one generator run
- Additional fields in later generator runs
- Safe repeated generator runs

### Authentication

In-place editing integrates automatically with b4um authentication.

Without authentication, generated in-place fields are editable.

When b4um authentication is installed, in-place editing is restricted to logged-in users and the corresponding
controller actions are protected with `require_login`.

Authentication can be installed either before or after in-place editing. The generators update the integration
automatically in both installation orders.

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

Current version: `0.2.17`

## Author

Alexander Baum

b4um

https://www.b4um.com

## License

b4um Generators is available under the terms of the MIT License.
