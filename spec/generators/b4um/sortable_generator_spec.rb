# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"
require "generators/b4um/sortable/sortable_generator"

RSpec.describe B4um::Generators::SortableGenerator do
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
      File.join(@destination_root, "db/migrate")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "config")
    )

    File.write(
      File.join(@destination_root, "config/routes.rb"),
      <<~RUBY
        Rails.application.routes.draw do
          resources :products
        end
      RUBY
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
      "<div class=\"b4um-bento\"></div>\n"
    )
  end

  after do
    FileUtils.remove_entry(@destination_root)
  end

  it "loads the B4UM sortable generator" do
    expect(described_class).to be < Rails::Generators::NamedBase
  end

  it "creates a position migration" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    migrations = Dir.glob(
      File.join(
        @destination_root,
        "db/migrate/*_add_position_to_products.rb"
      )
    )

    expect(migrations.size).to eq(1)

    content = File.read(migrations.first)

    expect(content).to include(
      "add_column :products, :position, :integer"
    )

    expect(content).to include(
      "change_column_null :products, :position, false"
    )
  end

  it "adds sortable position handling to the model" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    model_path = File.join(
      @destination_root,
      "app/models/product.rb"
    )

    content = File.read(model_path)

    expect(content).to include(
      "before_create :b4um_set_sortable_position"
    )

    expect(content).to include(
      "def b4um_set_sortable_position"
    )

    expect(content).to include(
      "self.position = self.class.maximum(:position).to_i + 1"
    )

    expect(content).to include(
      "after_destroy :b4um_compact_sortable_positions"
    )

    expect(content).to include(
      "def b4um_compact_sortable_positions"
    )

    expect(content).to include(
      '.where("position > ?", position)'
    )

    expect(content).to include(
      '.update_all("position = position - 1")'
    )
  end

  it "does not duplicate sortable position handling" do
    first_generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    first_generator.invoke_all

    second_generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    second_generator.invoke_all

    model = File.read(
      File.join(
        @destination_root,
        "app/models/product.rb"
      )
    )

    expect(
      model.scan("after_destroy :b4um_compact_sortable_positions").size
    ).to eq(1)

    expect(
      model.scan("before_create :b4um_set_sortable_position").size
    ).to eq(1)

    expect(
      model.scan("def b4um_set_sortable_position").size
    ).to eq(1)
  end

  it "does not create another position migration when one already exists" do
    existing_migration = File.join(
      @destination_root,
      "db/migrate/20261009000000_add_position_to_products.rb"
    )

    File.write(
      existing_migration,
      <<~RUBY
        class AddPositionToProducts < ActiveRecord::Migration[8.0]
          def change
            add_column :products, :position, :integer
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

    migrations = Dir.glob(
      File.join(
        @destination_root,
        "db/migrate/*_add_position_to_products.rb"
      )
    )

    expect(migrations.size).to eq(1)
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

  it "adds sortable ordering and the sort action to the controller" do
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

    expect(controller).to include(
      "@products = Product.order(:position, :id)"
    )

    expect(controller).to include(
      "def sort"
    )

    expect(controller).to include(
      "record = Product.find_by(id: params[:id])"
    )

    expect(controller).to include(
      "target_position = params[:position].to_i"
    )

    expect(controller).to include(
      "maximum_position = Product.count"
    )

    expect(controller).to include(
      "target_position.between?(1, maximum_position)"
    )

    expect(controller).to include(
      "if target_position == record.position"
    )

    expect(controller).to include(
      "old_position = record.position"
    )

    expect(controller).to include(
      "Product.transaction do"
    )

    expect(controller).to include(
      ".where(position: target_position...old_position)"
    )

    expect(controller).to include(
      '.update_all("position = position + 1")'
    )

    expect(controller).to include(
      ".where(position: (old_position + 1)..target_position)"
    )

    expect(controller).to include(
      '.update_all("position = position - 1")'
    )

    expect(controller).to include(
      "position: target_position"
    )

    expect(controller).to include(
      "head :unprocessable_content"
    )

    expect(controller).to include(
      "head :no_content"
    )
  end

  it "does not duplicate sortable controller handling" do
    first_generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    first_generator.invoke_all

    second_generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    second_generator.invoke_all

    controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/products_controller.rb"
      )
    )

    expect(
      controller.scan("def sort").size
    ).to eq(1)

    expect(
      controller.scan(
        "@products = Product.order(:position, :id)"
      ).size
    ).to eq(1)
  end

  it "adds the sortable collection route" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    routes = File.read(
      File.join(@destination_root, "config/routes.rb")
    )

    expect(routes).to include(
      "resources :products do"
    )

    expect(routes).to include(
      "patch :sort, on: :collection"
    )

    expect(routes.scan("patch :sort, on: :collection").size).to eq(1)
  end

  it "does not duplicate the sortable collection route" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    second_generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    second_generator.invoke_all

    routes = File.read(
      File.join(@destination_root, "config/routes.rb")
    )

    expect(routes.scan("patch :sort, on: :collection").size).to eq(1)
    expect(routes.scan("resources :products do").size).to eq(1)
  end

  it "preserves an existing resources block when adding the sortable route" do
    routes_path = File.join(
      @destination_root,
      "config/routes.rb"
    )

    File.write(
      routes_path,
      <<~RUBY
        Rails.application.routes.draw do
          resources :products do
            member do
              get :edit_name
            end
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

    routes = File.read(routes_path)

    expect(routes).to include(
      "resources :products do"
    )

    expect(routes).to include(
      "patch :sort, on: :collection"
    )

    expect(routes).to include(
      "member do"
    )

    expect(routes).to include(
      "get :edit_name"
    )

    expect(routes.scan("patch :sort, on: :collection").size).to eq(1)
    expect(routes.scan("get :edit_name").size).to eq(1)
  end

  it "creates a separate sortable path using the existing controller" do
    generator = described_class.new(
      ["Product"],
      { path: "sortierung" },
      destination_root: @destination_root
    )

    generator.invoke_all

    routes = File.read(
      File.join(@destination_root, "config/routes.rb")
    )

    expect(routes).to include(
      'get "sortierung", to: "products#sort"'
    )

    expect(routes).to include(
      'patch "sortierung", to: "products#sort"'
    )

    expect(routes).to include(
      "resources :products"
    )

    expect(routes).not_to include(
      "namespace :sortierung"
    )

    expect(routes).not_to include(
      "patch :sort, on: :collection"
    )
  end

  it "keeps the sort action correctly indented for a separate path" do
    generator = described_class.new(
      ["Product"],
      { path: "sortierung" },
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/products_controller.rb"
      )
    )

    expect(controller).to include(
      <<~RUBY.indent(2)
        def sort
          if request.get?
            @products = Product.order(:position, :id)
            return
          end

          record = Product.find_by(id: params[:id])
          target_position = params[:position].to_i
      RUBY
    )
  end

  it "creates a named update route for a separate sortable path" do
    generator = described_class.new(
      ["Product"],
      { path: "sortierung" },
      destination_root: @destination_root
    )

    generator.invoke_all

    routes = File.read(
      File.join(
        @destination_root,
        "config/routes.rb"
      )
    )

    expect(routes).to include(
      'patch "sortierung", to: "products#sort", as: :sort_products'
    )
  end

  it "adds separate page support after sortable was previously installed without a path" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    generator_with_path = described_class.new(
      ["Product"],
      { path: "sortierung" },
      destination_root: @destination_root
    )

    generator_with_path.invoke_all

    controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/products_controller.rb"
      )
    )

    expect(controller).to include(
      <<~RUBY.indent(2)
        def sort
          if request.get?
            @products = Product.order(:position, :id)
            return
          end
      RUBY
    )

    routes = File.read(
      File.join(
        @destination_root,
        "config/routes.rb"
      )
    )

    expect(routes).to include(
      'get "sortierung", to: "products#sort"'
    )

    expect(routes).to include(
      'patch "sortierung", to: "products#sort", as: :sort_products'
    )

    expect(routes).not_to include(
      "patch :sort, on: :collection"
    )

    index = File.read(
      File.join(
        @destination_root,
        "app/views/products/index.html.erb"
      )
    )

    expect(index).to include(
      'render "bento"'
    )

    expect(index).not_to include(
      'render "sortable"'
    )
  end

  it "restores the table layout when moving sortable to a separate path" do
    index_path = File.join(
      @destination_root,
      "app/views/products/index.html.erb"
    )

    File.write(
      index_path,
      <<~ERB
        <h1>Products</h1>

        <%= render "table", products: @products %>
      ERB
    )

    FileUtils.rm(
      File.join(
        @destination_root,
        "app/views/products/_bento.html.erb"
      )
    )

    File.write(
      File.join(
        @destination_root,
        "app/views/products/_table.html.erb"
      ),
      "<table></table>\n"
    )

    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    index = File.read(index_path)

    expect(index).to include(
      'render "sortable"'
    )

    generator_with_path = described_class.new(
      ["Product"],
      { path: "sortierung" },
      destination_root: @destination_root
    )

    generator_with_path.invoke_all

    index = File.read(index_path)

    expect(index).to include(
      'render "table"'
    )

    expect(index).not_to include(
      'render "sortable"'
    )
  end

  it "keeps sortable working when rerun without a path after a separate page was installed" do
    generator_with_path = described_class.new(
      ["Product"],
      { path: "sortierung" },
      destination_root: @destination_root
    )

    generator_with_path.invoke_all

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

    expect(
      controller.scan(/^\s*def\s+sort\b/).count
    ).to eq(1)

    expect(controller).to include(
      "@products = Product.order(:position, :id)"
    )

    routes = File.read(
      File.join(
        @destination_root,
        "config/routes.rb"
      )
    )

    expect(routes).to include(
      'get "sortierung", to: "products#sort"'
    )

    expect(routes).to include(
      'patch "sortierung", to: "products#sort", as: :sort_products'
    )

    expect(routes).not_to include(
      "patch :sort, on: :collection"
    )
  end

  it "uses the named sortable update route on a separate sortable page" do
    generator = described_class.new(
      ["Product"],
      { path: "sortierung" },
      destination_root: @destination_root
    )

    generator.invoke_all

    partial = File.read(
      File.join(
        @destination_root,
        "app/views/products/_sortable.html.erb"
      )
    )

    expect(partial).to include(
      'data-sortable-update-url-value="<%= sort_products_path %>"'
    )
  end

  it "does not duplicate separate sortable routes" do
    generator = described_class.new(
      ["Product"],
      { path: "sortierung" },
      destination_root: @destination_root
    )

    generator.invoke_all
    generator.invoke_all

    routes = File.read(
      File.join(
        @destination_root,
        "config/routes.rb"
      )
    )

    expect(
      routes.scan(
        'get "sortierung", to: "products#sort"'
      ).count
    ).to eq(1)

    expect(
      routes.scan(
        'patch "sortierung", to: "products#sort", as: :sort_products'
      ).count
    ).to eq(1)
  end

  it "does not duplicate an existing separate sortable route" do
    routes_path = File.join(
      @destination_root,
      "config/routes.rb"
    )

    routes = File.read(routes_path)

    routes.sub!(
      /^end\s*$/,
      <<~RUBY
          get "sortierung", to: "products#sort"
        end
      RUBY
    )

    File.write(routes_path, routes)

    generator = described_class.new(
      ["Product"],
      { path: "sortierung" },
      destination_root: @destination_root
    )

    generator.invoke_all

    routes = File.read(routes_path)

    expect(
      routes.scan(
        'get "sortierung", to: "products#sort"'
      ).count
    ).to eq(1)

    expect(
      routes.scan(
        'patch "sortierung", to: "products#sort", as: :sort_products'
      ).count
    ).to eq(1)
  end

  it "preserves the index layout when a separate path is used" do
    generator = described_class.new(
      ["Product"],
      { path: "admin" },
      destination_root: @destination_root
    )

    generator.invoke_all

    index = File.read(
      File.join(
        @destination_root,
        "app/views/products/index.html.erb"
      )
    )

    expect(index).to include(
      '<%= render "bento", products: @products %>'
    )

    expect(index).not_to include(
      'render "sortable"'
    )
  end

  it "creates a separate sortable view when a path is used" do
    generator = described_class.new(
      ["Product"],
      { path: "sortierung" },
      destination_root: @destination_root
    )

    generator.invoke_all

    sort_view_path = File.join(
      @destination_root,
      "app/views/products/sort.html.erb"
    )

    expect(File).to exist(sort_view_path)

    sort_view = File.read(sort_view_path)

    expect(sort_view).to include(
      '<%= render "sortable", products: @products %>'
    )
  end

  it "loads the sortable collection for a separate sortable page" do
    generator = described_class.new(
      ["Product"],
      { path: "sortierung" },
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/products_controller.rb"
      )
    )

    expect(controller).to include(
      <<~RUBY.indent(2)
        def sort
          if request.get?
            @products = Product.order(:position, :id)
            return
          end
      RUBY
    )
  end

  it "switches the index layout to sortable" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    index = File.read(
      File.join(
        @destination_root,
        "app/views/products/index.html.erb"
      )
    )

    expect(index).to include(
      'render "sortable"'
    )

    expect(index).not_to include(
      'render "bento"'
    )
  end

  it "creates the sortable partial" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    partial_path = File.join(
      @destination_root,
      "app/views/products/_sortable.html.erb"
    )

    expect(File).to exist(partial_path)

    partial = File.read(partial_path)

    expect(partial).to include(
      'data-controller="sortable"'
    )

    expect(partial).to include(
      'data-sortable-update-url-value="<%= sort_products_path %>"'
    )

    expect(partial).to include(
      'data-sortable-id="<%= product.id %>"'
    )

    expect(partial).to include(
      'class="b4um-sortable__position"'
    )

    expect(partial).not_to include(
      'max="<%= products.size %>"'
    )

    expect(partial).to include(
      'class="b4um-sortable__handle"'
    )

    expect(partial).to include(
      "render product,"
    )

    expect(partial).to include(
      "dragover->sortable#dragOver"
    )

    expect(partial).to include(
      "drop->sortable#drop"
    )

    expect(partial).to include(
      "change->sortable#positionChanged"
    )

    expect(partial).to include(
      "keydown->sortable#positionKeydown"
    )

    expect(partial).to include(
      'draggable="true"'
    )

    expect(partial).to include(
      "dragstart->sortable#dragStart"
    )

    expect(partial).to include(
      "dragend->sortable#dragEnd"
    )
  end

  it "creates the sortable Stimulus controller" do
    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      @destination_root,
      "app/javascript/controllers/sortable_controller.js"
    )

    expect(File).to exist(controller_path)

    controller = File.read(controller_path)

    expect(controller).to include(
      "import { Controller } from '@hotwired/stimulus'"
    )

    expect(controller).to include(
      "updateUrl: String"
    )

    expect(controller).to include(
      "dragStart(event)"
    )

    expect(controller).to include(
      "dragOver(event)"
    )

    expect(controller).to include(
      "positionChanged(event)"
    )

    expect(controller).to include(
      "positionFor(item)"
    )

    expect(controller).to include(
      "positionAfterDrop(item)"
    )

    expect(controller).to include(
      "async persist(id, position)"
    )

    expect(controller).to include(
      "method: 'PATCH'"
    )

    expect(controller).to include(
      "body: JSON.stringify({"
    )

    expect(controller).to include(
      "id,"
    )

    expect(controller).to include(
      "position"
    )

    expect(controller).not_to include(
      "const maximum = items.length"
    )

    expect(controller).not_to include(
      "body: JSON.stringify({ ids })"
    )

    expect(controller).to include(
      "'X-CSRF-Token': this.csrfToken()"
    )

    expect(controller).to include(
      "window.location.reload()"
    )
  end

  it "preserves an existing paginated collection" do
    controller_path = File.join(
      @destination_root,
      "app/controllers/products_controller.rb"
    )

    File.write(
      controller_path,
      <<~RUBY
        class ProductsController < ApplicationController
          include B4umPagination

          def index
            @products, @pagination = b4um_paginate(
              Product.all,
              per_page: 12
            )
          end

          private
        end
      RUBY
    )

    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(controller_path)

    expect(controller).to include(
      "@products, @pagination = b4um_paginate("
    )

    expect(controller).to include(
      "Product.order(:position, :id),"
    )

    expect(controller).to include(
      "per_page: 12"
    )

    expect(controller).to include(
      "def sort"
    )
  end

  it "preserves an existing searched collection" do
    controller_path = File.join(
      @destination_root,
      "app/controllers/products_controller.rb"
    )

    File.write(
      controller_path,
      <<~RUBY
        class ProductsController < ApplicationController
          include B4umSearch

          def index
            @products = b4um_search(
              Product.all,
              params[:q]
            )
          end

          private
        end
      RUBY
    )

    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(controller_path)

    expect(controller).to include(
      "@products = b4um_search("
    )

    expect(controller).to include(
      "Product.order(:position, :id),"
    )

    expect(controller).to include(
      "params[:q]"
    )

    expect(controller).to include(
      "def sort"
    )
  end

  it "preserves an existing searched and paginated collection" do
    controller_path = File.join(
      @destination_root,
      "app/controllers/products_controller.rb"
    )

    File.write(
      controller_path,
      <<~RUBY
        class ProductsController < ApplicationController
          include B4umSearch
          include B4umPagination

          def index
            @products, @pagination = b4um_paginate(
              b4um_search(
                Product.all,
                params[:q]
              ),
              per_page: 12
            )
          end

          private
        end
      RUBY
    )

    generator = described_class.new(
      ["Product"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(controller_path)

    expect(controller).to include(
      "@products, @pagination = b4um_paginate("
    )

    expect(controller).to include(
      "b4um_search("
    )

    expect(controller).to include(
      "Product.order(:position, :id),"
    )

    expect(controller).to include(
      "params[:q]"
    )

    expect(controller).to include(
      "per_page: 12"
    )

    expect(controller).to include(
      "def sort"
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
end
