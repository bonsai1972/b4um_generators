# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"
require "generators/b4um/bento/bento_generator"

RSpec.describe B4um::Generators::BentoGenerator do
  before do
    @destination_root = Dir.mktmpdir

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/views/products")
    )

    File.write(
      File.join(@destination_root, "app/models/product.rb"),
      "class Product < ApplicationRecord\nend\n"
    )

    File.write(
      File.join(
        @destination_root,
        "app/views/products/_product.html.erb"
      ),
      "<div><%= product %></div>\n"
    )
  end

  after do
    FileUtils.remove_entry(@destination_root)
  end

  it "loads the B4UM Bento generator" do
    expect(described_class).to be < Rails::Generators::NamedBase
  end

  it "generates a B4UM Bento partial for an existing model" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    partial_path = File.join(
      @destination_root,
      "app/views/products/_bento.html.erb"
    )

    expect(File).to exist(partial_path)

    bento = File.read(partial_path)

    expect(bento).to include(
      'id="products" class="b4um-grid"'
    )

    expect(bento).to include(
      "products.each_with_index do |product, index|"
    )

    expect(bento).to include(
      '"b4um-card b4um-card--wide"'
    )

    expect(bento).to include(
      '"b4um-card b4um-card--soft"'
    )

    expect(bento).to include(
      '"b4um-card b4um-card--large"'
    )

    expect(bento).to include(
      "render product, compact: true"
    )

    expect(bento).to include(
      'class: "button button--secondary"'
    )
  end

  it "raises an error when the model does not exist" do
    generator = described_class.new(
      ["Unknown"],
      {},
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      "Model not found: app/models/unknown.rb"
    )
  end

  it "raises an error when the resource partial does not exist" do
    FileUtils.rm(
      File.join(
        @destination_root,
        "app/views/products/_product.html.erb"
      )
    )

    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      "Resource partial not found: app/views/products/_product.html.erb"
    )
  end
end
