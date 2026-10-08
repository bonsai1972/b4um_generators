# frozen_string_literal: true

require "spec_helper"
require "yaml"
require "tmpdir"
require "fileutils"
require "generators/b4um/install/install_generator"

RSpec.describe B4um::Generators::InstallGenerator do
  around do |example|
    Dir.mktmpdir("b4um_install_test") do |directory|
      @destination_root = directory
      example.run
    end
  end

  def create_application_layout
    layout_directory = File.join(
      @destination_root,
      "app/views/layouts"
    )

    FileUtils.mkdir_p(layout_directory)

    File.write(
      File.join(layout_directory, "application.html.erb"),
      <<~ERB
        <!DOCTYPE html>
        <html>
          <head>
            <title>Test</title>
          </head>
          <body>
            <%= yield %>
          </body>
        </html>
      ERB
    )
  end

  def create_gemfile
    File.write(
      File.join(@destination_root, "Gemfile"),
      "source \"https://rubygems.org\"\n"
    )
  end

  def create_routes
    config_directory = File.join(
      @destination_root,
      "config"
    )

    FileUtils.mkdir_p(config_directory)

    File.write(
      File.join(config_directory, "routes.rb"),
      <<~RUBY
        Rails.application.routes.draw do
        end
      RUBY
    )
  end

  def build_generator(
    *answers,
    home_controller: nil,
    home_action: nil,
    sitemap_column_count: nil,
    sitemap_titles: nil
  )
    generator = described_class.new(
      [],
      {},
      destination_root: @destination_root
    )

    allow(generator).to receive(:yes?).and_return(*answers)

    ask_answers = []

    if home_controller || home_action
      ask_answers << (home_controller || "")
      ask_answers << (home_action || "")
    end

    ask_answers << if sitemap_column_count
                     sitemap_column_count.to_s
                   else
                     ""
                   end

    ask_answers.concat(
      sitemap_titles || ["", "", "", ""]
    )

    allow(generator).to receive(:ask).and_return(
      *ask_answers
    )

    generator
  end

  it "loads the B4UM install generator" do
    expect(described_class).to be < Rails::Generators::Base
  end

  it "can create a home page with a root route" do
    create_application_layout
    create_gemfile
    create_routes

    generator = build_generator(
      false, # bcrypt
      false, # Active Storage
      true,  # home page
      false, # hero
      false, # footer
      false, # cookie consent
      home_controller: "Pages",
      home_action: "home"
    )

    generator.invoke_all

    controller_path = File.join(
      @destination_root,
      "app/controllers/pages_controller.rb"
    )

    view_path = File.join(
      @destination_root,
      "app/views/pages/home.html.erb"
    )

    routes_path = File.join(
      @destination_root,
      "config/routes.rb"
    )

    navigation_path = File.join(
      @destination_root,
      "app/views/shared/_navigation.html.erb"
    )

    expect(File).to exist(controller_path)
    expect(File).to exist(view_path)

    controller = File.read(controller_path)
    view = File.read(view_path)
    routes = File.read(routes_path)
    navigation = File.read(navigation_path)

    expect(controller).to include(
      "class PagesController < ApplicationController"
    )

    expect(controller).to include(
      "def home"
    )

    expect(view).to include(
      "<h1>Home</h1>"
    )

    expect(routes).to include(
      'root "pages#home"'
    )

    expect(navigation).to include(
      "root_path"
    )

    expect(navigation).to include(
      "controller: :pages"
    )

    expect(navigation).to include(
      "action: :home"
    )

    expect(navigation).to include(
      %(      <%= navigation_link_to "Home",)
    )

    expect(navigation).to include(
      %(                             root_path,)
    )

    expect(navigation).to include(
      %(                             controller: :pages,)
    )

    expect(navigation).to include(
      %(                             action: :home %>)
    )

    expect(navigation).to include(
      %(      <%# B4UM_NAVIGATION_LINKS %>)
    )
  end

  it "can skip creating a home page" do
    create_application_layout
    create_gemfile
    create_routes

    generator = build_generator(
      false, # bcrypt
      false, # Active Storage
      false, # home page
      false, # hero
      false, # footer
      false  # cookie consent
    )

    generator.invoke_all

    expect(
      File.exist?(
        File.join(
          @destination_root,
          "app/controllers/pages_controller.rb"
        )
      )
    ).to be(false)

    expect(
      File.exist?(
        File.join(
          @destination_root,
          "app/views/pages/home.html.erb"
        )
      )
    ).to be(false)

    routes = File.read(
      File.join(@destination_root, "config/routes.rb")
    )

    expect(routes).not_to match(/^\s*root\b/)
  end

  it "keeps an existing root route when creating a home page" do
    create_application_layout
    create_gemfile
    create_routes

    routes_path = File.join(
      @destination_root,
      "config/routes.rb"
    )

    File.write(
      routes_path,
      <<~RUBY
        Rails.application.routes.draw do
          root "dashboard#index"
        end
      RUBY
    )

    generator = build_generator(
      false, # bcrypt
      false, # Active Storage
      true,  # home page
      false, # hero
      false, # footer
      false, # cookie consent
      home_controller: "Pages",
      home_action: "home"
    )

    generator.invoke_all

    routes = File.read(routes_path)

    navigation = File.read(
      File.join(
        @destination_root,
        "app/views/shared/_navigation.html.erb"
      )
    )

    expect(routes).to include(
      'root "dashboard#index"'
    )

    expect(routes).not_to include(
      'root "pages#home"'
    )

    expect(
      routes.scan(/^\s*root\b/).count
    ).to eq(1)

    expect(navigation).not_to include(
      "root_path"
    )

    expect(navigation).not_to include(
      "controller: :pages"
    )

    expect(navigation).not_to include(
      "action: :home"
    )
  end

  it "activates bcrypt when Rails provides it as a commented Gemfile entry" do
    create_application_layout

    File.write(
      File.join(@destination_root, "Gemfile"),
      <<~RUBY
        source "https://rubygems.org"

        # Use Active Model has_secure_password
        # gem "bcrypt", "~> 3.1.7"
      RUBY
    )

    generator = build_generator(
      true,  # bcrypt
      false, # Active Storage
      false, # home page
      false, # hero
      false, # footer
      false  # cookie consent
    )

    generator.invoke_all

    gemfile = File.read(
      File.join(@destination_root, "Gemfile")
    )

    expect(gemfile).to include(
      'gem "bcrypt", "~> 3.1.7"'
    )

    expect(gemfile).not_to include(
      '# gem "bcrypt", "~> 3.1.7"'
    )
  end

  it "installs the B4UM base setup with hero and footer" do
    create_application_layout
    create_gemfile

    generator = build_generator(
      false, # bcrypt
      false, # Active Storage
      false, # home page
      true,  # hero
      true,  # footer
      true,  # sitemap
      false  # cookie consent
    )

    generator.invoke_all

    stylesheet_path = File.join(
      @destination_root,
      "app/assets/stylesheets/b4um.css"
    )

    expect(File).to exist(stylesheet_path)

    stylesheet = File.read(stylesheet_path)

    expected_imports = %w[
      theme.css
      base.css
      layout.css
      navigation.css
      forms.css
      search.css
      resources.css
      lightbox.css
      hero.css
      cards.css
      tables.css
      pagination.css
      badges.css
      callouts.css
      empty-state.css
      flash.css
      comments.css
      footer.css
      cookie-consent.css
      theme-switcher.css
    ]

    expected_imports.each do |stylesheet_name|
      expect(stylesheet).to include(
        %(@import 'b4um/#{stylesheet_name}';)
      )
    end

    component_directory = File.join(
      @destination_root,
      "app/assets/stylesheets/b4um"
    )

    expected_components = %w[
      theme.css
      base.css
      layout.css
      navigation.css
      forms.css
      search.css
      resources.css
      lightbox.css
      hero.css
      cards.css
      tables.css
      pagination.css
      badges.css
      callouts.css
      empty-state.css
      flash.css
      comments.css
      footer.css
      cookie-consent.css
      theme-switcher.css
    ]

    expected_components.each do |stylesheet_name|
      expect(File).to exist(
        File.join(component_directory, stylesheet_name)
      )
    end

    lightbox_path = File.join(
      @destination_root,
      "app/assets/stylesheets/b4um/lightbox.css"
    )

    expect(File).to exist(lightbox_path)

    lightbox = File.read(
      lightbox_path
    )

    expect(lightbox).to include(
      ".lupe"
    )

    expect(lightbox).to include(
      ".resource-image__button"
    )

    expect(lightbox).to include(
      ".resource-images__button"
    )

    expect(lightbox).to include(
      ".image-lightbox__stage"
    )

    expect(lightbox).to include(
      "touch-action: pan-y"
    )

    expect(lightbox).to include(
      "cursor: grab"
    )

    expect(lightbox).to include(
      ".image-lightbox__image--dragging"
    )

    expect(lightbox).to include(
      ".image-lightbox__image--sliding"
    )

    expect(lightbox).to include(
      ".image-lightbox__image--waiting-right"
    )

    expect(lightbox).to include(
      ".image-lightbox__image--waiting-left"
    )

    expect(lightbox).to include(
      ".image-lightbox__image--exit-left"
    )

    expect(lightbox).to include(
      ".image-lightbox__image--exit-right"
    )

    expect(lightbox).to include(
      ".image-lightbox__navigation--previous"
    )

    expect(lightbox).to include(
      ".image-lightbox__navigation--next"
    )

    expect(lightbox).to include(
      ".image-lightbox__thumbnails"
    )

    expect(lightbox).to include(
      ".image-lightbox__thumbnail.is-active"
    )

    expect(lightbox).to include(
      "@media (prefers-reduced-motion: reduce)"
    )

    expect(lightbox).to include(
      "@media (max-width: 768px)"
    )

    theme = File.read(
      File.join(component_directory, "theme.css")
    )

    cards = File.read(
      File.join(component_directory, "cards.css")
    )

    forms = File.read(
      File.join(component_directory, "forms.css")
    )

    resources = File.read(
      File.join(component_directory, "resources.css")
    )

    footer = File.read(
      File.join(component_directory, "footer.css")
    )

    tables = File.read(
      File.join(component_directory, "tables.css")
    )

    badges = File.read(
      File.join(component_directory, "badges.css")
    )

    empty_state = File.read(
      File.join(component_directory, "empty-state.css")
    )

    flash = File.read(
      File.join(component_directory, "flash.css")
    )

    callouts = File.read(
      File.join(component_directory, "callouts.css")
    )

    expect(callouts).to include(
      ".b4um-callout--info"
    )

    expect(callouts).to include(
      ".b4um-callout--success"
    )

    expect(callouts).to include(
      ".b4um-callout--warning"
    )

    expect(callouts).to include(
      ".b4um-callout--danger"
    )

    expect(callouts).to include(
      "border-radius: var(--b4um-radius);"
    )

    expect(theme).to include(
      "--b4um-radius: 20px;"
    )

    expect(theme).to include(
      "--b4um-warning: #854d0e;"
    )

    expect(theme).to include(
      "--b4um-warning-background: #fef9c3;"
    )

    expect(theme).to include(
      "--b4um-warning-border: #fde68a;"
    )

    expect(theme).to include(
      "--b4um-code-background: #1e293b;"
    )

    expect(theme).to include(
      "--b4um-code-text: #f8fafc;"
    )

    expect(theme).to include(
      "--b4um-code-border: #334155;"
    )

    expect(resources).to include(
      ".b4um-rich-text-preview"
    )

    expect(resources).to include(
      ".b4um-rich-text-preview__heading"
    )

    expect(resources).to include(
      ".b4um-rich-text-preview__text"
    )

    expect(footer).to include(
      ".b4um-footer__link.is-active"
    )

    expect(footer).to include(
      "font-weight: 700;"
    )

    expect(forms).to include(
      ".form-field--rich-text trix-editor pre"
    )

    expect(forms).to include(
      ".trix-content pre"
    )

    expect(forms).to include(
      "white-space: pre-wrap;"
    )

    expect(forms).to include(
      "overflow-wrap: anywhere;"
    )

    expect(forms).to include(
      "background-color: var(--b4um-code-background);"
    )

    expect(flash).to include(
      "background-color: var(--b4um-success-background);"
    )

    expect(flash).to include(
      "border-color: var(--b4um-success-border);"
    )

    expect(flash).to include(
      "background-color: var(--b4um-danger-background);"
    )

    expect(flash).to include(
      "border-color: var(--b4um-danger-soft-border);"
    )

    expect(badges).to include(
      "background-color: var(--b4um-success-background);"
    )

    expect(badges).to include(
      "background-color: var(--b4um-warning-background);"
    )

    expect(badges).to include(
      "background-color: var(--b4um-danger-background);"
    )

    expect(badges).to include(
      "background-color: var(--b4um-neutral-background);"
    )

    expect(cards).to include(
      "border-radius: var(--b4um-radius);"
    )

    expect(cards).to include(
      "border-radius: var(--b4um-radius) var(--b4um-radius) 0 0;"
    )

    expect(cards).to include(
      ".b4um-card-grid"
    )

    expect(cards).to include(
      "grid-template-columns: repeat(3, minmax(0, 1fr));"
    )

    expect(cards).to include(
      ".b4um-list"
    )

    expect(cards).to include(
      ".b4um-list__item"
    )

    expect(cards).to include(
      ".b4um-alternating"
    )

    expect(cards).to include(
      ".b4um-alternating__item--reverse"
    )

    expect(tables).to include(
      ".b4um-table-wrapper"
    )

    expect(tables).to include(
      "overflow-x: auto;"
    )

    expect(tables).to include(
      ".b4um-table"
    )

    expect(tables).to include(
      "min-width: 640px;"
    )

    expect(tables).to include(
      ".b4um-table__actions"
    )

    expect(tables).to include(
      "border-radius: var(--b4um-radius);"
    )

    expect(empty_state).to include(
      "border-radius: var(--b4um-radius);"
    )

    base = File.read(
      File.join(component_directory, "base.css")
    )

    expect(base).to include(
      "display: flex;"
    )

    expect(base).to include(
      "flex-direction: column;"
    )

    expect(base).to include(
      "min-height: 100vh;"
    )

    expect(base).to include(
      "flex: 1 0 auto;"
    )

    expect(base).to include(
      "flex-shrink: 0;"
    )

    flash = File.read(
      File.join(component_directory, "flash.css")
    )

    expect(flash).to include(".flash--notice")
    expect(flash).to include(".flash--deleted")
    expect(flash).to include(".flash--alert")

    navigation_path = File.join(
      @destination_root,
      "app/views/shared/_navigation.html.erb"
    )

    expect(File).to exist(navigation_path)

    navigation = File.read(navigation_path)

    expect(navigation).to include(
      '<%= link_to "b4um", "/", class: "navigation__brand" %>'
    )

    expect(navigation).to include(
      "<%# B4UM_NAVIGATION_LINKS %>"
    )

    expect(navigation).to include(
      'class="navigation"'
    )

    expect(navigation).to include(
      'class="navigation__toggle"'
    )

    expect(navigation).to include(
      'id="navigation-menu"'
    )

    expect(navigation).to include(
      'data-controller="navigation"'
    )

    expect(navigation).to include(
      'data-navigation-target="toggle"'
    )

    expect(navigation).to include(
      'data-navigation-target="menu"'
    )

    expect(navigation).to include(
      'data-action="click->navigation#toggle"'
    )

    navigation_controller_path = File.join(
      @destination_root,
      "app/javascript/controllers/navigation_controller.js"
    )

    expect(File).to exist(navigation_controller_path)

    navigation_controller = File.read(
      navigation_controller_path
    )

    expect(navigation_controller).to include(
      "this.element.classList.add('navigation--open')"
    )

    expect(navigation_controller).to include(
      "this.toggleTarget.setAttribute('aria-expanded', 'true')"
    )

    expect(navigation_controller).to include(
      "this.element.classList.remove('navigation--open')"
    )

    expect(navigation_controller).to include(
      "this.toggleTarget.setAttribute('aria-expanded', 'false')"
    )

    sitemap_controller_path = File.join(
      @destination_root,
      "app/javascript/controllers/sitemap_controller.js"
    )

    expect(File).to exist(sitemap_controller_path)

    sitemap_controller = File.read(
      sitemap_controller_path
    )

    expect(sitemap_controller).to include(
      "static targets = ['title']"
    )

    expect(sitemap_controller).to include(
      "title.setAttribute('aria-expanded', String(!isOpen))"
    )

    expect(sitemap_controller).to include(
      "item.classList.toggle('is-open', !isOpen)"
    )

    expect(sitemap_controller).to include(
      "if (window.matchMedia('(min-width: 78rem)').matches) return"
    )

    b4um_config_path = File.join(
      @destination_root,
      "config/b4um.yml"
    )

    expect(File).to exist(b4um_config_path)

    b4um_config = File.read(
      b4um_config_path
    )

    expect(b4um_config).to include(
      "key: column_1"
    )
    expect(b4um_config).to include(
      "title: Kontakt"
    )
    expect(b4um_config).to include(
      "key: column_2"
    )
    expect(b4um_config).to include(
      "key: column_3"
    )
    expect(b4um_config).to include(
      "key: column_4"
    )

    expect(b4um_config).to include(
      "legal_links:"
    )

    expect(b4um_config).to include(
      "placement: footer"
    )

    b4um_helper_path = File.join(
      @destination_root,
      "app/helpers/b4um_helper.rb"
    )

    expect(File).to exist(b4um_helper_path)

    b4um_helper = File.read(
      b4um_helper_path
    )

    expect(b4um_helper).to include(
      'require "yaml"'
    )

    expect(b4um_helper).to include(
      "def b4um_sitemap_columns"
    )

    expect(b4um_helper).to include(
      'Array(config["sitemap"])'
    )

    expect(b4um_helper).to include(
      "def b4um_sitemap_path(route)"
    )

    expect(b4um_helper).to include(
      "Rails.application.routes.url_helpers"
    )

    expect(
      File
    ).to exist(
      File.join(
        @destination_root,
        "app/javascript/controllers/image_preview_controller.js"
      )
    )

    expect(
      File
    ).to exist(
      File.join(
        @destination_root,
        "app/javascript/controllers/image_lightbox_controller.js"
      )
    )

    image_lightbox_controller_path = File.join(
      @destination_root,
      "app/javascript/controllers/image_lightbox_controller.js"
    )

    image_lightbox_controller = File.read(
      image_lightbox_controller_path
    )

    expect(image_lightbox_controller).to include(
      "'thumbnails'"
    )

    expect(image_lightbox_controller).to include(
      "buildThumbnails()"
    )

    expect(image_lightbox_controller).to include(
      "updateThumbnails(activeIndex = this.currentIndex)"
    )

    expect(image_lightbox_controller).to include(
      "thumbnail.classList.toggle('is-active', active)"
    )

    expect(image_lightbox_controller).to include(
      "thumbnail.setAttribute('aria-current', active ? 'true' : 'false')"
    )

    expect(image_lightbox_controller).to include(
      "scrollIntoView"
    )

    expect(image_lightbox_controller).to include(
      "pointerDown(event)"
    )

    expect(image_lightbox_controller).to include(
      "pointerMove(event)"
    )

    expect(image_lightbox_controller).to include(
      "pointerUp(event)"
    )

    expect(image_lightbox_controller).to include(
      "pointerCancel(event)"
    )

    expect(image_lightbox_controller).to include(
      "setPointerCapture(event.pointerId)"
    )

    expect(image_lightbox_controller).to include(
      "releasePointerCapture(event.pointerId)"
    )

    expect(image_lightbox_controller).to include(
      "createDragImage(index, direction)"
    )

    expect(image_lightbox_controller).to include(
      "slideTo(index, direction)"
    )

    expect(image_lightbox_controller).to include(
      "prefersReducedMotion()"
    )

    expect(image_lightbox_controller).to include(
      "'(prefers-reduced-motion: reduce)'"
    )

    expect(image_lightbox_controller).to include(
      "case 'ArrowLeft':"
    )

    expect(image_lightbox_controller).to include(
      "case 'ArrowRight':"
    )

    expect(image_lightbox_controller).to include(
      "case 'Escape':"
    )

    expect(image_lightbox_controller).to include(
      "this.counterTarget.textContent = `${this.currentIndex + 1} von ${this.itemTargets.length}`"
    )

    expect(image_lightbox_controller).to include(
      "this.previousButtonTarget.hidden = !hasMultipleImages"
    )

    expect(image_lightbox_controller).to include(
      "this.nextButtonTarget.hidden = !hasMultipleImages"
    )

    expect(image_lightbox_controller).to include(
      "prepareActionTextImages()"
    )

    expect(image_lightbox_controller).to include(
      "'keydown.enter->image-lightbox#open'"
    )

    expect(image_lightbox_controller).to include(
      "'keydown.space->image-lightbox#open'"
    )

    rich_text_controller_path = File.join(
      @destination_root,
      "app/javascript/controllers/rich_text_controller.js"
    )

    expect(File).to exist(rich_text_controller_path)

    rich_text_controller = File.read(
      rich_text_controller_path
    )

    expect(rich_text_controller).to include(
      "link.setAttribute('target', '_blank')"
    )

    expect(rich_text_controller).to include(
      "rel.add('noopener')"
    )

    expect(rich_text_controller).to include(
      "rel.add('noreferrer')"
    )

    expect(rich_text_controller).to include(
      "link.setAttribute('rel', Array.from(rel).join(' '))"
    )

    scroll_to_top_controller_path = File.join(
      @destination_root,
      "app/javascript/controllers/scroll_to_top_controller.js"
    )

    expect(File).to exist(scroll_to_top_controller_path)

    scroll_to_top_controller = File.read(
      scroll_to_top_controller_path
    )

    expect(scroll_to_top_controller).to include(
      "scrollTo"
    )

    expect(scroll_to_top_controller).to include(
      "behavior: 'smooth'"
    )

    expect(
      File
    ).to exist(
      File.join(
        @destination_root,
        "app/javascript/controllers/dismissible_controller.js"
      )
    )

    theme_controller_path = File.join(
      @destination_root,
      "app/javascript/controllers/theme_controller.js"
    )

    expect(File).to exist(theme_controller_path)

    theme_controller = File.read(
      theme_controller_path
    )

    expect(theme_controller).to include(
      "const STORAGE_KEY = 'b4um-theme'"
    )

    expect(theme_controller).to include(
      "const DARK_MEDIA_QUERY = '(prefers-color-scheme: dark)'"
    )

    expect(theme_controller).to include(
      "static targets = ['menu', 'toggle', 'icon', 'option']"
    )

    theme_switcher_path = File.join(
      @destination_root,
      "app/views/shared/_theme_switcher.html.erb"
    )

    expect(File).to exist(theme_switcher_path)

    theme_switcher = File.read(
      theme_switcher_path
    )

    expect(theme_switcher).to include(
      'class="b4um-theme-switcher"'
    )

    expect(theme_switcher).to include(
      'data-controller="theme"'
    )

    expect(theme_switcher).to include(
      'data-theme-value="system"'
    )

    expect(theme_switcher).to include(
      'data-theme-value="light"'
    )

    expect(theme_switcher).to include(
      'data-theme-value="dark"'
    )

    theme_switcher_css_path = File.join(
      @destination_root,
      "app/assets/stylesheets/b4um/theme-switcher.css"
    )

    expect(File).to exist(theme_switcher_css_path)

    navigation_helper_path = File.join(
      @destination_root,
      "app/helpers/navigation_helper.rb"
    )

    expect(File).to exist(navigation_helper_path)

    navigation_helper = File.read(
      navigation_helper_path
    )

    expect(navigation_helper).to include(
      "def navigation_link_to(name, path, controller: nil, action: nil)"
    )

    expect(navigation_helper).to include(
      "action_name == action.to_s"
    )

    expect(navigation_helper).to include(
      "controller_name == controller.to_s"
    )

    expect(navigation_helper).to include(
      "current_page?(path)"
    )

    expect(navigation_helper).to include(
      'data: { action: "click->navigation#close" }'
    )

    hero_path = File.join(
      @destination_root,
      "app/views/shared/_hero.html.erb"
    )

    footer_path = File.join(
      @destination_root,
      "app/views/shared/_footer.html.erb"
    )

    expect(File).to exist(hero_path)
    expect(File).to exist(footer_path)

    hero = File.read(hero_path)
    footer = File.read(footer_path)

    expect(hero).to include(
      "b4um-hero b4um-hero--text-only"
    )

    expect(hero).to include(
      'class="b4um-hero__title"'
    )

    expect(footer).to include(
      'href="#b4um-page-top"'
    )

    expect(footer).to include(
      'data-controller="scroll-to-top"'
    )

    expect(footer).to include(
      'data-action="click->scroll-to-top#scroll"'
    )

    expect(footer).to include(
      'class="b4um-footer"'
    )

    expect(footer).to include(
      "Time.current.year"
    )

    expect(footer).to include(
      "<%# B4UM_FOOTER_LINKS %>"
    )

    expect(footer).to include(
      '<%= render "shared/sitemap" %>'
    )

    sitemap_path = File.join(
      @destination_root,
      "app/views/shared/_sitemap.html.erb"
    )

    expect(File).to exist(sitemap_path)

    sitemap = File.read(sitemap_path)

    expect(sitemap).to include(
      'data-controller="sitemap"'
    )

    expect(sitemap).to include(
      "b4um_sitemap_columns"
    )

    expect(sitemap).to include(
      'column["title"]'
    )

    expect(footer).not_to include(
      'href="#"'
    )

    layout = File.read(
      File.join(
        @destination_root,
        "app/views/layouts/application.html.erb"
      )
    )

    expect(layout).to include(
      '<%= render "shared/navigation" %>'
    )

    expect(layout).to include(
      '<main class="container">'
    )

    expect(layout).to include(
      '<%= render "shared/hero" if respond_to?(:root_path) && request.path == root_path %>'
    )

    expect(layout).to include(
      '<%= render "shared/flash" %>'
    )

    expect(layout).not_to include(
      "flash.each"
    )

    flash_partial = File.read(
      File.join(
        @destination_root,
        "app/views/shared/_flash.html.erb"
      )
    )

    expect(flash_partial).to include(
      'id="flash-messages"'
    )

    expect(flash_partial).to include(
      "flash.each"
    )

    expect(flash_partial).to include(
      'data-controller="dismissible"'
    )

    expect(flash_partial).to include(
      'class="flash__close"'
    )

    expect(flash_partial).to include(
      'data-action="dismissible#dismiss"'
    )

    expect(layout).to include(
      "<%= yield %>"
    )

    expect(layout).to include(
      "</main>"
    )

    expect(layout).to include(
      '<%= render "shared/footer" %>'
    )

    expect(layout).to include(
      '<%= render "shared/theme_switcher" %>'
    )

    main_end = layout.index("</main>")
    footer_position = layout.index(
      '<%= render "shared/footer" %>'
    )

    expect(footer_position).to be > main_end
  end

  it "can configure between two and five sitemap columns" do
    {
      2 => %w[Kontakt Inhalte],
      3 => %w[Kontakt Inhalte Service],
      4 => %w[Kontakt Inhalte Service Mehr],
      5 => %w[Kontakt Inhalte Service Mehr Extras]
    }.each do |column_count, titles|
      FileUtils.rm_rf(@destination_root)
      FileUtils.mkdir_p(@destination_root)

      create_application_layout
      create_gemfile

      generator = build_generator(
        false, # bcrypt
        false, # Active Storage
        false, # home page
        false, # hero
        true,  # footer
        true,  # sitemap
        false, # cookie consent
        sitemap_column_count: column_count,
        sitemap_titles: titles
      )

      generator.invoke_all

      config_path = File.join(
        @destination_root,
        "config/b4um.yml"
      )

      config = YAML.safe_load_file(config_path)

      sitemap = config.fetch("sitemap")

      expect(sitemap.length).to eq(column_count)

      expect(
        sitemap.map { |column| column["key"] }
      ).to eq(
        (1..column_count).map { |number| "column_#{number}" }
      )

      expect(
        sitemap.map { |column| column["title"] }
      ).to eq(titles)
    end
  end

  it "can customize sitemap column titles" do
    create_application_layout
    create_gemfile

    generator = build_generator(
      false, # bcrypt
      false, # Active Storage
      false, # home page
      false, # hero
      true,  # footer
      true,  # sitemap
      false, # cookie consent
      sitemap_titles: %w[
        Unternehmen
        Produkte
        Hilfe
        Rechtliches
      ]
    )

    generator.invoke_all

    config_path = File.join(
      @destination_root,
      "config/b4um.yml"
    )

    config = File.read(config_path)

    expect(config).to include(
      "title: Unternehmen"
    )

    expect(config).to include(
      "title: Produkte"
    )

    expect(config).to include(
      "title: Hilfe"
    )

    expect(config).to include(
      "title: Rechtliches"
    )

    expect(config).not_to include(
      "title: Kontakt"
    )

    expect(config).not_to include(
      "title: Inhalte"
    )

    expect(config).not_to include(
      "title: Service"
    )

    expect(config).not_to include(
      "title: Mehr"
    )
  end

  it "can skip hero and footer independently" do
    create_application_layout
    create_gemfile

    generator = build_generator(
      false, # bcrypt
      false, # Active Storage
      false, # home page
      false, # hero
      true,  # footer
      false, # sitemap
      false  # cookie consent
    )

    generator.invoke_all

    hero_path = File.join(
      @destination_root,
      "app/views/shared/_hero.html.erb"
    )

    footer_path = File.join(
      @destination_root,
      "app/views/shared/_footer.html.erb"
    )

    expect(File).not_to exist(hero_path)
    expect(File).to exist(footer_path)

    layout = File.read(
      File.join(
        @destination_root,
        "app/views/layouts/application.html.erb"
      )
    )

    expect(layout).not_to include(
      '<%= render "shared/hero" if respond_to?(:root_path) && request.path == root_path %>'
    )

    expect(layout).to include(
      'render "shared/footer"'
    )
  end

  it "can install hero without footer" do
    create_application_layout
    create_gemfile

    generator = build_generator(
      false, # bcrypt
      false, # Active Storage
      false, # home page
      true,  # hero
      false, # footer
      false  # cookie consent
    )

    generator.invoke_all

    hero_path = File.join(
      @destination_root,
      "app/views/shared/_hero.html.erb"
    )

    footer_path = File.join(
      @destination_root,
      "app/views/shared/_footer.html.erb"
    )

    expect(File).to exist(hero_path)
    expect(File).not_to exist(footer_path)

    layout = File.read(
      File.join(
        @destination_root,
        "app/views/layouts/application.html.erb"
      )
    )

    expect(layout).to include(
      '<%= render "shared/hero" if respond_to?(:root_path) && request.path == root_path %>'
    )

    expect(layout).not_to include(
      'render "shared/footer"'
    )
  end

  it "does not duplicate the B4UM layout setup" do
    create_application_layout
    create_gemfile

    first_generator = build_generator(
      false, # bcrypt
      false, # Active Storage
      false, # home page
      true,  # hero
      true,  # footer
      false, # sitemap
      false  # cookie consent
    )

    first_generator.invoke_all

    footer_path = File.join(
      @destination_root,
      "app/views/shared/_footer.html.erb"
    )

    footer = File.read(footer_path)

    File.write(
      footer_path,
      footer.sub(
        "<%# B4UM_FOOTER_LINKS %>",
        <<~ERB.chomp
          <%= link_to "AGB", legaltest_agb_path, class: "b4um-footer__link" %>

          <%# B4UM_FOOTER_LINKS %>
        ERB
      )
    )

    second_generator = build_generator(
      false, # bcrypt
      false, # Active Storage
      false, # home page
      true,  # hero
      true,  # footer
      false, # sitemap
      false  # cookie consent
    )

    second_generator.invoke_all

    layout = File.read(
      File.join(
        @destination_root,
        "app/views/layouts/application.html.erb"
      )
    )

    expect(
      layout.scan('<%= render "shared/navigation" %>').count
    ).to eq(1)

    expect(
      layout.scan('<main class="container">').count
    ).to eq(1)

    expect(
      layout.scan('<%= render "shared/hero" if respond_to?(:root_path) && request.path == root_path %>').count
    ).to eq(1)

    expect(
      layout.scan('<%= render "shared/flash" %>').count
    ).to eq(1)

    expect(
      layout.scan("flash.each").count
    ).to eq(0)

    expect(
      layout.scan("</main>").count
    ).to eq(1)

    footer = File.read(footer_path)

    expect(footer).to include(
      '<%= link_to "AGB", legaltest_agb_path, class: "b4um-footer__link" %>'
    )

    expect(
      footer.scan("<%# B4UM_FOOTER_LINKS %>").count
    ).to eq(1)

    expect(
      layout.scan('<%= render "shared/footer" %>').count
    ).to eq(1)

    expect(
      layout.scan('<%= render "shared/theme_switcher" %>').count
    ).to eq(1)
  end

  it "can install cookie consent" do
    create_application_layout
    create_gemfile

    generator = build_generator(
      false, # bcrypt
      false, # Active Storage
      false, # home page
      false, # hero
      false, # footer
      true   # cookie consent
    )

    generator.invoke_all

    cookie_consent_path = File.join(
      @destination_root,
      "app/views/shared/_cookie_consent.html.erb"
    )

    cookie_controller_path = File.join(
      @destination_root,
      "app/javascript/controllers/cookie_consent_controller.js"
    )

    expect(File).to exist(cookie_consent_path)
    expect(File).to exist(cookie_controller_path)

    layout = File.read(
      File.join(
        @destination_root,
        "app/views/layouts/application.html.erb"
      )
    )

    expect(layout).to include(
      '<%= render "shared/cookie_consent" %>'
    )

    cookie_consent = File.read(cookie_consent_path)
    cookie_controller = File.read(cookie_controller_path)

    expect(cookie_consent).to include(
      'data-controller="cookie-consent"'
    )

    expect(cookie_consent).to include(
      'data-action="cookie-consent#reject"'
    )

    expect(cookie_consent).to include(
      'data-action="cookie-consent#accept"'
    )

    expect(cookie_controller).to include(
      "const STORAGE_KEY = 'b4um-cookie-consent'"
    )

    expect(cookie_controller).to include(
      "this.storeConsent('accepted')"
    )

    expect(cookie_controller).to include(
      "this.storeConsent('rejected')"
    )

    expect(cookie_controller).to include(
      "window.localStorage.setItem(STORAGE_KEY, consent)"
    )

    expect(cookie_controller).to include(
      "new CustomEvent('b4um:cookie-consent-accepted')"
    )

    expect(cookie_controller).to include(
      "new CustomEvent('b4um:cookie-consent-rejected')"
    )
  end

  it "can install cookie consent without footer" do
    create_application_layout
    create_gemfile

    generator = build_generator(
      false, # bcrypt
      false, # Active Storage
      false, # home page
      false, # hero
      false, # footer
      true   # cookie consent
    )

    generator.invoke_all

    footer_path = File.join(
      @destination_root,
      "app/views/shared/_footer.html.erb"
    )

    cookie_consent_path = File.join(
      @destination_root,
      "app/views/shared/_cookie_consent.html.erb"
    )

    cookie_controller_path = File.join(
      @destination_root,
      "app/javascript/controllers/cookie_consent_controller.js"
    )

    expect(File).not_to exist(footer_path)
    expect(File).to exist(cookie_consent_path)
    expect(File).to exist(cookie_controller_path)

    layout = File.read(
      File.join(
        @destination_root,
        "app/views/layouts/application.html.erb"
      )
    )

    expect(layout).not_to include(
      'render "shared/footer"'
    )

    expect(layout).to include(
      '<%= render "shared/cookie_consent" %>'
    )
  end

  it "adds cookie settings to the footer when cookie consent is installed" do
    create_application_layout
    create_gemfile

    generator = build_generator(
      false, # bcrypt
      false, # Active Storage
      false, # home page
      false, # hero
      true,  # footer
      false, # sitemap
      true   # cookie consent
    )

    generator.invoke_all

    footer_path = File.join(
      @destination_root,
      "app/views/shared/_footer.html.erb"
    )

    expect(File).to exist(footer_path)

    footer = File.read(footer_path)

    expect(footer).to include(
      "data-b4um-cookie-consent-open"
    )

    expect(footer).to include(
      "Cookie-Einstellungen"
    )

    expect(footer).to include(
      "b4um-footer__link--button"
    )

    expect(
      footer.scan("data-b4um-cookie-consent-open").count
    ).to eq(1)
  end

  it "does not duplicate cookie consent setup" do
    create_application_layout
    create_gemfile

    generator = build_generator(
      false, # bcrypt
      false, # Active Storage
      false, # home page
      false, # hero
      true,  # footer
      false, # sitemap
      true   # cookie consent
    )

    generator.invoke_all
    generator.invoke_all

    layout = File.read(
      File.join(
        @destination_root,
        "app/views/layouts/application.html.erb"
      )
    )

    footer = File.read(
      File.join(
        @destination_root,
        "app/views/shared/_footer.html.erb"
      )
    )

    expect(
      layout.scan('<%= render "shared/cookie_consent" %>').count
    ).to eq(1)

    expect(
      footer.scan("data-b4um-cookie-consent-open").count
    ).to eq(1)
  end
end
