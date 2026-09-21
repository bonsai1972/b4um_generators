# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "generators/b4um/table/table_generator"

RSpec.describe B4um::Generators::TableGenerator do
  around do |example|
    Dir.mktmpdir("b4um_table_generator_test") do |directory|
      @destination_root = directory

      example.run
    end
  end

  it "loads the B4UM table generator" do
    expect(described_class).to be < Rails::Generators::NamedBase
  end

  it "generates a B4UM table partial for an existing model" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    File.write(
      File.join(
        @destination_root,
        "app/models/product.rb"
      ),
      <<~RUBY
        class Product < ApplicationRecord
        end
      RUBY
    )

    generator = described_class.new(
      [
        "Product",
        "name:string",
        "description:text",
        "price:decimal",
        "status:string"
      ],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    table_path = File.join(
      @destination_root,
      "app/views/products/_table.html.erb"
    )

    expect(File).to exist(table_path)

    table = File.read(table_path)

    expect(table).to include(
      'class="b4um-table-wrapper"'
    )

    expect(table).to include(
      'class="b4um-table"'
    )

    expect(table).to include(
      '<tbody id="products">'
    )

    expect(table).to include("<th>Name</th>")
    expect(table).to include("<th>Description</th>")
    expect(table).to include("<th>Price</th>")
    expect(table).to include("<th>Status</th>")
    expect(table).to include("<th>Actions</th>")

    expect(table).to include(
      "products.each do |product|"
    )

    expect(table).to include("product.name")
    expect(table).to include(
      "truncate(product.description, length: 100)"
    )
    expect(table).to include("product.price")
    expect(table).to include("product.status")

    expect(table).to include(
      'class="b4um-badge"'
    )

    expect(table).to include(
      'class="b4um-table__actions"'
    )

    expect(table).to include(
      'class: "button button--secondary"'
    )
  end

  it "raises an error when the model does not exist" do
    generator = described_class.new(
      [
        "MissingProduct",
        %w[name status]
      ],
      {},
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      "Model not found: app/models/missing_product.rb"
    )
  end
end
