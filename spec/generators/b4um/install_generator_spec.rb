# frozen_string_literal: true

require "spec_helper"
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

  def build_generator(*answers)
    generator = described_class.new(
      [],
      {},
      destination_root: @destination_root
    )

    allow(generator).to receive(:yes?).and_return(*answers)

    generator
  end

  it "loads the B4UM install generator" do
    expect(described_class).to be < Rails::Generators::Base
  end

  it "installs the B4UM base setup with hero and footer" do
    create_application_layout
    create_gemfile

    generator = build_generator(
      false,
      false,
      true,
      true
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
      resources.css
      lightbox.css
      hero.css
      cards.css
      flash.css
      comments.css
      footer.css
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
      resources.css
      lightbox.css
      hero.css
      cards.css
      flash.css
      comments.css
      footer.css
    ]

    expected_components.each do |stylesheet_name|
      expect(File).to exist(
        File.join(component_directory, stylesheet_name)
      )
    end

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
      'class="b4um-footer"'
    )

    expect(footer).to include(
      "Time.current.year"
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
      '<%= render "shared/hero" %>'
    )

    expect(layout).to include(
      "flash.each"
    )

    expect(layout).to include(
      '<div class="flash <%= "flash--" + type.to_s %>">'
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

    main_end = layout.index("</main>")
    footer_position = layout.index(
      '<%= render "shared/footer" %>'
    )

    expect(footer_position).to be > main_end
  end

  it "can skip hero and footer independently" do
    create_application_layout
    create_gemfile

    generator = build_generator(
      false,
      false,
      false,
      true
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
      'render "shared/hero"'
    )

    expect(layout).to include(
      'render "shared/footer"'
    )
  end

  it "can install hero without footer" do
    create_application_layout
    create_gemfile

    generator = build_generator(
      false,
      false,
      true,
      false
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
      'render "shared/hero"'
    )

    expect(layout).not_to include(
      'render "shared/footer"'
    )
  end

  it "does not duplicate the B4UM layout setup" do
    create_application_layout
    create_gemfile

    first_generator = build_generator(
      false,
      false,
      true,
      true
    )

    first_generator.invoke_all

    second_generator = build_generator(
      false,
      false,
      true,
      true
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
      layout.scan('<%= render "shared/hero" %>').count
    ).to eq(1)

    expect(
      layout.scan("flash.each").count
    ).to eq(1)

    expect(
      layout.scan("</main>").count
    ).to eq(1)

    expect(
      layout.scan('<%= render "shared/footer" %>').count
    ).to eq(1)
  end
end
