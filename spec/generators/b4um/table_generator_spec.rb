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

  def create_product_model
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
  end

  def stub_product_model(
    columns: [],
    associations: [],
    attachments: []
  )
    product_class = double(
      "Product",
      columns: columns,
      reflect_on_all_associations: associations,
      reflect_on_all_attachments: attachments
    )

    stub_const("Product", product_class)
  end

  it "loads the B4UM table generator" do
    expect(described_class).to be < Rails::Generators::NamedBase
  end

  it "generates a B4UM table partial for model fields" do
    create_product_model

    columns = [
      Struct.new(:name, :type).new("name", :string),
      Struct.new(:name, :type).new("description", :text),
      Struct.new(:name, :type).new("price", :decimal),
      Struct.new(:name, :type).new("status", :string)
    ]

    stub_product_model(columns: columns)

    generator = described_class.new(
      %w[
        Product
        name
        description
        price
        status
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

  it "uses the actual model type instead of a supplied field type" do
    create_product_model

    columns = [
      Struct.new(:name, :type).new("price", :decimal)
    ]

    stub_product_model(columns: columns)

    generator = described_class.new(
      [
        "Product",
        "price:string"
      ],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    table = File.read(
      File.join(
        @destination_root,
        "app/views/products/_table.html.erb"
      )
    )

    expect(table).to include("product.price")
  end

  it "accepts configured select and radio fields" do
    create_product_model

    columns = [
      Struct.new(:name, :type).new("status", :string),
      Struct.new(:name, :type).new("condition", :string)
    ]

    stub_product_model(columns: columns)

    generator = described_class.new(
      %w[
        Product
        status
        condition
      ],
      {
        select: "status:Active=Aktiv,Inactive=Inaktiv",
        radio: "condition:new=Neu,used=Gebraucht,refurbished=Generalüberholt"
      },
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.not_to raise_error
  end

  it "recognizes rich text fields from the model" do
    create_product_model

    association = Struct.new(:name).new(
      :rich_text_description
    )

    stub_product_model(
      associations: [association]
    )

    generator = described_class.new(
      %w[Product description],
      {},
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.not_to raise_error
  end

  it "recognizes single and multiple attachments from the model" do
    create_product_model

    reflection = Struct.new(:name, :macro)

    attachments = [
      reflection.new(:image, :has_one_attached),
      reflection.new(:gallery, :has_many_attached)
    ]

    stub_product_model(
      attachments: attachments
    )

    generator = described_class.new(
      %w[Product image gallery],
      {},
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.not_to raise_error
  end

  it "accepts field:type syntax with select configuration" do
    create_product_model

    columns = [
      Struct.new(:name, :type).new("status", :string)
    ]

    stub_product_model(columns: columns)

    generator = described_class.new(
      [
        "Product",
        "status:string"
      ],
      {
        select: "status:Active=Aktiv,Inactive=Inaktiv"
      },
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.not_to raise_error
  end

  it "rejects a select configuration for an unknown field" do
    create_product_model

    columns = [
      Struct.new(:name, :type).new("name", :string),
      Struct.new(:name, :type).new("status", :string)
    ]

    stub_product_model(columns: columns)

    generator = described_class.new(
      %w[Product name status],
      {
        select: "category:Active=Aktiv,Inactive=Inaktiv"
      },
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      "--select field category must be one of the generated fields: name, status"
    )
  end

  it "rejects a select configuration without values" do
    create_product_model

    columns = [
      Struct.new(:name, :type).new("status", :string)
    ]

    stub_product_model(columns: columns)

    generator = described_class.new(
      %w[Product status],
      {
        select: "status:"
      },
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      "Invalid --select configuration. Expected FIELD:VALUE[,VALUE...]"
    )
  end

  it "rejects a radio configuration for an unknown field" do
    create_product_model

    columns = [
      Struct.new(:name, :type).new("condition", :string)
    ]

    stub_product_model(columns: columns)

    generator = described_class.new(
      %w[Product condition],
      {
        radio: "category:new=Neu,used=Gebraucht"
      },
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      "--radio field category must be one of the generated fields: condition"
    )
  end

  it "rejects a radio configuration without values" do
    create_product_model

    columns = [
      Struct.new(:name, :type).new("condition", :string)
    ]

    stub_product_model(columns: columns)

    generator = described_class.new(
      %w[Product condition],
      {
        radio: "condition:,,"
      },
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      "Invalid --radio configuration. Expected FIELD:VALUE[,VALUE...]"
    )
  end

  it "rejects using select and radio for the same field" do
    create_product_model

    columns = [
      Struct.new(:name, :type).new("status", :string)
    ]

    stub_product_model(columns: columns)

    generator = described_class.new(
      %w[Product status],
      {
        select: "status:Active=Aktiv,Inactive=Inaktiv",
        radio: "status:Active=Aktiv,Inactive=Inaktiv"
      },
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      "Field status cannot use both --select and --radio"
    )
  end

  it "renders configured select and radio labels in the table" do
    create_product_model

    columns = [
      Struct.new(:name, :type).new("status", :string),
      Struct.new(:name, :type).new("condition", :string)
    ]

    stub_product_model(columns: columns)

    generator = described_class.new(
      %w[
        Product
        status
        condition
      ],
      {
        select: "status:Active=Aktiv,Inactive=Inaktiv",
        radio: "condition:new=Neu,used=Gebraucht,refurbished=Generalüberholt"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    table = File.read(
      File.join(
        @destination_root,
        "app/views/products/_table.html.erb"
      )
    )

    expect(table).to include("Active")
    expect(table).to include("Aktiv")
    expect(table).to include("Inactive")
    expect(table).to include("Inaktiv")

    expect(table).to include("new")
    expect(table).to include("Neu")
    expect(table).to include("used")
    expect(table).to include("Gebraucht")
    expect(table).to include("refurbished")
    expect(table).to include("Generalüberholt")

    expect(table).to include(
      'class="b4um-badge"'
    )
  end

  it "renders rich text with image lightbox support" do
    create_product_model

    association = Struct.new(:name).new(
      :rich_text_description
    )

    stub_product_model(
      associations: [association]
    )

    generator = described_class.new(
      %w[Product description],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    table = File.read(
      File.join(
        @destination_root,
        "app/views/products/_table.html.erb"
      )
    )

    expect(table).to include(
      'class="b4um-table__rich-text trix-content"'
    )

    expect(table).to include(
      'data-controller="image-lightbox rich-text"'
    )

    expect(table).to include(
      "<%= product.description %>"
    )

    expect(table).to include(
      'data-image-lightbox-target="overlay"'
    )

    expect(table).to include(
      'data-image-lightbox-target="image"'
    )

    expect(table).to include(
      "pointerdown->image-lightbox#pointerDown"
    )

    expect(table).to include(
      "pointermove->image-lightbox#pointerMove"
    )

    expect(table).to include(
      "pointerup->image-lightbox#pointerUp"
    )

    expect(table).to include(
      "pointercancel->image-lightbox#pointerCancel"
    )

    expect(table).to include(
      'data-image-lightbox-target="thumbnails"'
    )

    expect(table).to include(
      'data-image-lightbox-target="caption"'
    )

    expect(table).to include(
      'data-action="click->image-lightbox#previous"'
    )

    expect(table).to include(
      'data-action="click->image-lightbox#next"'
    )

    expect(table).to include(
      'class="image-lightbox__navigation image-lightbox__navigation--previous"'
    )

    expect(table).to include(
      'class="image-lightbox__navigation image-lightbox__navigation--next"'
    )
  end

  it "renders single and multiple attachments as lightbox thumbnails" do
    create_product_model

    reflection = Struct.new(:name, :macro)

    attachments = [
      reflection.new(:image, :has_one_attached),
      reflection.new(:gallery, :has_many_attached)
    ]

    stub_product_model(
      attachments: attachments
    )

    generator = described_class.new(
      %w[Product image gallery],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    table = File.read(
      File.join(
        @destination_root,
        "app/views/products/_table.html.erb"
      )
    )

    expect(table).to include(
      "<% if product.image.attached? %>"
    )

    expect(table).to include(
      "<%= url_for(product.image) %>"
    )

    expect(table).to include(
      "<%= image_tag product.image,"
    )

    expect(table).to include(
      "<% if product.gallery.attached? %>"
    )

    expect(table).to include(
      "<% product.gallery.each do |image| %>"
    )

    expect(table).to include(
      "<%= url_for(image) %>"
    )

    expect(table).to include(
      "<%= image_tag image,"
    )

    expect(table).to include(
      'class="b4um-table__image-button"'
    )

    expect(table).to include(
      'class: "b4um-table__image"'
    )

    expect(table).to include(
      'data-image-lightbox-target="item"'
    )

    expect(table).to include(
      'data-action="click->image-lightbox#open"'
    )

    expect(table).to include(
      'aria-label="Image gallery"'
    )

    expect(table).to include(
      'data-action="click->image-lightbox#previous"'
    )

    expect(table).to include(
      'data-action="click->image-lightbox#next"'
    )

    expect(table).not_to include(
      "<%= product.image %>"
    )

    expect(table).not_to include(
      "<%= product.gallery %>"
    )
  end

  it "automatically uses model fields when no fields are supplied" do
    create_product_model

    columns = [
      Struct.new(:name, :type).new("id", :integer),
      Struct.new(:name, :type).new("name", :string),
      Struct.new(:name, :type).new("price", :decimal),
      Struct.new(:name, :type).new("status", :string),
      Struct.new(:name, :type).new("created_at", :datetime),
      Struct.new(:name, :type).new("updated_at", :datetime)
    ]

    association = Struct.new(:name).new(
      :rich_text_description
    )

    reflection = Struct.new(:name, :macro)

    attachments = [
      reflection.new(:image, :has_one_attached),
      reflection.new(:gallery, :has_many_attached)
    ]

    stub_product_model(
      columns: columns,
      associations: [association],
      attachments: attachments
    )

    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    table = File.read(
      File.join(
        @destination_root,
        "app/views/products/_table.html.erb"
      )
    )

    expect(table).to include("<th>Name</th>")
    expect(table).to include("<th>Price</th>")
    expect(table).to include("<th>Status</th>")
    expect(table).to include("<th>Description</th>")
    expect(table).to include("<th>Image</th>")
    expect(table).to include("<th>Gallery</th>")

    expect(table).not_to include("<th>Id</th>")
    expect(table).not_to include("<th>Created at</th>")
    expect(table).not_to include("<th>Updated at</th>")

    expect(table).to include(
      "<%= product.description %>"
    )

    expect(table).to include(
      "<% if product.image.attached? %>"
    )

    expect(table).to include(
      "<% product.gallery.each do |image| %>"
    )
  end

  it "switches an existing bento index to the table layout" do
    create_product_model

    columns = [
      Struct.new(:name, :type).new("name", :string)
    ]

    stub_product_model(columns: columns)

    views_path = File.join(
      @destination_root,
      "app/views/products"
    )

    FileUtils.mkdir_p(views_path)

    index_path = File.join(
      views_path,
      "index.html.erb"
    )

    File.write(
      index_path,
      <<~ERB
        <%= content_for :title, "Products" %>

        <% if @products.any? %>
          <%= render "bento",
                     products: @products %>
        <% end %>
      ERB
    )

    generator = described_class.new(
      %w[Product name],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    index = File.read(index_path)

    expect(index).to include(
      '<%= render "table",'
    )

    expect(index).to include(
      "products: @products"
    )

    expect(index).not_to include(
      'render "bento"'
    )
  end

  it "raises an error when the model does not exist" do
    generator = described_class.new(
      %w[MissingProduct name status],
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
