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

  it "generates the grid layout by default" do
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

    grid = File.read(partial_path)

    expect(grid).to include(
      'id="products" class="b4um-card-grid"'
    )

    expect(grid).to include(
      "products.each do |product|"
    )

    expect(grid).to include(
      '<article class="b4um-card">'
    )

    expect(grid).to include(
      "render product, compact: true"
    )

    expect(grid).to include(
      'class: "button button--secondary"'
    )

    expect(grid).not_to include(
      "b4um-card--wide"
    )

    expect(grid).not_to include(
      "b4um-card--large"
    )
  end

  it "generates a three-column card grid layout" do
    generator = described_class.new(
      ["Product"],
      { layout: "grid" },
      destination_root: @destination_root
    )

    generator.invoke_all

    partial_path = File.join(
      @destination_root,
      "app/views/products/_bento.html.erb"
    )

    expect(File).to exist(partial_path)

    grid = File.read(partial_path)

    expect(grid).to include(
      'id="products" class="b4um-card-grid"'
    )

    expect(grid).to include(
      "products.each do |product|"
    )

    expect(grid).to include(
      '<article class="b4um-card">'
    )

    expect(grid).to include(
      "render product, compact: true"
    )

    expect(grid).to include(
      'class: "button button--secondary"'
    )

    expect(grid).not_to include(
      "b4um-card--wide"
    )

    expect(grid).not_to include(
      "b4um-card--large"
    )
  end

  it "generates the classic Bento layout explicitly" do
    generator = described_class.new(
      ["Product"],
      { layout: "bento" },
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
  it "generates a compact list layout" do
    generator = described_class.new(
      ["Product"],
      { layout: "list" },
      destination_root: @destination_root
    )

    generator.invoke_all

    partial_path = File.join(
      @destination_root,
      "app/views/products/_bento.html.erb"
    )

    expect(File).to exist(partial_path)

    list = File.read(partial_path)

    expect(list).to include(
      'id="products" class="b4um-list"'
    )

    expect(list).to include(
      "products.each do |product|"
    )

    expect(list).to include(
      '<article class="b4um-list__item">'
    )

    expect(list).to include(
      '<div class="b4um-list__content">'
    )

    expect(list).to include(
      '<div class="b4um-list__actions">'
    )

    expect(list).to include(
      "render product, compact: true"
    )

    expect(list).to include(
      'class: "button button--secondary"'
    )
  end

  it "generates an alternating layout" do
    generator = described_class.new(
      ["Product"],
      { layout: "alternating" },
      destination_root: @destination_root
    )

    generator.invoke_all

    partial_path = File.join(
      @destination_root,
      "app/views/products/_bento.html.erb"
    )

    expect(File).to exist(partial_path)

    alternating = File.read(partial_path)

    expect(alternating).to include(
      'id="products" class="b4um-alternating"'
    )

    expect(alternating).to include(
      "products.each_with_index do |product, index|"
    )

    expect(alternating).to include(
      "b4um-alternating__item--reverse"
    )

    expect(alternating).to include(
      '<div class="b4um-alternating__content">'
    )

    expect(alternating).to include(
      '<div class="b4um-alternating__actions">'
    )

    expect(alternating).to include(
      "render product, compact: true"
    )

    expect(alternating).to include(
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

  it "switches an existing table index back to the bento layout" do
    index_path = File.join(
      @destination_root,
      "app/views/products/index.html.erb"
    )

    File.write(
      index_path,
      <<~ERB
        <%= content_for :title, "Products" %>

        <% if @products.any? %>
          <%= render "table",
                     products: @products %>
        <% end %>
      ERB
    )

    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    index = File.read(index_path)

    expect(index).to include(
      '<%= render "bento",'
    )

    expect(index).to include(
      "products: @products"
    )

    expect(index).not_to include(
      'render "table"'
    )
  end
end
