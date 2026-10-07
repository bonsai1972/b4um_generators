# frozen_string_literal: true

require "fileutils"
require "spec_helper"
require "rails/generators"
require_relative "../../../lib/generators/b4um/authentication/authentication_generator"

RSpec.describe B4um::Generators::AuthenticationGenerator do
  before do
    @destination_root = File.expand_path(
      "../../tmp/authentication_generator",
      __dir__
    )

    FileUtils.rm_rf(@destination_root)
    FileUtils.mkdir_p(@destination_root)

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/controllers")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/views/shared")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "config")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "db/migrate")
    )

    File.write(
      File.join(@destination_root, "Gemfile"),
      <<~RUBY
        source "https://rubygems.org"

        gem "bcrypt", "~> 3.1"
    RUBY
    )

    File.write(
      File.join(@destination_root, "app/models/user.rb"),
      <<~RUBY
        class User < ApplicationRecord
          has_secure_password
        end
    RUBY
    )

    File.write(
      File.join(
        @destination_root,
        "db/migrate/20260101000000_create_users.rb"
      ),
      <<~RUBY
        class CreateUsers < ActiveRecord::Migration[8.0]
          def change
            create_table :users do |t|
              t.string :email
              t.string :password_digest

              t.timestamps
            end
          end
        end
      RUBY
    )

    File.write(
      File.join(@destination_root, "config/routes.rb"),
      <<~RUBY
        Rails.application.routes.draw do
        end
    RUBY
    )
    File.write(
      File.join(
        @destination_root,
        "app/controllers/application_controller.rb"
      ),
      <<~RUBY
        class ApplicationController < ActionController::Base
          allow_browser versions: :modern

          stale_when_importmap_changes
        end
      RUBY
    )

    File.write(
      File.join(
        @destination_root,
        "app/views/shared/_navigation.html.erb"
      ),
      <<~ERB
        <nav
          class="navigation"
          aria-label="Main navigation"
          data-controller="navigation"
        >
          <div class="navigation__inner">
            <%= link_to "b4um", "/", class: "navigation__brand" %>

            <div
              class="navigation__menu"
              id="navigation-menu"
              data-navigation-target="menu"
            >
              <%# B4UM_NAVIGATION_LINKS %>
            </div>
          </div>
        </nav>
      ERB
    )
  end

  it "loads the B4UM authentication generator" do
    expect(described_class).to be < Rails::Generators::Base
  end

  it "generates session authentication" do
    generator = described_class.new(
      ["User"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/sessions_controller.rb"
      )
    )

    expect(controller).to include(
      "class SessionsController < ApplicationController"
    )

    expect(controller).to include(
      "User.find_by(email: params[:email])"
    )

    expect(controller).to include(
      "user&.authenticate(params[:password])"
    )

    expect(controller).to include(
      "session[:user_id] = user.id"
    )

    expect(controller).to include(
      "session.delete(:user_id)"
    )

    login_view = File.read(
      File.join(
        @destination_root,
        "app/views/sessions/new.html.erb"
      )
    )

    expect(login_view).to include(
      "form_with url: login_path"
    )

    expect(login_view).to include(
      "form.email_field :email"
    )

    expect(login_view).to include(
      "form.password_field :password"
    )

    expect(login_view).to include(
      'class: "form-input"'
    )

    expect(login_view).to include(
      'class: "form-submit"'
    )

    routes = File.read(
      File.join(@destination_root, "config/routes.rb")
    )

    expect(routes).to include(
      'get "login", to: "sessions#new", as: :login'
    )

    expect(routes).to include(
      'post "login", to: "sessions#create"'
    )

    expect(routes).to include(
      'delete "logout", to: "sessions#destroy", as: :logout'
    )
  end

  it "adds authentication helpers to ApplicationController" do
    generator = described_class.new(
      ["User"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/application_controller.rb"
      )
    )

    expect(controller).to include(
      "helper_method :current_user, :logged_in?"
    )

    expect(controller).to include(
      "def current_user"
    )

    expect(controller).to include(
      "@current_user ||= User.find_by(id: session[:user_id])"
    )

    expect(controller).to include(
      "def logged_in?"
    )

    expect(controller).to include(
      "current_user.present?"
    )

    expect(controller).to include(
      "def require_login"
    )

    expect(controller).to include(
      "return if logged_in?"
    )

    expect(controller).to include(
      'redirect_to login_path, alert: "Please log in first."'
    )

    expect(controller).to include(
      "allow_browser versions: :modern"
    )

    expect(controller).to include(
      "stale_when_importmap_changes"
    )
  end

  it "updates an existing in-place helper to require login" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/helpers")
    )

    File.write(
      File.join(
        @destination_root,
        "app/helpers/b4um_in_place_helper.rb"
      ),
      <<~RUBY
        # frozen_string_literal: true

        module B4umInPlaceHelper
          def b4um_in_place_editing_allowed?
            true
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
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

  it "protects an existing in-place controller" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/controllers")
    )

    File.write(
      File.join(
        @destination_root,
        "app/controllers/products_controller.rb"
      ),
      <<~RUBY
        class ProductsController < ApplicationController
          IN_PLACE_FIELDS = %w[
            name
          ].freeze

          before_action :set_product, only: %i[ show edit edit_name update destroy ]

          def show
          end

          def edit_name
          end

          def update
          end

          private

          def set_product
            @product = Product.find(params.expect(:id))
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
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

  it "does not duplicate in-place authentication integration when run twice" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/helpers")
    )

    File.write(
      File.join(
        @destination_root,
        "app/helpers/b4um_in_place_helper.rb"
      ),
      <<~RUBY
        # frozen_string_literal: true

        module B4umInPlaceHelper
          def b4um_in_place_editing_allowed?
            true
          end
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
          IN_PLACE_FIELDS = %w[
            name
          ].freeze

          before_action :set_product, only: %i[ show edit edit_name update destroy ]

          def show
          end

          def edit_name
          end

          def update
          end

          private

          def set_product
            @product = Product.find(params.expect(:id))
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all
    generator.invoke_all

    helper = File.read(
      File.join(
        @destination_root,
        "app/helpers/b4um_in_place_helper.rb"
      )
    )

    controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/products_controller.rb"
      )
    )

    expect(
      helper.scan(
        "def b4um_in_place_editing_allowed?\n    logged_in?"
      ).count
    ).to eq(1)

    expect(
      controller.scan(
        "before_action :require_login, except: [:index, :show]"
      ).count
    ).to eq(1)
  end

  it "does not duplicate authentication setup when run twice" do
    generator = described_class.new(
      ["User"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all
    generator.invoke_all

    controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/application_controller.rb"
      )
    )

    routes = File.read(
      File.join(@destination_root, "config/routes.rb")
    )

    navigation = File.read(
      File.join(
        @destination_root,
        "app/views/shared/_navigation.html.erb"
      )
    )

    expect(
      controller.scan(
        "helper_method :current_user, :logged_in?"
      ).count
    ).to eq(1)

    expect(
      controller.scan("def current_user").count
    ).to eq(1)

    expect(
      controller.scan("def logged_in?").count
    ).to eq(1)

    expect(
      controller.scan("def require_login").count
    ).to eq(1)

    expect(
      routes.scan(
        'get "login", to: "sessions#new", as: :login'
      ).count
    ).to eq(1)

    expect(
      routes.scan(
        'post "login", to: "sessions#create"'
      ).count
    ).to eq(1)

    expect(
      routes.scan(
        'delete "logout", to: "sessions#destroy", as: :logout'
      ).count
    ).to eq(1)

    expect(
      navigation.scan(
        'navigation_button_to "Logout", logout_path, method: :delete'
      ).count
    ).to eq(1)

    expect(
      navigation.scan(
        'navigation_link_to "Login",'
      ).count
    ).to eq(1)

    expect(
      navigation.scan(
        "<%# B4UM_NAVIGATION_LINKS %>"
      ).count
    ).to eq(1)
  end

  it "adds login and logout to the B4UM navigation" do
    generator = described_class.new(
      ["User"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    navigation = File.read(
      File.join(
        @destination_root,
        "app/views/shared/_navigation.html.erb"
      )
    )

    expect(navigation).to include(
      "<% if logged_in? %>"
    )

    expect(navigation).to include(
      'navigation_button_to "Logout", logout_path, method: :delete'
    )

    expect(navigation).to include(
      'navigation_link_to "Login",'
    )

    expect(navigation).to include(
      "login_path,"
    )

    expect(navigation).to include(
      "controller: :sessions,"
    )

    expect(navigation).to include(
      "action: :new"
    )

    expect(navigation).to include(
      "<% else %>"
    )

    expect(navigation).to include(
      "<% end %>"
    )

    expect(navigation).to include(
      "<%# B4UM_NAVIGATION_LINKS %>"
    )
  end

  it "uses the requested authentication model" do
    File.write(
      File.join(@destination_root, "app/models/admin.rb"),
      <<~RUBY
        class Admin < ApplicationRecord
          has_secure_password
        end
      RUBY
    )

    File.write(
      File.join(
        @destination_root,
        "db/migrate/20260101000001_create_admins.rb"
      ),
      <<~RUBY
        class CreateAdmins < ActiveRecord::Migration[8.0]
          def change
            create_table :admins do |t|
              t.string :email
              t.string :password_digest

              t.timestamps
            end
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["Admin"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    sessions_controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/sessions_controller.rb"
      )
    )

    application_controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/application_controller.rb"
      )
    )

    expect(sessions_controller).to include(
      "Admin.find_by(email: params[:email])"
    )

    expect(sessions_controller).to include(
      "session[:admin_id] = admin.id"
    )

    expect(application_controller).to include(
      "helper_method :current_admin, :logged_in?"
    )

    expect(application_controller).to include(
      "def current_admin"
    )

    expect(application_controller).to include(
      "@current_admin ||= Admin.find_by(id: session[:admin_id])"
    )

    expect(application_controller).to include(
      "current_admin.present?"
    )
  end

  it "raises a helpful error when the authentication model does not exist" do
    generator = described_class.new(
      ["Member"],
      {},
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      /Authentication model Member was not found/
    )
  end

  it "raises a helpful error when the authentication model does not use has_secure_password" do
    File.write(
      File.join(@destination_root, "app/models/member.rb"),
      <<~RUBY
        class Member < ApplicationRecord
        end
      RUBY
    )

    generator = described_class.new(
      ["Member"],
      {},
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      /Authentication model Member must use has_secure_password/
    )
  end

  it "raises a helpful error when password_digest is missing" do
    File.write(
      File.join(@destination_root, "app/models/member.rb"),
      <<~RUBY
        class Member < ApplicationRecord
          has_secure_password
        end
      RUBY
    )

    generator = described_class.new(
      ["Member"],
      {},
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      /Authentication model Member requires a password_digest column/
    )
  end

  it "recognizes password_digest from schema.rb" do
    File.write(
      File.join(@destination_root, "app/models/member.rb"),
      <<~RUBY
        class Member < ApplicationRecord
          has_secure_password
        end
      RUBY
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "db")
    )

    File.write(
      File.join(@destination_root, "db/schema.rb"),
      <<~RUBY
        ActiveRecord::Schema[8.0].define(version: 2026_01_01_000000) do
          create_table "members", force: :cascade do |t|
            t.string "email"
            t.string "password_digest"
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["Member"],
      {},
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.not_to raise_error
  end

  it "raises a helpful error when bcrypt is missing" do
    File.write(
      File.join(@destination_root, "Gemfile"),
      <<~RUBY
        source "https://rubygems.org"
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      /bcrypt is required for authentication/
    )
  end

  it "protects selected controllers while keeping index and show public" do
    products_controller_path = File.join(
      @destination_root,
      "app/controllers/products_controller.rb"
    )

    articles_controller_path = File.join(
      @destination_root,
      "app/controllers/articles_controller.rb"
    )

    FileUtils.mkdir_p(File.dirname(products_controller_path))

    File.write(
      products_controller_path,
      <<~RUBY
        class ProductsController < ApplicationController
          def index
          end

          def show
          end

          def new
          end
        end
      RUBY
    )

    File.write(
      articles_controller_path,
      <<~RUBY
        class ArticlesController < ApplicationController
          def index
          end

          def show
          end

          def edit
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      { protect: "Products,Articles" },
      destination_root: @destination_root
    )

    generator.invoke_all

    products_controller = File.read(products_controller_path)
    articles_controller = File.read(articles_controller_path)

    expect(products_controller).to include(
      "before_action :require_login, except: [:index, :show]"
    )

    expect(articles_controller).to include(
      "before_action :require_login, except: [:index, :show]"
    )
  end

  it "hides protected show actions from logged-out visitors" do
    products_controller_path = File.join(
      @destination_root,
      "app/controllers/products_controller.rb"
    )

    show_path = File.join(
      @destination_root,
      "app/views/products/show.html.erb"
    )

    FileUtils.mkdir_p(
      File.dirname(products_controller_path)
    )

    FileUtils.mkdir_p(
      File.dirname(show_path)
    )

    File.write(
      products_controller_path,
      <<~RUBY
        class ProductsController < ApplicationController
          def index
          end

          def show
          end

          def edit
          end
        end
      RUBY
    )

    File.write(
      show_path,
      <<~ERB
        <div class="b4um-card__actions">
          <%= link_to "Edit",
                      edit_product_path(@product),
                      class: "button button--secondary" %>

          <%= link_to "Back",
                      products_path,
                      class: "button button--secondary" %>

          <%= button_to "Destroy",
                        @product,
                        method: :delete,
                        class: "button button--danger" %>
        </div>
      ERB
    )

    generator = described_class.new(
      ["User"],
      { protect: "Products" },
      destination_root: @destination_root
    )

    generator.invoke_all

    show = File.read(show_path)

    expect(show).to match(
      /^  <% if logged_in\? %>\n    <%= link_to "Edit",/
    )

    expect(show).to match(
      /^  <% if logged_in\? %>\n    <%= button_to "Destroy",/
    )

    expect(show).to include('link_to "Back"')
  end

  it "can protect another controller on a later run without duplicating authentication setup" do
    products_controller_path = File.join(
      @destination_root,
      "app/controllers/products_controller.rb"
    )

    comments_controller_path = File.join(
      @destination_root,
      "app/controllers/comments_controller.rb"
    )

    FileUtils.mkdir_p(File.dirname(products_controller_path))

    File.write(
      products_controller_path,
      <<~RUBY
        class ProductsController < ApplicationController
          def index
          end

          def show
          end
        end
      RUBY
    )

    File.write(
      comments_controller_path,
      <<~RUBY
        class CommentsController < ApplicationController
          def create
          end

          def destroy
          end
        end
      RUBY
    )

    first_generator = described_class.new(
      ["User"],
      { protect: "Products" },
      destination_root: @destination_root
    )

    first_generator.invoke_all

    second_generator = described_class.new(
      ["User"],
      { protect: "Comments" },
      destination_root: @destination_root
    )

    second_generator.invoke_all

    application_controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/application_controller.rb"
      )
    )

    routes = File.read(
      File.join(@destination_root, "config/routes.rb")
    )

    navigation = File.read(
      File.join(
        @destination_root,
        "app/views/shared/_navigation.html.erb"
      )
    )

    products_controller = File.read(products_controller_path)
    comments_controller = File.read(comments_controller_path)

    expect(application_controller.scan(
      "helper_method :current_user, :logged_in?"
    ).length).to eq(1)

    expect(routes.scan(
      'get "login", to: "sessions#new", as: :login'
    ).length).to eq(1)

    expect(navigation.scan(
      'navigation_button_to "Logout", logout_path, method: :delete'
    ).length).to eq(1)

    expect(products_controller.scan(
      "before_action :require_login, except: [:index, :show]"
    ).length).to eq(1)

    expect(comments_controller.scan(
      "before_action :require_login, except: [:index, :show]"
    ).length).to eq(1)
  end

  it "hides the protected new action from logged-out visitors" do
    products_controller_path = File.join(
      @destination_root,
      "app/controllers/products_controller.rb"
    )

    index_path = File.join(
      @destination_root,
      "app/views/products/index.html.erb"
    )

    FileUtils.mkdir_p(
      File.dirname(products_controller_path)
    )

    FileUtils.mkdir_p(
      File.dirname(index_path)
    )

    File.write(
      products_controller_path,
      <<~RUBY
        class ProductsController < ApplicationController
          def index
          end

          def show
          end

          def new
          end
        end
      RUBY
    )

    File.write(
      index_path,
      <<~ERB
        <div class="page-header">
          <h1>Products</h1>

          <%= link_to "New product",
                      new_product_path,
                      class: "button button--primary" %>
        </div>
      ERB
    )

    generator = described_class.new(
      ["User"],
      { protect: "Products" },
      destination_root: @destination_root
    )

    generator.invoke_all

    index = File.read(index_path)

    expect(index).to match(
      /^  <% if logged_in\? %>\n    <%= link_to "New product",/
    )
  end

  it "does not duplicate protected view actions when run twice" do
    products_controller_path = File.join(
      @destination_root,
      "app/controllers/products_controller.rb"
    )

    index_path = File.join(
      @destination_root,
      "app/views/products/index.html.erb"
    )

    show_path = File.join(
      @destination_root,
      "app/views/products/show.html.erb"
    )

    FileUtils.mkdir_p(File.dirname(products_controller_path))
    FileUtils.mkdir_p(File.dirname(index_path))

    File.write(
      products_controller_path,
      <<~RUBY
        class ProductsController < ApplicationController
          def index
          end

          def show
          end

          def new
          end

          def edit
          end
        end
      RUBY
    )

    File.write(
      index_path,
      <<~ERB
        <div class="page-header">
          <%= link_to "New product",
                      new_product_path,
                      class: "button button--primary" %>
        </div>
      ERB
    )

    File.write(
      show_path,
      <<~ERB
        <div class="b4um-card__actions">
          <%= link_to "Edit",
                      edit_product_path(@product),
                      class: "button button--secondary" %>

          <%= button_to "Destroy",
                        @product,
                        method: :delete,
                        class: "button button--danger" %>
        </div>
      ERB
    )

    2.times do
      generator = described_class.new(
        ["User"],
        { protect: "Products" },
        destination_root: @destination_root
      )

      generator.invoke_all
    end

    index = File.read(index_path)
    show = File.read(show_path)

    expect(index.scan("<% if logged_in? %>").length).to eq(1)
    expect(index.scan('link_to "New product"').length).to eq(1)

    expect(show.scan("<% if logged_in? %>").length).to eq(2)
    expect(show.scan('link_to "Edit"').length).to eq(1)
    expect(show.scan('button_to "Destroy"').length).to eq(1)
  end

  it "does not accept commented bcrypt" do
    File.write(
      File.join(@destination_root, "Gemfile"),
      <<~RUBY
        source "https://rubygems.org"

        # gem "bcrypt", "~> 3.1"
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      /bcrypt is required for authentication/
    )
  end

  it "raises a helpful error before changing files when a protected controller does not exist" do
    sessions_controller_path = File.join(
      @destination_root,
      "app/controllers/sessions_controller.rb"
    )

    login_view_path = File.join(
      @destination_root,
      "app/views/sessions/new.html.erb"
    )

    application_controller_path = File.join(
      @destination_root,
      "app/controllers/application_controller.rb"
    )

    routes_path = File.join(
      @destination_root,
      "config/routes.rb"
    )

    application_controller_before = File.read(application_controller_path)
    routes_before = File.read(routes_path)

    generator = described_class.new(
      ["User"],
      { protect: "Products" },
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      /Protected controller ProductsController was not found/
    )

    expect(File).not_to exist(sessions_controller_path)
    expect(File).not_to exist(login_view_path)

    expect(
      File.read(application_controller_path)
    ).to eq(application_controller_before)

    expect(
      File.read(routes_path)
    ).to eq(routes_before)
  end

  it "turns the authentication resource into a private profile" do
    users_controller_path = File.join(
      @destination_root,
      "app/controllers/users_controller.rb"
    )

    File.write(
      users_controller_path,
      <<~RUBY
        class UsersController < ApplicationController
          before_action :set_user, only: %i[ show edit update destroy ]

          def index
            @users = User.all
          end

          def show
          end

          def new
            @user = User.new
          end

          def edit
          end

          def create
          end

          def update
          end

          def destroy
          end

          private

          def set_user
            @user = User.find(params.expect(:id))
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(users_controller_path)

    expect(controller).to include(
      "before_action :require_login, except: %i[ new create ]"
    )

    expect(controller).to include(
      "before_action :require_current_user, only: %i[ show edit update destroy ]"
    )

    expect(controller).to include(
      "def require_current_user"
    )

    expect(controller).to include(
      "return if @user == current_user"
    )

    expect(controller).to include(
      'redirect_to root_path, alert: "Access denied."'
    )
  end

  it "replaces the authentication resource navigation with Profile" do
    navigation_path = File.join(
      @destination_root,
      "app/views/shared/_navigation.html.erb"
    )

    File.write(
      navigation_path,
      <<~ERB
        <nav>
          <div class="navigation__menu">
            <%= navigation_link_to "Users",
                                   users_path,
                                   controller: :users %>

            <%# B4UM_NAVIGATION_LINKS %>
          </div>
        </nav>
      ERB
    )

    users_controller_path = File.join(
      @destination_root,
      "app/controllers/users_controller.rb"
    )

    File.write(
      users_controller_path,
      <<~RUBY
        class UsersController < ApplicationController
          before_action :set_user, only: %i[ show edit update destroy ]

          private

          def set_user
            @user = User.find(params.expect(:id))
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    navigation = File.read(navigation_path)

    expect(navigation).not_to include(
      'navigation_link_to "Users"'
    )

    expect(navigation).to include(
      'navigation_link_to "Profile"'
    )

    expect(navigation).to include(
      "current_user"
    )

    expect(navigation).to include(
      "controller: :users"
    )

    expect(navigation).to include(
      "action: :show"
    )
  end

  it "does not duplicate profile protection when authentication is run twice" do
    users_controller_path = File.join(
      @destination_root,
      "app/controllers/users_controller.rb"
    )

    File.write(
      users_controller_path,
      <<~RUBY
        class UsersController < ApplicationController
          before_action :set_user, only: %i[ show edit update destroy ]

          def index
          end

          def show
          end

          def new
          end

          def create
          end

          private

          def set_user
            @user = User.find(params.expect(:id))
          end
        end
      RUBY
    )

    2.times do
      generator = described_class.new(
        ["User"],
        {},
        destination_root: @destination_root
      )

      generator.invoke_all
    end

    controller = File.read(users_controller_path)

    expect(
      controller.scan(
        "before_action :require_login, except: %i[ new create ]"
      ).length
    ).to eq(1)

    expect(
      controller.scan(
        "before_action :require_current_user, only: %i[ show edit update destroy ]"
      ).length
    ).to eq(1)

    expect(
      controller.scan("def require_current_user").length
    ).to eq(1)
  end

  it "prevents normal users from accessing the authentication resource index" do
    users_controller_path = File.join(
      @destination_root,
      "app/controllers/users_controller.rb"
    )

    File.write(
      users_controller_path,
      <<~RUBY
        class UsersController < ApplicationController
          before_action :set_user, only: %i[ show edit update destroy ]

          def index
            @users = User.all
          end

          def show
          end

          def new
          end

          def create
          end

          private

          def set_user
            @user = User.find(params.expect(:id))
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(users_controller_path)

    expect(controller).to include(
      "before_action :prevent_authentication_index, only: :index"
    )

    expect(controller).to include(
      "def prevent_authentication_index"
    )

    expect(controller).to include(
      "redirect_to current_user"
    )
  end

  it "clears the authentication session when the current user is destroyed" do
    users_controller_path = File.join(
      @destination_root,
      "app/controllers/users_controller.rb"
    )

    File.write(
      users_controller_path,
      <<~RUBY
        class UsersController < ApplicationController
          before_action :set_user, only: %i[ show edit update destroy ]

          def index
          end

          def show
          end

          def new
          end

          def create
          end

          def destroy
            @user.destroy!

            redirect_to root_path
          end

          private

          def set_user
            @user = User.find(params.expect(:id))
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(users_controller_path)

    expect(controller).to include(
      "session.delete(:user_id)"
    )
  end

  it "adds profile authorization methods outside a real B4UM scaffold destroy action" do
    users_controller_path = File.join(
      @destination_root,
      "app/controllers/users_controller.rb"
    )

    File.write(
      users_controller_path,
      <<~RUBY
        class UsersController < ApplicationController
          before_action :set_user, only: %i[ show edit update destroy ]

          # GET /users or /users.json
          def index
            @users = User.all
          end

          # GET /users/1 or /users/1.json
          def show
          end

          # GET /users/new
          def new
            @user = User.new
          end

          # GET /users/1/edit
          def edit
          end

          # POST /users or /users.json
          def create
            @user = User.new(user_params)

            respond_to do |format|
              if @user.save
                format.html { redirect_to @user, notice: "User was successfully created." }
                format.json { render :show, status: :created, location: @user }
              else
                format.html { render :new, status: :unprocessable_content }
                format.json { render json: @user.errors, status: :unprocessable_content }
              end
            end
          end

          # PATCH/PUT /users/1 or /users/1.json
          def update
            respond_to do |format|
              if @user.update(user_params)
                format.html { redirect_to @user, notice: "User was successfully updated.", status: :see_other }
                format.json { render :show, status: :ok, location: @user }
              else
                format.html { render :edit, status: :unprocessable_content }
                format.json { render json: @user.errors, status: :unprocessable_content }
              end
            end
          end

          # DELETE /users/1 or /users/1.json
          def destroy
            @user.destroy!

            respond_to do |format|
              format.html do
          flash[:deleted] = "User was successfully destroyed."
          redirect_to users_path, status: :see_other
        end
              format.json { head :no_content }
            end
          end

          private
            # Use callbacks to share common setup or constraints between actions.
            def set_user
              @user = User.find(params.expect(:id))
            end

            # Only allow a list of trusted parameters through.
            def user_params
              params.expect(user: [ :name, :email, :password, :password_confirmation ])
            end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(users_controller_path)

    expect(controller).to include(
      "def prevent_authentication_index"
    )

    expect(controller).to include(
      "def require_current_user"
    )

    expect(controller).to include(
      "def clear_authentication_session"
    )

    expect(controller.scan(
      "def prevent_authentication_index"
    ).length).to eq(1)

    expect(controller.scan(
      "def require_current_user"
    ).length).to eq(1)

    expect(controller.scan(
      "def clear_authentication_session"
    ).length).to eq(1)

    expect(controller).to match(
      /
        private
        .*def\ set_user
        .*def\ user_params
        .*def\ prevent_authentication_index
        .*def\ require_current_user
        .*def\ clear_authentication_session
      /mx
    )

    destroy_section = controller[
      /def destroy.*?\n\s*private/m
    ]

    expect(destroy_section).not_to include(
      "def prevent_authentication_index"
    )

    expect(destroy_section).not_to include(
      "def require_current_user"
    )

    expect(destroy_section).not_to include(
      "def clear_authentication_session"
    )
  end

  it "signs in the authentication user after registration" do
    users_controller_path = File.join(
      @destination_root,
      "app/controllers/users_controller.rb"
    )

    File.write(
      users_controller_path,
      <<~RUBY
        class UsersController < ApplicationController
          def create
            @user = User.new(user_params)

            respond_to do |format|
              if @user.save
                format.html { redirect_to @user, notice: "User was successfully created." }
                format.json { render :show, status: :created, location: @user }
              else
                format.html { render :new, status: :unprocessable_content }
                format.json { render json: @user.errors, status: :unprocessable_content }
              end
            end
          end

          private

          def user_params
            params.expect(user: [ :email, :password, :password_confirmation ])
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(users_controller_path)

    expect(controller).to include(
      "session[:user_id] = @user.id"
    )

    expect(controller.index(
             "session[:user_id] = @user.id"
           )).to be < controller.index(
             'format.html { redirect_to @user, notice: "User was successfully created." }'
           )
  end

  it "adds Register to the logged-out navigation" do
    users_controller_path = File.join(
      @destination_root,
      "app/controllers/users_controller.rb"
    )

    File.write(
      users_controller_path,
      <<~RUBY
        class UsersController < ApplicationController
          def new
            @user = User.new
          end

          def create
            @user = User.new
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    navigation = File.read(
      File.join(
        @destination_root,
        "app/views/shared/_navigation.html.erb"
      )
    )

    expect(navigation).to include(
      'navigation_link_to "Register",'
    )

    expect(navigation).to include(
      "new_user_path,"
    )

    expect(navigation).to include(
      "controller: :users,"
    )

    expect(navigation).to include(
      "action: :new"
    )

    register_position = navigation.index(
      'navigation_link_to "Register",'
    )

    login_position = navigation.index(
      'navigation_link_to "Login",'
    )

    expect(register_position).to be < login_position
  end

  it "adds Register when authentication navigation already exists" do
    users_controller_path = File.join(
      @destination_root,
      "app/controllers/users_controller.rb"
    )

    File.write(
      users_controller_path,
      <<~RUBY
        class UsersController < ApplicationController
          def new
            @user = User.new
          end

          def create
            @user = User.new
          end
        end
      RUBY
    )

    navigation_path = File.join(
      @destination_root,
      "app/views/shared/_navigation.html.erb"
    )

    File.write(
      navigation_path,
      <<~ERB
        <nav>
          <div class="navigation__menu">
            <% if logged_in? %>
              <%= navigation_link_to "Profile",
                                     current_user,
                                     controller: :users,
                                     action: :show %>
              <%= navigation_button_to "Logout", logout_path, method: :delete %>
            <% else %>
              <%= navigation_link_to "Login",
                                     login_path,
                                     controller: :sessions,
                                     action: :new %>
            <% end %>

            <%# B4UM_NAVIGATION_LINKS %>
          </div>
        </nav>
      ERB
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    navigation = File.read(navigation_path)

    expect(navigation).to include(
      'navigation_link_to "Register",'
    )

    expect(navigation).to include(
      "new_user_path,"
    )

    expect(
      navigation.scan(
        'navigation_link_to "Login",'
      ).length
    ).to eq(1)

    expect(
      navigation.scan(
        'navigation_button_to "Logout", logout_path, method: :delete'
      ).length
    ).to eq(1)

    expect(
      navigation.scan(
        'navigation_link_to "Profile",'
      ).length
    ).to eq(1)

    expect(
      navigation.scan(
        'navigation_link_to "Register",'
      ).length
    ).to eq(1)
  end

  it "redirects to root after destroying the authentication user" do
    users_controller_path = File.join(
      @destination_root,
      "app/controllers/users_controller.rb"
    )

    File.write(
      users_controller_path,
      <<~RUBY
        class UsersController < ApplicationController
          before_action :set_user, only: %i[ show edit update destroy ]

          def destroy
            @user.destroy!

            respond_to do |format|
              format.html do
                flash[:deleted] = "User was successfully destroyed."
                redirect_to users_path, status: :see_other
              end

              format.json { head :no_content }
            end
          end

          private

          def set_user
            @user = User.find(params.expect(:id))
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(users_controller_path)

    expect(controller).to include(
      'flash[:deleted] = "User was successfully destroyed."'
    )

    expect(controller).to include(
      "redirect_to root_path, status: :see_other"
    )

    expect(controller).not_to include(
      "redirect_to users_path, status: :see_other"
    )
  end
end
