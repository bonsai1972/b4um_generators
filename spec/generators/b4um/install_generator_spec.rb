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
  it "installs the B4UM stylesheet and updates the layout" do
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

    generator = described_class.new(
      [],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    expect(
      File.exist?(
        File.join(
          @destination_root,
          "app/assets/stylesheets/b4um.css"
        )
      )
    ).to be(true)

    layout = File.read(
      File.join(layout_directory, "application.html.erb")
    )

    expect(layout).to include('<main class="container">')
    expect(layout).to include("flash.each")
    expect(layout).to include('<div class="flash <%= "flash--" + type.to_s %>">')
    expect(layout).to include("<%= yield %>")
    expect(layout).to include("</main>")
  end

  it "does not duplicate the B4UM layout setup" do
    layout_directory = File.join(
      @destination_root,
      "app/views/layouts"
    )

    FileUtils.mkdir_p(layout_directory)

    layout_path = File.join(
      layout_directory,
      "application.html.erb"
    )

    File.write(
      layout_path,
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

    generator = described_class.new(
      [],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    generator = described_class.new(
      [],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    layout = File.read(layout_path)

    expect(layout.scan('<main class="container">').count).to eq(1)
    expect(layout.scan("flash.each").count).to eq(1)
    expect(layout.scan("</main>").count).to eq(1)
  end
  it "loads the B4UM install generator" do
    expect(described_class).to be < Rails::Generators::Base
  end
end
