# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "generators/b4um/controller/controller_generator"

RSpec.describe B4um::Generators::ControllerGenerator do
  around do |example|
    Dir.mktmpdir("b4um_controller_test") do |directory|
      @destination_root = directory
      example.run
    end
  end

  it "loads the B4UM controller generator" do
    expect(described_class).to be < Rails::Generators::ControllerGenerator
  end

  it "generates B4UM controller views" do
    routes_directory = File.join(
      @destination_root,
      "config"
    )

    FileUtils.mkdir_p(routes_directory)

    File.write(
      File.join(routes_directory, "routes.rb"),
      <<~RUBY
        Rails.application.routes.draw do
        end
      RUBY
    )

    generator = described_class.new(
      %w[Pages home about],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    home_path = File.join(
      @destination_root,
      "app/views/pages/home.html.erb"
    )

    about_path = File.join(
      @destination_root,
      "app/views/pages/about.html.erb"
    )

    expect(File).to exist(home_path)
    expect(File).to exist(about_path)

    home = File.read(home_path)
    about = File.read(about_path)

    expect(home).to include(
      '<% content_for :title, "Home" %>'
    )

    expect(home).to include(
      '<div class="page-header">'
    )

    expect(home).to include(
      "<h1>Home</h1>"
    )

    expect(home).to include(
      '<div class="b4um-grid">'
    )

    expect(home).to include(
      '<section class="b4um-card b4um-card--full">'
    )

    expect(home).to include(
      'class="b4um-card__title"'
    )

    expect(home).to include(
      'class="b4um-card__text"'
    )

    expect(home).to include(
      "Add your content here."
    )

    expect(about).to include(
      '<% content_for :title, "About" %>'
    )

    expect(about).to include(
      "<h1>About</h1>"
    )
  end

  it "uses B4UM labels for abbreviated action names" do
    routes_directory = File.join(
      @destination_root,
      "config"
    )

    FileUtils.mkdir_p(routes_directory)

    File.write(
      File.join(routes_directory, "routes.rb"),
      <<~RUBY
        Rails.application.routes.draw do
        end
      RUBY
    )

    generator = described_class.new(
      %w[Pages agb faq],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    agb = File.read(
      File.join(
        @destination_root,
        "app/views/pages/agb.html.erb"
      )
    )

    faq = File.read(
      File.join(
        @destination_root,
        "app/views/pages/faq.html.erb"
      )
    )

    expect(agb).to include(
      '<% content_for :title, "AGB" %>'
    )

    expect(agb).to include(
      "<h1>AGB</h1>"
    )

    expect(faq).to include(
      '<% content_for :title, "FAQ" %>'
    )

    expect(faq).to include(
      "<h1>FAQ</h1>"
    )
  end

  it "adds controller actions to the B4UM navigation" do
    navigation_directory = File.join(
      @destination_root,
      "app/views/shared"
    )

    FileUtils.mkdir_p(navigation_directory)

    navigation_path = File.join(
      navigation_directory,
      "_navigation.html.erb"
    )

    File.write(
      navigation_path,
      <<~ERB
        <div
          class="navigation__menu"
          id="navigation-menu"
          data-navigation-target="menu"
        >
          <%# B4UM_NAVIGATION_LINKS %>
        </div>
      ERB
    )

    routes_directory = File.join(
      @destination_root,
      "config"
    )

    FileUtils.mkdir_p(routes_directory)

    File.write(
      File.join(routes_directory, "routes.rb"),
      <<~RUBY
        Rails.application.routes.draw do
        end
      RUBY
    )

    generator = described_class.new(
      %w[Pages home about impressum agb faq],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    # Ein zweiter Aufruf darf die Links nicht duplizieren.
    generator.add_navigation_links

    navigation = File.read(navigation_path)

    expect(navigation).to include(
      'navigation_link_to "Home"'
    )

    expect(navigation).to include(
      "pages_home_path"
    )

    expect(navigation).to include(
      "controller: :pages"
    )

    expect(navigation).to include(
      "action: :home"
    )

    expect(navigation).to include(
      'navigation_link_to "About"'
    )

    expect(navigation).to include(
      "pages_about_path"
    )

    expect(navigation).to include(
      "action: :about"
    )

    expect(navigation).to include(
      'navigation_link_to "Impressum"'
    )

    expect(navigation).to include(
      "pages_impressum_path"
    )

    expect(navigation).to include(
      "action: :impressum"
    )

    expect(navigation).to include(
      'navigation_link_to "AGB"'
    )

    expect(navigation).to include(
      "pages_agb_path"
    )

    expect(navigation).to include(
      "action: :agb"
    )

    expect(navigation).to include(
      'navigation_link_to "FAQ"'
    )

    expect(navigation).to include(
      "pages_faq_path"
    )

    expect(navigation).to include(
      "action: :faq"
    )

    expect(navigation).to include(
      "<%# B4UM_NAVIGATION_LINKS %>"
    )

    expect(
      navigation.scan("action: :home").count
    ).to eq(1)

    expect(
      navigation.scan("action: :about").count
    ).to eq(1)

    expect(
      navigation.scan("action: :impressum").count
    ).to eq(1)

    expect(
      navigation.scan("action: :agb").count
    ).to eq(1)

    expect(
      navigation.scan("action: :faq").count
    ).to eq(1)
  end
end
