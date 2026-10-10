# frozen_string_literal: true

require "spec_helper"
require "generators/b4um/search/search_generator"
require "tmpdir"
require "fileutils"

RSpec.describe B4um::Generators::SearchGenerator do
  it "loads the B4UM search generator" do
    expect(described_class).to be < Rails::Generators::NamedBase
  end

  it "describes the B4UM search generator" do
    expect(described_class.desc).to eq(
      "Adds B4UM search to an existing resource."
    )
  end

  it "raises an error when the model does not exist" do
    Dir.mktmpdir("b4um_search_generator_test") do |directory|
      generator = described_class.new(
        ["MissingProduct"],
        {},
        destination_root: directory
      )

      expect do
        generator.invoke_all
      end.to raise_error(
        Thor::Error,
        "Model not found: app/models/missing_product.rb"
      )
    end
  end

  it "raises an error when the controller does not exist" do
    Dir.mktmpdir("b4um_search_generator_test") do |directory|
      FileUtils.mkdir_p(
        File.join(directory, "app/models")
      )

      File.write(
        File.join(directory, "app/models/product.rb"),
        <<~RUBY
          class Product < ApplicationRecord
          end
        RUBY
      )

      generator = described_class.new(
        ["Product"],
        {},
        destination_root: directory
      )

      expect do
        generator.invoke_all
      end.to raise_error(
        Thor::Error,
        "Controller not found: app/controllers/products_controller.rb"
      )
    end
  end

  it "raises an error when the index view does not exist" do
    Dir.mktmpdir("b4um_search_generator_test") do |directory|
      FileUtils.mkdir_p(
        File.join(directory, "app/models")
      )

      FileUtils.mkdir_p(
        File.join(directory, "app/controllers")
      )

      File.write(
        File.join(directory, "app/models/product.rb"),
        <<~RUBY
          class Product < ApplicationRecord
          end
        RUBY
      )

      File.write(
        File.join(directory, "app/controllers/products_controller.rb"),
        <<~RUBY
          class ProductsController < ApplicationController
            def index
              @products = Product.all
            end
          end
        RUBY
      )

      generator = described_class.new(
        ["Product"],
        {},
        destination_root: directory
      )

      expect do
        generator.invoke_all
      end.to raise_error(
        Thor::Error,
        "Index view not found: app/views/products/index.html.erb"
      )
    end
  end

  it "creates the shared search concern" do
    Dir.mktmpdir("b4um_search_generator_test") do |directory|
      FileUtils.mkdir_p(
        File.join(directory, "app/models")
      )

      FileUtils.mkdir_p(
        File.join(directory, "app/controllers")
      )

      FileUtils.mkdir_p(
        File.join(directory, "app/views/products")
      )

      File.write(
        File.join(directory, "app/models/product.rb"),
        <<~RUBY
          class Product < ApplicationRecord
          end
        RUBY
      )

      File.write(
        File.join(directory, "app/controllers/products_controller.rb"),
        <<~RUBY
          class ProductsController < ApplicationController
            def index
              @products = Product.all
            end
          end
        RUBY
      )

      File.write(
        File.join(directory, "app/views/products/index.html.erb"),
        "<h1>Products</h1>\n"
      )

      generator = described_class.new(
        ["Product"],
        {},
        destination_root: directory
      )

      generator.invoke_all

      concern_path = File.join(
        directory,
        "app/controllers/concerns/b4um_search.rb"
      )

      expect(File).to exist(concern_path)

      content = File.read(concern_path)

      expect(content).to include(
        "def b4um_search(scope, query)"
      )

      expect(content).to include(
        "return scope if query.blank?"
      )

      expect(content).to include(
        "scope.klass.columns"
      )

      expect(content).to include(
        "%i[string text].include?(column.type)"
      )

      expect(content).to include(
        "searchable_columns.map"
      )

      expect(content).to include(
        "LOWER("
      )

      expect(content).to include(
        "ActiveRecord::Base.sanitize_sql_like"
      )

      expect(content).to include(
        "scope.where("
      )
    end
  end

  it "includes B4umSearch in the controller" do
    Dir.mktmpdir("b4um_search_generator_test") do |directory|
      FileUtils.mkdir_p(File.join(directory, "app/models"))
      FileUtils.mkdir_p(File.join(directory, "app/controllers"))
      FileUtils.mkdir_p(File.join(directory, "app/views/products"))

      File.write(
        File.join(directory, "app/models/product.rb"),
        "class Product < ApplicationRecord\nend\n"
      )

      File.write(
        File.join(directory, "app/controllers/products_controller.rb"),
        <<~RUBY
          class ProductsController < ApplicationController
            def index
              @products = Product.all
            end
          end
        RUBY
      )

      File.write(
        File.join(directory, "app/views/products/index.html.erb"),
        "<h1>Products</h1>\n"
      )

      generator = described_class.new(
        ["Product"],
        {},
        destination_root: directory
      )

      generator.invoke_all

      controller = File.read(
        File.join(
          directory,
          "app/controllers/products_controller.rb"
        )
      )

      expect(controller).to include(
        "include B4umSearch"
      )
    end
  end

  it "adds search to a plain index action" do
    Dir.mktmpdir("b4um_search_generator_test") do |directory|
      FileUtils.mkdir_p(File.join(directory, "app/models"))
      FileUtils.mkdir_p(File.join(directory, "app/controllers"))
      FileUtils.mkdir_p(File.join(directory, "app/views/products"))

      File.write(
        File.join(directory, "app/models/product.rb"),
        "class Product < ApplicationRecord\nend\n"
      )

      File.write(
        File.join(directory, "app/controllers/products_controller.rb"),
        <<~RUBY
          class ProductsController < ApplicationController
            def index
              @products = Product.all
            end
          end
        RUBY
      )

      File.write(
        File.join(directory, "app/views/products/index.html.erb"),
        "<h1>Products</h1>\n"
      )

      generator = described_class.new(
        ["Product"],
        {},
        destination_root: directory
      )

      generator.invoke_all

      controller = File.read(
        File.join(
          directory,
          "app/controllers/products_controller.rb"
        )
      )

      expect(controller).to include(
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
    end
  end

  it "preserves sortable ordering when adding search" do
    Dir.mktmpdir("b4um_search_generator_test") do |directory|
      FileUtils.mkdir_p(
        File.join(directory, "app/models")
      )

      FileUtils.mkdir_p(
        File.join(directory, "app/controllers")
      )

      FileUtils.mkdir_p(
        File.join(directory, "app/views/products")
      )

      File.write(
        File.join(directory, "app/models/product.rb"),
        <<~RUBY
          class Product < ApplicationRecord
          end
        RUBY
      )

      controller_path = File.join(
        directory,
        "app/controllers/products_controller.rb"
      )

      File.write(
        controller_path,
        <<~RUBY
          class ProductsController < ApplicationController
            def index
              @products = Product.order(:position, :id)
            end
          end
        RUBY
      )

      File.write(
        File.join(directory, "app/views/products/index.html.erb"),
        <<~ERB
          <h1>Products</h1>

          <%= render "bento", products: @products %>
        ERB
      )

      generator = described_class.new(
        ["Product"],
        {},
        destination_root: directory
      )

      generator.invoke_all

      controller = File.read(controller_path)

      expect(controller).to include(
        <<~RUBY
          class ProductsController < ApplicationController
            include B4umSearch

            def index
              @products = b4um_search(
                Product.order(:position, :id),
                params[:q]
              )
            end
          end
        RUBY
      )

      expect(controller).not_to include(
        "Product.all,"
      )
    end
  end

  it "adds search before existing pagination" do
    Dir.mktmpdir("b4um_search_generator_test") do |directory|
      FileUtils.mkdir_p(File.join(directory, "app/models"))
      FileUtils.mkdir_p(File.join(directory, "app/controllers"))
      FileUtils.mkdir_p(File.join(directory, "app/views/products"))

      File.write(
        File.join(directory, "app/models/product.rb"),
        "class Product < ApplicationRecord\nend\n"
      )

      File.write(
        File.join(directory, "app/controllers/products_controller.rb"),
        <<~RUBY
          class ProductsController < ApplicationController
            include B4umPagination

            def index
              @products, @pagination = b4um_paginate(
                Product.all,
                per_page: 20
              )
            end
          end
        RUBY
      )

      File.write(
        File.join(directory, "app/views/products/index.html.erb"),
        "<h1>Products</h1>\n"
      )

      generator = described_class.new(
        ["Product"],
        {},
        destination_root: directory
      )

      generator.invoke_all

      controller = File.read(
        File.join(
          directory,
          "app/controllers/products_controller.rb"
        )
      )

      expect(controller).to match(
        /@products,\s*@pagination\s*=\s*b4um_paginate\(\s*
          b4um_search\(Product\.all,\s*params\[:q\]\),\s*
          per_page:\s*20\s*
        \)/x
      )
    end
  end

  it "is safe to run multiple times" do
    Dir.mktmpdir("b4um_search_generator_test") do |directory|
      FileUtils.mkdir_p(File.join(directory, "app/models"))
      FileUtils.mkdir_p(File.join(directory, "app/controllers"))
      FileUtils.mkdir_p(File.join(directory, "app/views/products"))

      File.write(
        File.join(directory, "app/models/product.rb"),
        "class Product < ApplicationRecord\nend\n"
      )

      File.write(
        File.join(directory, "app/controllers/products_controller.rb"),
        <<~RUBY
          class ProductsController < ApplicationController
            def index
              @products = Product.all
            end
          end
        RUBY
      )

      File.write(
        File.join(directory, "app/views/products/index.html.erb"),
        "<h1>Products</h1>\n"
      )

      2.times do
        generator = described_class.new(
          ["Product"],
          {},
          destination_root: directory
        )

        generator.invoke_all
      end

      controller = File.read(
        File.join(
          directory,
          "app/controllers/products_controller.rb"
        )
      )

      expect(
        controller.scan("include B4umSearch").count
      ).to eq(1)

      expect(
        controller.scan("b4um_search(").count
      ).to eq(1)

      view = File.read(
        File.join(
          directory,
          "app/views/products/index.html.erb"
        )
      )

      expect(
        view.scan('class="b4um-search"').count
      ).to eq(1)

      expect(
        view.scan("<% if params[:q].present? %>").count
      ).to be <= 1
    end
  end

  it "adds a search form to the index view" do
    Dir.mktmpdir("b4um_search_generator_test") do |directory|
      FileUtils.mkdir_p(File.join(directory, "app/models"))
      FileUtils.mkdir_p(File.join(directory, "app/controllers"))
      FileUtils.mkdir_p(File.join(directory, "app/views/products"))

      File.write(
        File.join(directory, "app/models/product.rb"),
        "class Product < ApplicationRecord\nend\n"
      )

      File.write(
        File.join(directory, "app/controllers/products_controller.rb"),
        <<~RUBY
          class ProductsController < ApplicationController
            def index
              @products = Product.all
            end
          end
        RUBY
      )

      File.write(
        File.join(directory, "app/views/products/index.html.erb"),
        "<h1>Products</h1>\n"
      )

      generator = described_class.new(
        ["Product"],
        {},
        destination_root: directory
      )

      generator.invoke_all

      view = File.read(
        File.join(
          directory,
          "app/views/products/index.html.erb"
        )
      )

      expect(view).to include(
        'class="b4um-search"'
      )

      expect(view).to include(
        "form.search_field :q"
      )

      expect(view).to include(
        "value: params[:q]"
      )

      expect(view).to include(
        'class: "form-input"'
      )

      expect(view).to include(
        'class: "form-label"'
      )
    end
  end

  it "updates the scaffold empty state for search results" do
    Dir.mktmpdir("b4um_search_generator_test") do |directory|
      FileUtils.mkdir_p(File.join(directory, "app/models"))
      FileUtils.mkdir_p(File.join(directory, "app/controllers"))
      FileUtils.mkdir_p(File.join(directory, "app/views/products"))

      File.write(
        File.join(directory, "app/models/product.rb"),
        "class Product < ApplicationRecord\nend\n"
      )

      File.write(
        File.join(directory, "app/controllers/products_controller.rb"),
        <<~RUBY
          class ProductsController < ApplicationController
            def index
              @products = Product.all
            end
          end
        RUBY
      )

      File.write(
        File.join(directory, "app/views/products/index.html.erb"),
        <<~ERB
          <% if @products.any? %>
            <%= render "bento", products: @products %>
          <% else %>
            <section class="b4um-empty-state">
              <h2 class="b4um-empty-state__title">
                No products yet.
              </h2>

              <p class="b4um-empty-state__text">
                Create your first product to get started.
              </p>
            </section>
          <% end %>
        ERB
      )

      generator = described_class.new(
        ["Product"],
        {},
        destination_root: directory
      )

      generator.invoke_all

      view = File.read(
        File.join(
          directory,
          "app/views/products/index.html.erb"
        )
      )

      expect(view).to include(
        "<% if params[:q].present? %>"
      )

      expect(view).to include(
        "No products found."
      )

      expect(view).to include(
        "Try a different search term."
      )

      expect(view).to include(
        "No products yet."
      )

      expect(view).to include(
        "Create your first product to get started."
      )
    end
  end

  it "does not duplicate the search empty state when run twice" do
    Dir.mktmpdir("b4um_search_generator_test") do |directory|
      FileUtils.mkdir_p(File.join(directory, "app/models"))
      FileUtils.mkdir_p(File.join(directory, "app/controllers"))
      FileUtils.mkdir_p(File.join(directory, "app/views/products"))

      File.write(
        File.join(directory, "app/models/product.rb"),
        "class Product < ApplicationRecord\nend\n"
      )

      File.write(
        File.join(directory, "app/controllers/products_controller.rb"),
        <<~RUBY
          class ProductsController < ApplicationController
            def index
              @products = Product.all
            end
          end
        RUBY
      )

      File.write(
        File.join(directory, "app/views/products/index.html.erb"),
        <<~ERB
          <% if @products.any? %>
            <%= render "bento", products: @products %>
          <% else %>
            <section class="b4um-empty-state">
              <h2 class="b4um-empty-state__title">
                No products yet.
              </h2>

              <p class="b4um-empty-state__text">
                Create your first product to get started.
              </p>
            </section>
          <% end %>
        ERB
      )

      2.times do
        generator = described_class.new(
          ["Product"],
          {},
          destination_root: directory
        )

        generator.invoke_all
      end

      view = File.read(
        File.join(
          directory,
          "app/views/products/index.html.erb"
        )
      )

      expect(
        view.scan("<% if params[:q].present? %>").count
      ).to eq(1)

      expect(
        view.scan("No products found.").count
      ).to eq(1)

      expect(
        view.scan("Try a different search term.").count
      ).to eq(1)

      expect(
        view.scan("No products yet.").count
      ).to eq(1)
    end
  end

  it "raises an error when the index collection cannot be found" do
    Dir.mktmpdir("b4um_search_generator_test") do |directory|
      FileUtils.mkdir_p(File.join(directory, "app/models"))
      FileUtils.mkdir_p(File.join(directory, "app/controllers"))
      FileUtils.mkdir_p(File.join(directory, "app/views/products"))

      File.write(
        File.join(directory, "app/models/product.rb"),
        "class Product < ApplicationRecord\nend\n"
      )

      File.write(
        File.join(directory, "app/controllers/products_controller.rb"),
        <<~RUBY
          class ProductsController < ApplicationController
            def index
              @products = Product.order(:name)
            end
          end
        RUBY
      )

      File.write(
        File.join(directory, "app/views/products/index.html.erb"),
        "<h1>Products</h1>\n"
      )

      generator = described_class.new(
        ["Product"],
        {},
        destination_root: directory
      )

      expect do
        generator.invoke_all
      end.to raise_error(
        Thor::Error,
        "Could not find the index collection in app/controllers/products_controller.rb"
      )
    end
  end
end
