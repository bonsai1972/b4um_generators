# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"
require "generators/b4um/pagination/pagination_generator"

RSpec.describe B4um::Generators::PaginationGenerator do
  before do
    @destination_root = Dir.mktmpdir

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/controllers")
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
        "app/controllers/products_controller.rb"
      ),
      <<~RUBY
        class ProductsController < ApplicationController
          def index
            @products = Product.all
          end
        end
      RUBY
    )

    File.write(
      File.join(
        @destination_root,
        "app/views/products/index.html.erb"
      ),
      <<~ERB
        <h1>Products</h1>

        <%= render "bento", products: @products %>
      ERB
    )
  end

  after do
    FileUtils.remove_entry(@destination_root)
  end

  it "loads the B4UM pagination generator" do
    expect(described_class).to be < Rails::Generators::NamedBase
  end

  it "accepts the default per-page value" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.not_to raise_error
  end

  it "creates the shared pagination concern" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    pagination_path = File.join(
      @destination_root,
      "app/controllers/concerns/b4um_pagination.rb"
    )

    expect(File).to exist(pagination_path)

    content = File.read(pagination_path)

    expect(content).to include("module B4umPagination")
    expect(content).to include("def b4um_paginate(scope, per_page:)")
    expect(content).to include(".limit(per_page)")
    expect(content).to include(".offset((current_page - 1) * per_page)")
  end

  it "creates the shared pagination partial" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    pagination_path = File.join(
      @destination_root,
      "app/views/shared/_pagination.html.erb"
    )

    expect(File).to exist(pagination_path)

    content = File.read(pagination_path)

    expect(content).to include('class="b4um-pagination"')
    expect(content).to include("pagination.previous_page")
    expect(content).to include("pagination.current_page")
    expect(content).to include("pagination.next_page")
    expect(content).to include("pagination.total_pages")
    expect(content).to include("request.query_parameters")
  end

  it "adds pagination to the resource controller" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      @destination_root,
      "app/controllers/products_controller.rb"
    )

    content = File.read(controller_path)

    expect(content).to include("include B4umPagination")

    expect(content).to match(
      /    @products, @pagination = b4um_paginate\(\n      Product\.all,\n      per_page: 20\n    \)/
    )

    expect(content).not_to include("@products = Product.all")
  end

  it "adds the pagination partial to the index view" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/views/products")
    )

    File.write(
      File.join(
        @destination_root,
        "app/views/products/index.html.erb"
      ),
      <<~ERB
        <h1>Products</h1>

        <%= render "bento", products: @products %>
      ERB
    )

    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    index_path = File.join(
      @destination_root,
      "app/views/products/index.html.erb"
    )

    content = File.read(index_path)

    expect(content).to include(
      '<%= render "shared/pagination", pagination: @pagination %>'
    )

    expect(
      content.scan('render "shared/pagination"').count
    ).to eq(1)
  end

  it "uses a custom per-page value in the controller" do
    generator = described_class.new(
      ["Product"],
      { per_page: 50 },
      destination_root: @destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      @destination_root,
      "app/controllers/products_controller.rb"
    )

    content = File.read(controller_path)

    expect(content).to match(
      /    @products, @pagination = b4um_paginate\(\n      Product\.all,\n      per_page: 50\n    \)/
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

  it "raises an error when the controller does not exist" do
    FileUtils.rm(
      File.join(
        @destination_root,
        "app/controllers/products_controller.rb"
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
      "Controller not found: app/controllers/products_controller.rb"
    )
  end

  it "raises an error when the index view does not exist" do
    FileUtils.rm(
      File.join(
        @destination_root,
        "app/views/products/index.html.erb"
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
      "Index view not found: app/views/products/index.html.erb"
    )
  end

  it "rejects a per-page value of zero" do
    generator = described_class.new(
      ["Product"],
      { per_page: 0 },
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      "--per-page must be greater than 0"
    )
  end
end
