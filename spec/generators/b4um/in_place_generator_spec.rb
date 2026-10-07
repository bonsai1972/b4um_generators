# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "generators/b4um/in_place/in_place_generator"

RSpec.describe B4um::Generators::InPlaceGenerator do
  around do |example|
    Dir.mktmpdir("b4um_in_place_test") do |directory|
      @destination_root = directory
      example.run
    end
  end

  def create_basic_product_app
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/controllers")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "config")
    )

    File.write(
      File.join(@destination_root, "app/models/product.rb"),
      <<~RUBY
        class Product < ApplicationRecord
        end
      RUBY
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
      File.join(
        @destination_root,
        "app/controllers/products_controller.rb"
      ),
      <<~RUBY
        class ProductsController < ApplicationController
          before_action :set_product, only: %i[ show edit update destroy ]

          def show
          end

          def edit
          end

          def create
          end

          def update
            respond_to do |format|
              if @product.update(product_params)
                format.html { redirect_to @product, notice: "Product was successfully updated.", status: :see_other }
              else
                format.html { render :edit, status: :unprocessable_content }
              end
            end
          end

          def destroy
          end

          private

          def set_product
            @product = Product.find(params.expect(:id))
          end

          def product_params
            params.expect(product: [ :name ])
          end
        end
      RUBY
    )
  end

  it "loads the b4um in-place generator" do
    expect(described_class).to be < Rails::Generators::NamedBase
  end

  it "generates in-place editing for a string field" do
    create_basic_product_app

    column = Struct.new(:name, :type).new(
      "name",
      :string
    )

    product_class = double(
      "Product",
      columns: [column],
      reflect_on_all_associations: [],
      reflect_on_all_attachments: []
    )

    stub_const("Product", product_class)

    generator = described_class.new(
      %w[Product name],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    expect(
      File
    ).to exist(
      File.join(
        @destination_root,
        "app/assets/stylesheets/b4um/in_place.css"
      )
    )

    expect(
      File
    ).to exist(
      File.join(
        @destination_root,
        "app/views/products/edit_name.html.erb"
      )
    )

    expect(
      File
    ).to exist(
      File.join(
        @destination_root,
        "app/views/products/_name.html.erb"
      )
    )

    controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/products_controller.rb"
      )
    )

    routes = File.read(
      File.join(
        @destination_root,
        "config/routes.rb"
      )
    )

    edit_view = File.read(
      File.join(
        @destination_root,
        "app/views/products/edit_name.html.erb"
      )
    )

    display_view = File.read(
      File.join(
        @destination_root,
        "app/views/products/_name.html.erb"
      )
    )

    stimulus_controller = File.read(
      File.join(
        @destination_root,
        "app/javascript/controllers/in_place_controller.js"
      )
    )

    expect(controller).to include(
      "def edit_name"
    )

    expect(controller).to include(
      "edit_name update"
    )

    expect(controller).to include(
      ":name"
    )

    expect(routes).to include(
      "get :edit_name"
    )

    expect(display_view).to include(
      "keydown.enter->in-place#edit"
    )

    expect(display_view).to include(
      "keydown.space->in-place#edit"
    )

    expect(edit_view).to include(
      "data-in-place-cancel-url-value"
    )

    expect(stimulus_controller).to include(
      "event.key !== 'Escape'"
    )

    expect(stimulus_controller).to include(
      "event.preventDefault()"
    )

    expect(stimulus_controller).to include(
      "this.focusEditor()"
    )

    expect(stimulus_controller).to include(
      'input:not([type="hidden"]):not([type="file"])'
    )
  end

  it "adds multiple regular fields to strong parameters" do
    create_basic_product_app

    columns = [
      Struct.new(:name, :type).new("name", :string),
      Struct.new(:name, :type).new("condition", :string),
      Struct.new(:name, :type).new("featured", :boolean)
    ]

    product_class = double(
      "Product",
      columns: columns,
      reflect_on_all_associations: [],
      reflect_on_all_attachments: []
    )

    stub_const("Product", product_class)

    generator = described_class.new(
      %w[Product condition featured],
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

    expect(controller).to include(":condition")
    expect(controller).to include(":featured")

    expect(
      controller.scan(":condition").count
    ).to eq(1)

    expect(
      controller.scan(":featured").count
    ).to eq(1)
  end

  it "generates radio and boolean editors" do
    create_basic_product_app

    columns = [
      Struct.new(:name, :type).new("condition", :string),
      Struct.new(:name, :type).new("featured", :boolean)
    ]

    product_class = double(
      "Product",
      columns: columns,
      reflect_on_all_associations: [],
      reflect_on_all_attachments: []
    )

    stub_const("Product", product_class)

    generator = described_class.new(
      %w[Product condition featured],
      {
        radio: "condition:new=Neu,used=Gebraucht,refurbished=Generalüberholt"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    condition_editor = File.read(
      File.join(
        @destination_root,
        "app/views/products/edit_condition.html.erb"
      )
    )

    featured_editor = File.read(
      File.join(
        @destination_root,
        "app/views/products/edit_featured.html.erb"
      )
    )

    expect(condition_editor).to include("radio_button")
    expect(condition_editor).to include("Neu")
    expect(condition_editor).to include("Gebraucht")
    expect(condition_editor).to include("Generalüberholt")

    expect(featured_editor).to include("check_box")
    expect(featured_editor).to include(
      "change->in-place#save"
    )
  end

  it "rejects a radio configuration for a field that is not being generated" do
    create_basic_product_app

    columns = [
      Struct.new(:name, :type).new("name", :string),
      Struct.new(:name, :type).new("condition", :string)
    ]

    product_class = double(
      "Product",
      columns: columns,
      reflect_on_all_associations: [],
      reflect_on_all_attachments: []
    )

    stub_const("Product", product_class)

    generator = described_class.new(
      %w[Product name],
      {
        radio: "condition:new=Neu,used=Gebraucht"
      },
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      "--radio field condition must be one of the generated fields: name"
    )
  end

  it "rejects a radio configuration without values" do
    create_basic_product_app

    columns = [
      Struct.new(:name, :type).new("condition", :string)
    ]

    product_class = double(
      "Product",
      columns: columns,
      reflect_on_all_associations: [],
      reflect_on_all_attachments: []
    )

    stub_const("Product", product_class)

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

  it "rejects an invalid select configuration" do
    create_basic_product_app

    columns = [
      Struct.new(:name, :type).new("status", :string)
    ]

    product_class = double(
      "Product",
      columns: columns,
      reflect_on_all_associations: [],
      reflect_on_all_attachments: []
    )

    stub_const("Product", product_class)

    generator = described_class.new(
      %w[Product status],
      {
        select: "status"
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

  it "rejects a select configuration without values" do
    create_basic_product_app

    columns = [
      Struct.new(:name, :type).new("status", :string)
    ]

    product_class = double(
      "Product",
      columns: columns,
      reflect_on_all_associations: [],
      reflect_on_all_attachments: []
    )

    stub_const("Product", product_class)

    generator = described_class.new(
      %w[Product status],
      {
        select: "status:,,"
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

  it "generates a select editor" do
    create_basic_product_app

    column = Struct.new(:name, :type).new(
      "status",
      :string
    )

    product_class = double(
      "Product",
      columns: [column],
      reflect_on_all_associations: [],
      reflect_on_all_attachments: []
    )

    stub_const("Product", product_class)

    generator = described_class.new(
      %w[Product status],
      {
        select: "status:Active=Aktiv,Inactive=Inaktiv"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    editor = File.read(
      File.join(
        @destination_root,
        "app/views/products/edit_status.html.erb"
      )
    )

    display = File.read(
      File.join(
        @destination_root,
        "app/views/products/_status.html.erb"
      )
    )

    expect(editor).to include("form.select")
    expect(editor).to include("Aktiv")
    expect(editor).to include("Inaktiv")
    expect(editor).to include(
      "change->in-place#save"
    )

    expect(display).to include("Active")
    expect(display).to include("Aktiv")
    expect(display).to include("Inactive")
    expect(display).to include("Inaktiv")
  end

  it "rejects a select configuration for a field that is not being generated" do
    create_basic_product_app

    columns = [
      Struct.new(:name, :type).new("name", :string),
      Struct.new(:name, :type).new("status", :string)
    ]

    product_class = double(
      "Product",
      columns: columns,
      reflect_on_all_associations: [],
      reflect_on_all_attachments: []
    )

    stub_const("Product", product_class)

    generator = described_class.new(
      %w[Product name],
      {
        select: "status:Active=Aktiv,Inactive=Inaktiv"
      },
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      "--select field status must be one of the generated fields: name"
    )
  end

  it "rejects select and radio for the same field" do
    create_basic_product_app

    columns = [
      Struct.new(:name, :type).new("status", :string)
    ]

    product_class = double(
      "Product",
      columns: columns,
      reflect_on_all_associations: [],
      reflect_on_all_attachments: []
    )

    stub_const("Product", product_class)

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

  it "generates a rich text editor and display" do
    create_basic_product_app

    association = Struct.new(:name).new(
      :rich_text_description
    )

    product_class = double(
      "Product",
      columns: [],
      reflect_on_all_associations: [association],
      reflect_on_all_attachments: []
    )

    stub_const("Product", product_class)

    generator = described_class.new(
      %w[Product description],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    editor = File.read(
      File.join(
        @destination_root,
        "app/views/products/edit_description.html.erb"
      )
    )

    display = File.read(
      File.join(
        @destination_root,
        "app/views/products/_description.html.erb"
      )
    )

    expect(editor).to include(
      "form.rich_text_area"
    )

    expect(display).to include(
      'data-controller="image-lightbox rich-text"'
    )

    expect(display).to include(
      "in-place-rich-text__action"
    )

    expect(display).to include(
      "in-place-edit-button"
    )

    expect(display).to include(
      "image-lightbox__thumbnails"
    )

    expect(display).to include(
      "image-lightbox__caption"
    )
  end

  it "generates single and multiple attachment editing" do
    create_basic_product_app

    reflection = Struct.new(:name, :macro)

    attachments = [
      reflection.new(:image, :has_one_attached),
      reflection.new(:gallery, :has_many_attached)
    ]

    product_class = double(
      "Product",
      columns: [],
      reflect_on_all_associations: [],
      reflect_on_all_attachments: attachments
    )

    stub_const("Product", product_class)

    generator = described_class.new(
      %w[Product image gallery],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    image_editor = File.read(
      File.join(
        @destination_root,
        "app/views/products/edit_image.html.erb"
      )
    )

    gallery_editor = File.read(
      File.join(
        @destination_root,
        "app/views/products/edit_gallery.html.erb"
      )
    )

    controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/products_controller.rb"
      )
    )

    expect(image_editor).to include(
      "in-place-image-editor"
    )

    expect(image_editor).to include(
      "remove_image"
    )

    expect(gallery_editor).to include(
      "remove_gallery_ids"
    )

    expect(gallery_editor).to include(
      "multiple: true"
    )

    expect(controller).to include(
      ":image"
    )

    expect(controller).to include(
      ":remove_image"
    )

    expect(controller).to include(
      "gallery: []"
    )

    expect(controller).to include(
      "remove_gallery_ids: []"
    )

    expect(controller).to include(
      '@product.image.purge if remove_image == "1"'
    )

    expect(controller).to include(
      "@product.gallery.attach(new_gallery)"
    )

    expect(controller).to include(
      "@product.gallery.reload"
    )
  end

  it "does not duplicate generated in-place integration" do
    create_basic_product_app

    column = Struct.new(:name, :type).new(
      "name",
      :string
    )

    product_class = double(
      "Product",
      columns: [column],
      reflect_on_all_associations: [],
      reflect_on_all_attachments: []
    )

    stub_const("Product", product_class)

    2.times do
      generator = described_class.new(
        %w[Product name],
        {},
        destination_root: @destination_root
      )

      generator.invoke_all
    end

    controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/products_controller.rb"
      )
    )

    routes = File.read(
      File.join(
        @destination_root,
        "config/routes.rb"
      )
    )

    expect(
      controller.scan("def edit_name").count
    ).to eq(1)

    expect(
      controller.scan("name\n  ].freeze").count
    ).to eq(1)

    expect(
      controller.scan(
        "IN_PLACE_FIELDS.include?(params[:in_place_field])"
      ).count
    ).to eq(2)

    expect(
      controller.scan(
        'flash.now[:notice] = "Product was successfully updated."'
      ).count
    ).to eq(1)

    expect(
      controller.scan(
        "turbo_stream.update("
      ).count
    ).to eq(1)

    expect(
      controller.scan(
        '"flash-messages"'
      ).count
    ).to eq(1)

    expect(
      controller.scan(
        'partial: "shared/flash"'
      ).count
    ).to eq(1)

    expect(controller).to include(
      "helpers.dom_id("
    )

    expect(controller).to include(
      "params[:in_place_field]"
    )

    expect(controller).not_to include(
      "params[:in_place_frame]"
    )

    expect(
      routes.scan("get :edit_name").count
    ).to eq(1)
  end

  it "uses logged_in? when authentication is already installed" do
    create_basic_product_app

    File.write(
      File.join(
        @destination_root,
        "app/controllers/application_controller.rb"
      ),
      <<~RUBY
        class ApplicationController < ActionController::Base
          helper_method :current_user, :logged_in?

          private

          def current_user
            @current_user ||= User.find_by(id: session[:user_id])
          end

          def logged_in?
            current_user.present?
          end
        end
      RUBY
    )

    column = Struct.new(:name, :type).new(
      "name",
      :string
    )

    product_class = double(
      "Product",
      columns: [column],
      reflect_on_all_associations: [],
      reflect_on_all_attachments: []
    )

    stub_const("Product", product_class)

    generator = described_class.new(
      %w[Product name],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    helper = File.read(
      File.join(
        @destination_root,
        "app/helpers/b4um_in_place_helper.rb"
      )
    )

    expect(helper).to include(
      "def b4um_in_place_editing_allowed?\n    logged_in?"
    )

    expect(helper).not_to include(
      "def b4um_in_place_editing_allowed?\n    true"
    )
  end

  it "protects in-place actions when authentication is installed" do
    create_basic_product_app

    File.write(
      File.join(
        @destination_root,
        "app/controllers/application_controller.rb"
      ),
      <<~RUBY
        class ApplicationController < ActionController::Base
          helper_method :current_user, :logged_in?

          private

          def current_user
            @current_user ||= User.find_by(id: session[:user_id])
          end

          def logged_in?
            current_user.present?
          end

          def require_login
            return if logged_in?

            redirect_to login_path, alert: "Please log in first."
          end
        end
      RUBY
    )

    column = Struct.new(:name, :type).new(
      "name",
      :string
    )

    product_class = double(
      "Product",
      columns: [column],
      reflect_on_all_associations: [],
      reflect_on_all_attachments: []
    )

    stub_const("Product", product_class)

    generator = described_class.new(
      %w[Product name],
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
      "before_action :require_login, except: [:index, :show]"
    )
  end

  it "adds attachment update integration on a later generator run" do
    create_basic_product_app

    reflection = Struct.new(:name, :macro)

    product_class = double(
      "Product",
      columns: [],
      reflect_on_all_associations: [],
      reflect_on_all_attachments: [
        reflection.new(:image, :has_one_attached),
        reflection.new(:gallery, :has_many_attached)
      ]
    )

    stub_const("Product", product_class)

    generator = described_class.new(
      %w[Product image],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    generator = described_class.new(
      %w[Product gallery],
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
      'remove_image = update_params.delete("remove_image")'
    )

    expect(controller).to include(
      'new_gallery = update_params.delete("gallery")'
    )

    expect(controller).to include(
      'remove_gallery_ids = update_params.delete("remove_gallery_ids")'
    )

    expect(controller).to include(
      "@product.image.purge if remove_image == \"1\""
    )

    expect(controller).to include(
      "@product.gallery.attach(new_gallery)"
    )

    expect(controller).to include(
      "@product.gallery.reload"
    )
  end

  it "does not duplicate attachment integration when run twice" do
    create_basic_product_app

    reflection = Struct.new(:name, :macro)

    product_class = double(
      "Product",
      columns: [],
      reflect_on_all_associations: [],
      reflect_on_all_attachments: [
        reflection.new(:gallery, :has_many_attached)
      ]
    )

    stub_const("Product", product_class)

    2.times do
      generator = described_class.new(
        %w[Product gallery],
        {},
        destination_root: @destination_root
      )

      generator.invoke_all
    end

    controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/products_controller.rb"
      )
    )

    expect(
      controller.scan(
        'new_gallery = update_params.delete("gallery")'
      ).count
    ).to eq(1)

    expect(
      controller.scan(
        'remove_gallery_ids = update_params.delete("remove_gallery_ids")'
      ).count
    ).to eq(1)

    expect(
      controller.scan(
        "@product.gallery.attach(new_gallery)"
      ).count
    ).to eq(1)

    expect(
      controller.scan(
        "@product.gallery.reload"
      ).count
    ).to eq(1)

    expect(
      controller.scan(
        "IN_PLACE_FIELDS.include?(params[:in_place_field])"
      ).count
    ).to eq(2)
  end
end
