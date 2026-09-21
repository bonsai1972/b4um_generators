# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"
require "generators/b4um/infinite_scroll/infinite_scroll_generator"

RSpec.describe B4um::Generators::InfiniteScrollGenerator do
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

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/views/shared")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/javascript/controllers")
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

    File.write(
      File.join(
        @destination_root,
        "app/views/products/_bento.html.erb"
      ),
      <<~ERB
        <div id="products" class="b4um-grid">
          <% products.each do |product| %>
            <article class="b4um-card">
              <%= render product, compact: true %>
            </article>
          <% end %>
        </div>
      ERB
    )
  end

  after do
    FileUtils.remove_entry(@destination_root)
  end

  it "loads the B4UM infinite scroll generator" do
    expect(described_class).to be < Rails::Generators::NamedBase
  end

  it "describes the B4UM infinite scroll generator" do
    expect(described_class.desc).to eq(
      "Adds B4UM infinite scroll to an existing resource."
    )
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

    path = File.join(
      @destination_root,
      "app/controllers/concerns/b4um_pagination.rb"
    )

    expect(File).to exist(path)

    content = File.read(path)

    expect(content).to include("module B4umPagination")
    expect(content).to include("def b4um_paginate(scope, per_page:)")
  end

  it "creates the infinite scroll Stimulus controller" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    path = File.join(
      @destination_root,
      "app/javascript/controllers/infinite_scroll_controller.js"
    )

    expect(File).to exist(path)

    content = File.read(path)

    expect(content).to include("IntersectionObserver")
    expect(content).to include("fetch(")
  end

  it "loads and appends the next page" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    path = File.join(
      @destination_root,
      "app/javascript/controllers/infinite_scroll_controller.js"
    )

    content = File.read(path)

    expect(content).to include("response.text()")
    expect(content).to include("insertAdjacentHTML")
  end

  it "extracts items from the next page response" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    path = File.join(
      @destination_root,
      "app/javascript/controllers/infinite_scroll_controller.js"
    )

    content = File.read(path)

    expect(content).to include("DOMParser")
    expect(content).to include("container: String")
    expect(content).to include(
      "querySelector(`#${this.containerValue}`)"
    )
  end

  it "appends only the next page grid contents" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    path = File.join(
      @destination_root,
      "app/javascript/controllers/infinite_scroll_controller.js"
    )

    content = File.read(path)

    expect(content).to include(
      "currentGrid.insertAdjacentHTML('beforeend', nextGrid.innerHTML)"
    )
  end

  it "updates the next page URL after loading" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    path = File.join(
      @destination_root,
      "app/javascript/controllers/infinite_scroll_controller.js"
    )

    content = File.read(path)

    expect(content).to include(
      '[data-controller="infinite-scroll"]'
    )

    expect(content).to include(
      "this.nextUrlValue = nextSentinel.dataset.infiniteScrollNextUrlValue"
    )
  end

  it "stops observing when there is no next page" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    path = File.join(
      @destination_root,
      "app/javascript/controllers/infinite_scroll_controller.js"
    )

    content = File.read(path)

    expect(content).to include(
      "this.observer.disconnect()"
    )

    expect(content).to include(
      "this.element.remove()"
    )
  end

  it "adds server-side pagination to the resource controller" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    path = File.join(
      @destination_root,
      "app/controllers/products_controller.rb"
    )

    content = File.read(path)

    expect(content).to include("include B4umPagination")

    expect(content).to match(
      /    @products, @pagination = b4um_paginate\(\n      Product\.all,\n      per_page: 20\n    \)/
    )
  end

  it "uses a custom per-page value" do
    generator = described_class.new(
      ["Product"],
      { per_page: 50 },
      destination_root: @destination_root
    )

    generator.invoke_all

    path = File.join(
      @destination_root,
      "app/controllers/products_controller.rb"
    )

    content = File.read(path)

    expect(content).to match(
      /    @products, @pagination = b4um_paginate\(\n      Product\.all,\n      per_page: 50\n    \)/
    )
  end

  it "adds infinite scroll to the index view" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    path = File.join(
      @destination_root,
      "app/views/products/index.html.erb"
    )

    content = File.read(path)

    expect(content).to include(
      'data-controller="infinite-scroll"'
    )

    expect(content).to include(
      "data-infinite-scroll-next-url-value"
    )
  end

  it "configures the resource container in the index view" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    path = File.join(
      @destination_root,
      "app/views/products/index.html.erb"
    )

    content = File.read(path)

    expect(content).to include(
      'data-infinite-scroll-container-value="products"'
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

  it "is idempotent when invoked twice" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/products_controller.rb"
      )
    )

    index = File.read(
      File.join(
        @destination_root,
        "app/views/products/index.html.erb"
      )
    )

    expect(
      controller.scan("include B4umPagination").count
    ).to eq(1)

    expect(
      controller.scan("b4um_paginate(").count
    ).to eq(1)

    expect(
      index.scan('data-controller="infinite-scroll"').count
    ).to eq(1)
  end

  it "raises an error when the index collection cannot be found" do
    File.write(
      File.join(
        @destination_root,
        "app/controllers/products_controller.rb"
      ),
      <<~RUBY
        class ProductsController < ApplicationController
          def index
            @products = Product.order(:name)
          end
        end
      RUBY
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
      "Could not find the index collection in app/controllers/products_controller.rb"
    )
  end

  it "removes existing B4UM pagination from the index view" do
    path = File.join(
      @destination_root,
      "app/views/products/index.html.erb"
    )

    File.open(path, "a") do |file|
      file.write(
        "\n<%= render \"shared/pagination\", pagination: @pagination %>\n"
      )
    end

    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    content = File.read(path)

    expect(content).not_to include(
      'render "shared/pagination", pagination: @pagination'
    )

    expect(content).to include(
      'data-controller="infinite-scroll"'
    )
  end

  it "adds infinite scroll to an existing B4UM search" do
    File.write(
      File.join(
        @destination_root,
        "app/controllers/products_controller.rb"
      ),
      <<~RUBY
        class ProductsController < ApplicationController
          include B4umSearch

          def index
            @products = b4um_search(
              Product.all,
              params[:q]
            )
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/products_controller.rb"
      )
    )

    expect(controller).to match(
      /@products,\s*@pagination\s*=\s*b4um_paginate\(\s*
        b4um_search\(\s*
          Product\.all,\s*
          params\[:q\]\s*
        \),\s*
        per_page:\s*20\s*
      \)/x
    )
  end
end
