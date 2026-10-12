# frozen_string_literal: true

require "fileutils"
require "spec_helper"
require "rails/generators"
require_relative "../../../lib/generators/b4um/admin/admin_generator"
require_relative "../../../lib/generators/b4um/authentication/authentication_generator"

RSpec.describe B4um::Generators::AdminGenerator do
  def create_authentication_setup(destination_root)
    FileUtils.mkdir_p(
      File.join(destination_root, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(destination_root, "app/controllers")
    )

    FileUtils.mkdir_p(
      File.join(destination_root, "db/migrate")
    )

    FileUtils.mkdir_p(
      File.join(destination_root, "config")
    )

    File.write(
      File.join(destination_root, "app/models/user.rb"),
      <<~RUBY
        class User < ApplicationRecord
          has_secure_password
        end
      RUBY
    )

    File.write(
      File.join(
        destination_root,
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

    File.write(
      File.join(
        destination_root,
        "app/controllers/sessions_controller.rb"
      ),
      <<~RUBY
        class SessionsController < ApplicationController
          def new
          end

          def create
            user = User.find_by(email: params[:email])

            if user&.authenticate(params[:password])
              session[:user_id] = user.id

              redirect_to root_path, notice: "Successfully logged in."
            else
              flash.now[:alert] = "Invalid email or password."
              render :new, status: :unprocessable_content
            end
          end

          def destroy
            session.delete(:user_id)

            redirect_to root_path, notice: "Successfully logged out."
          end
        end
      RUBY
    )

    File.write(
      File.join(destination_root, "config/routes.rb"),
      <<~RUBY
        Rails.application.routes.draw do
        end
      RUBY
    )
  end

  it "loads the b4um admin generator" do
    expect(described_class).to be < Rails::Generators::Base
  end

  it "raises a helpful error when the authentication model does not exist" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      /Authentication model User was not found/
    )
  end

  it "raises a helpful error when b4um authentication is not installed" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    FileUtils.mkdir_p(
      File.join(destination_root, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(destination_root, "app/controllers")
    )

    File.write(
      File.join(destination_root, "app/models/user.rb"),
      <<~RUBY
        class User < ApplicationRecord
          has_secure_password
        end
    RUBY
    )

    File.write(
      File.join(
        destination_root,
        "app/controllers/application_controller.rb"
      ),
      <<~RUBY
        class ApplicationController < ActionController::Base
        end
    RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      /b4um authentication is not installed for User/
    )
  end

  it "fails before making changes when the authentication setup is incomplete" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    sessions_path = File.join(
      destination_root,
      "app/controllers/sessions_controller.rb"
    )

    File.write(
      sessions_path,
      <<~RUBY
        class SessionsController < ApplicationController
          def create
            user = User.find_by(email: params[:email])

            if user&.authenticate(params[:password])
              redirect_to root_path, notice: "Successfully logged in."
            else
              render :new, status: :unprocessable_content
            end
          end
        end
      RUBY
    )

    routes_path = File.join(
      destination_root,
      "config/routes.rb"
    )

    routes_before = File.read(routes_path)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      /authentication session assignment/
    )

    expect(
      Dir.glob(
        File.join(
          destination_root,
          "db/migrate/*_add_admin_fields_to_users.rb"
        )
      )
    ).to be_empty

    expect(
      File.exist?(
        File.join(
          destination_root,
          "app/controllers/admin/base_controller.rb"
        )
      )
    ).to be(false)

    expect(
      File.exist?(
        File.join(
          destination_root,
          "lib/tasks/b4um_admin.rake"
        )
      )
    ).to be(false)

    expect(File.read(routes_path)).to eq(routes_before)
  end

  it "fails before making changes when the current authentication method is incomplete" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    application_controller_path = File.join(
      destination_root,
      "app/controllers/application_controller.rb"
    )

    File.write(
      application_controller_path,
      <<~RUBY
        class ApplicationController < ActionController::Base
          helper_method :current_user, :logged_in?

          private

          def current_user
            nil
          end

          def logged_in?
            current_user.present?
          end
        end
      RUBY
    )

    routes_path = File.join(
      destination_root,
      "config/routes.rb"
    )

    routes_before = File.read(routes_path)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      /current authentication method/
    )

    expect(
      Dir.glob(
        File.join(
          destination_root,
          "db/migrate/*_add_admin_fields_to_users.rb"
        )
      )
    ).to be_empty

    expect(
      File.exist?(
        File.join(
          destination_root,
          "app/controllers/admin/base_controller.rb"
        )
      )
    ).to be(false)

    expect(
      File.exist?(
        File.join(
          destination_root,
          "lib/tasks/b4um_admin.rake"
        )
      )
    ).to be(false)

    expect(File.read(routes_path)).to eq(routes_before)
  end

  it "accepts an existing model with b4um authentication" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    expect do
      generator.invoke_all
    end.not_to raise_error
  end

  it "removes admin and blocked from public authentication model parameters" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    File.write(
      File.join(
        destination_root,
        "app/controllers/users_controller.rb"
      ),
      <<~RUBY
        class UsersController < ApplicationController
          private

          def user_params
            params.expect(
              user: [
                :name,
                :email,
                :password,
                :password_confirmation,
                :admin,
                :blocked
              ]
            )
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      destination_root,
      "app/controllers/users_controller.rb"
    )

    controller = File.read(controller_path)

    expect(controller).to include(":name")
    expect(controller).to include(":email")
    expect(controller).to include(":password")
    expect(controller).to include(":password_confirmation")

    expect(controller).not_to match(
      /:\s*admin\b/
    )

    expect(controller).not_to match(
      /:\s*blocked\b/
    )
  end

  it "removes protected admin fields regardless of parameter order" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    File.write(
      File.join(
        destination_root,
        "app/controllers/users_controller.rb"
      ),
      <<~RUBY
        class UsersController < ApplicationController
          private

          def user_params
            params.expect(
              user: [
                :admin,
                :blocked,
                :name,
                :email,
                :password,
                :password_confirmation
              ]
            )
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      destination_root,
      "app/controllers/users_controller.rb"
    )

    controller = File.read(controller_path)

    expect(controller).to include(":name")
    expect(controller).to include(":email")
    expect(controller).to include(":password")
    expect(controller).to include(":password_confirmation")

    expect(controller).not_to match(
      /:\s*admin\b/
    )

    expect(controller).not_to match(
      /:\s*blocked\b/
    )
  end

  it "preserves admin symbols outside the authentication model parameters" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    controller_path = File.join(
      destination_root,
      "app/controllers/users_controller.rb"
    )

    File.write(
      controller_path,
      <<~RUBY
        class UsersController < ApplicationController
          def example
            redirect_to root_path, alert: :admin
          end

          private

          def user_params
            params.expect(
              user: [
                :admin,
                :name,
                :email,
                :blocked
              ]
            )
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    controller = File.read(controller_path)

    expect(controller).to include(
      "redirect_to root_path, alert: :admin"
    )

    expect(controller).not_to match(
      /user:\s*\[[^\]]*:admin/m
    )

    expect(controller).not_to match(
      /user:\s*\[[^\]]*:blocked/m
    )
  end

  it "creates a migration with admin and blocked fields" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    migrations = Dir.glob(
      File.join(
        destination_root,
        "db/migrate/*_add_admin_fields_to_users.rb"
      )
    )

    expect(migrations.length).to eq(1)

    migration = File.read(migrations.first)

    expect(migration).to include(
      "add_column :users, :admin, :boolean, default: false, null: false"
    )

    expect(migration).to include(
      "add_column :users, :blocked, :boolean, default: false, null: false"
    )
  end

  it "does not create a duplicate admin fields migration" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    existing_migration = File.join(
      destination_root,
      "db/migrate/20260101000000_add_admin_fields_to_users.rb"
    )

    File.write(
      existing_migration,
      <<~RUBY
        class AddAdminFieldsToUsers < ActiveRecord::Migration[8.0]
          def change
            add_column :users, :admin, :boolean, default: false, null: false
            add_column :users, :blocked, :boolean, default: false, null: false
          end
        end
    RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    migrations = Dir.glob(
      File.join(
        destination_root,
        "db/migrate/*_add_admin_fields_to_users.rb"
      )
    )

    expect(migrations.length).to eq(1)
  end

  it "does not create an admin fields migration when the fields already exist in the schema" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    File.write(
      File.join(destination_root, "db/schema.rb"),
      <<~RUBY
        ActiveRecord::Schema[8.0].define(version: 2026_01_01_000000) do
          create_table "users", force: :cascade do |t|
            t.string "email"
            t.string "password_digest"
            t.boolean "admin", default: false, null: false
            t.boolean "blocked", default: false, null: false
          end
        end
    RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    migrations = Dir.glob(
      File.join(
        destination_root,
        "db/migrate/*_add_admin_fields_to_users.rb"
      )
    )

    expect(migrations).to be_empty
  end

  it "creates a migration only for missing admin fields" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    File.write(
      File.join(destination_root, "db/schema.rb"),
      <<~RUBY
        ActiveRecord::Schema[8.0].define(version: 2026_01_01_000000) do
          create_table "users", force: :cascade do |t|
            t.string "email"
            t.string "password_digest"
            t.boolean "admin", default: false, null: false
          end
        end
    RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    migration_path = Dir.glob(
      File.join(
        destination_root,
        "db/migrate/*_add_admin_fields_to_users.rb"
      )
    ).first

    expect(migration_path).not_to be_nil

    migration = File.read(migration_path)

    expect(migration).not_to include(
      "add_column :users, :admin"
    )

    expect(migration).to include(
      "add_column :users, :blocked, :boolean, default: false, null: false"
    )
  end

  it "adds require_admin to the application controller" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    application_controller_path = File.join(
      destination_root,
      "app/controllers/application_controller.rb"
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    controller = File.read(application_controller_path)

    expect(controller).to include("def require_admin")

    expect(controller).to include(
      "return if logged_in? && current_user.admin?"
    )

    expect(controller).to include(
      'redirect_to root_path, alert: "Access denied."'
    )
  end

  it "does not add require_admin more than once" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    application_controller_path = File.join(
      destination_root,
      "app/controllers/application_controller.rb"
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    second_generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    second_generator.invoke_all

    controller = File.read(application_controller_path)

    expect(controller.scan("def require_admin").length).to eq(1)
  end

  it "adds require_admin only once with generated authentication formatting" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    application_controller_path = File.join(
      destination_root,
      "app/controllers/application_controller.rb"
    )

    File.write(
      application_controller_path,
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

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    controller = File.read(application_controller_path)

    expect(controller.scan("def require_admin").length).to eq(1)

    syntax_check = RubyVM::InstructionSequence.compile(controller)

    expect(syntax_check).to be_a(RubyVM::InstructionSequence)
  end

  it "prevents blocked users from logging in" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    sessions_controller_path = File.join(
      destination_root,
      "app/controllers/sessions_controller.rb"
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    controller = File.read(sessions_controller_path)

    expect(controller).to include(
      "if user.blocked?"
    )

    expect(controller).to include(
      'flash.now[:alert] = "Account is blocked."'
    )

    expect(
      controller.index("if user.blocked?")
    ).to be <
         controller.index("session[:user_id] = user.id")
  end

  it "keeps blocked login handling correctly indented" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    controller = File.read(
      File.join(
        destination_root,
        "app/controllers/sessions_controller.rb"
      )
    )

    expected = [
      "      if user.blocked?",
      '        flash.now[:alert] = "Account is blocked."',
      "        render :new, status: :unprocessable_content",
      "      else",
      "        session[:user_id] = user.id",
      "",
      '        redirect_to root_path, notice: "Successfully logged in."',
      "      end"
    ].join("\n")

    expect(controller).to include(expected)
  end

  it "preserves blocked login handling when authentication is run again" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    File.write(
      File.join(destination_root, "Gemfile"),
      <<~RUBY
        source "https://rubygems.org"

        gem "bcrypt", "~> 3.1"
      RUBY
    )

    File.write(
      File.join(
        destination_root,
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

    admin_generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    admin_generator.invoke_all

    sessions_controller_path = File.join(
      destination_root,
      "app/controllers/sessions_controller.rb"
    )

    controller_before = File.read(sessions_controller_path)

    expect(controller_before).to include(
      "if user.blocked?"
    )

    authentication_generator =
      B4um::Generators::AuthenticationGenerator.new(
        ["User"],
        {},
        destination_root: destination_root
      )

    authentication_generator.invoke_all

    controller_after = File.read(sessions_controller_path)

    expect(controller_after).to include(
      "if user.blocked?"
    )

    expect(controller_after).to include(
      'flash.now[:alert] = "Account is blocked."'
    )
  end

  it "invalidates the session for blocked users" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    application_controller_path = File.join(
      destination_root,
      "app/controllers/application_controller.rb"
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    controller = File.read(application_controller_path)

    expect(controller).to include(
      "if @current_user&.blocked?"
    )

    expect(controller).to include(
      "session.delete(:user_id)"
    )

    expect(controller).to include(
      "@current_user = nil"
    )
  end

  it "does not add blocked session handling more than once" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    application_controller_path = File.join(
      destination_root,
      "app/controllers/application_controller.rb"
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    second_generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    second_generator.invoke_all

    controller = File.read(application_controller_path)

    expect(
      controller.scan("if @current_user&.blocked?").length
    ).to eq(1)

    expect(
      controller.scan("session.delete(:user_id)").length
    ).to eq(1)
  end

  it "creates a protected admin base controller" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      destination_root,
      "app/controllers/admin/base_controller.rb"
    )

    expect(File).to exist(controller_path)

    controller = File.read(controller_path)

    expect(controller).to include(
      "class Admin::BaseController < ApplicationController"
    )

    expect(controller).to include(
      "before_action :require_admin"
    )
  end

  it "adds the admin root route" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    FileUtils.mkdir_p(
      File.join(destination_root, "config")
    )

    routes_path = File.join(
      destination_root,
      "config/routes.rb"
    )

    File.write(
      routes_path,
      <<~RUBY
        Rails.application.routes.draw do
        end
    RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    routes = File.read(routes_path)

    expect(routes).to include(
      'get "admin", to: "admin/dashboard#index", as: :admin_root'
    )
  end

  it "creates the admin dashboard controller" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    FileUtils.mkdir_p(
      File.join(destination_root, "config")
    )

    File.write(
      File.join(destination_root, "config/routes.rb"),
      <<~RUBY
        Rails.application.routes.draw do
        end
    RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      destination_root,
      "app/controllers/admin/dashboard_controller.rb"
    )

    expect(File).to exist(controller_path)

    controller = File.read(controller_path)

    expect(controller).to include(
      "class Admin::DashboardController < Admin::BaseController"
    )

    expect(controller).to include(
      "def index"
    )
  end

  it "creates the admin dashboard view" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    FileUtils.mkdir_p(
      File.join(destination_root, "config")
    )

    File.write(
      File.join(destination_root, "config/routes.rb"),
      <<~RUBY
        Rails.application.routes.draw do
        end
    RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    view_path = File.join(
      destination_root,
      "app/views/admin/dashboard/index.html.erb"
    )

    expect(File).to exist(view_path)

    view = File.read(view_path)

    expect(view).to include("Admin")

    expect(view).to include(
      '<div class="b4um-grid">'
    )

    expect(view).to include(
      '<section class="b4um-card b4um-card--full">'
    )
  end

  it "adds the admin users route" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    routes = File.read(
      File.join(destination_root, "config/routes.rb")
    )

    expect(routes).to include(
      "resources :users, only: [:index, :destroy]"
    )
  end

  it "adds admin users routes when matching public users routes already exist" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    File.write(
      File.join(destination_root, "config/routes.rb"),
      <<~RUBY
        Rails.application.routes.draw do
          resources :users, only: [:index, :destroy]
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    routes_path = File.join(
      destination_root,
      "config/routes.rb"
    )

    routes = File.read(routes_path)

    expect(routes).to include(
      "resources :users, only: [:index, :destroy]"
    )

    expect(routes).to include(
      "namespace :admin do"
    )

    expect(routes).to include(
      "patch :block"
    )

    expect(routes).to include(
      "patch :unblock"
    )

    expect(routes).to include(
      "patch :grant_admin"
    )

    expect(routes).to include(
      "patch :revoke_admin"
    )
  end

  it "does not upgrade a public users route when an admin namespace already exists" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    File.write(
      File.join(destination_root, "config/routes.rb"),
      <<~RUBY
        Rails.application.routes.draw do
          resources :users, only: [:index]

          namespace :admin do
            get "reports", to: "reports#index"
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    routes = File.read(
      File.join(destination_root, "config/routes.rb")
    )

    expect(routes).to include(
      "resources :users, only: [:index]"
    )

    expect(routes).to include(
      'get "reports", to: "reports#index"'
    )

    expect(routes).to include(
      "resources :users, only: [:index, :destroy]"
    )

    expect(routes).to include("patch :block")
    expect(routes).to include("patch :unblock")
    expect(routes).to include("patch :grant_admin")
    expect(routes).to include("patch :revoke_admin")
  end

  it "upgrades an existing admin users route without adding a second admin namespace" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    File.write(
      File.join(destination_root, "config/routes.rb"),
      <<~RUBY
        Rails.application.routes.draw do
          namespace :admin do
            resources :users, only: [:index]
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    routes = File.read(
      File.join(destination_root, "config/routes.rb")
    )

    expect(routes.scan("namespace :admin do").size).to eq(1)

    expect(routes).to include(
      "resources :users, only: [:index, :destroy]"
    )

    expect(routes).to include("patch :block")
    expect(routes).to include("patch :unblock")
    expect(routes).to include("patch :grant_admin")
    expect(routes).to include("patch :revoke_admin")
  end

  it "does not add admin routes more than once" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    first_generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    first_generator.invoke_all

    second_generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    second_generator.invoke_all

    routes = File.read(
      File.join(destination_root, "config/routes.rb")
    )

    expect(
      routes.scan(
        'get "admin", to: "admin/dashboard#index", as: :admin_root'
      ).length
    ).to eq(1)

    expect(
      routes.scan("namespace :admin do").length
    ).to eq(1)

    expect(
      routes.scan(
        "resources :users, only: [:index, :destroy]"
      ).length
    ).to eq(1)

    expect(
      routes.scan("patch :block").length
    ).to eq(1)

    expect(
      routes.scan("patch :unblock").length
    ).to eq(1)

    expect(
      routes.scan("patch :grant_admin").length
    ).to eq(1)

    expect(
      routes.scan("patch :revoke_admin").length
    ).to eq(1)
  end

  it "generates correctly indented admin user routes" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    routes = File.read(
      File.join(destination_root, "config/routes.rb")
    )

    expected = <<~RUBY
      \x20\x20namespace :admin do
      \x20\x20  resources :users, only: [:index, :destroy] do
      \x20\x20    member do
      \x20\x20      patch :block
      \x20\x20      patch :unblock
      \x20\x20      patch :grant_admin
      \x20\x20      patch :revoke_admin
      \x20\x20    end
      \x20\x20  end
      \x20\x20end
    RUBY

    expect(routes).to include(expected)
  end
  it "adds admin routes before the final routes draw end" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    routes_path = File.join(
      destination_root,
      "config/routes.rb"
    )

    File.write(
      routes_path,
      <<~RUBY
        Rails.application.routes.draw do
          namespace :api do
            resources :products
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    routes = File.read(routes_path)

    api_end = routes.index(
      "  end"
    )

    admin_root = routes.index(
      'get "admin", to: "admin/dashboard#index", as: :admin_root'
    )

    final_end = routes.rindex(
      /^end$/
    )

    expect(api_end).not_to be_nil
    expect(admin_root).not_to be_nil
    expect(final_end).not_to be_nil

    expect(admin_root).to be > api_end
    expect(admin_root).to be < final_end

    expect do
      RubyVM::InstructionSequence.compile(routes)
    end.not_to raise_error
  end

  it "creates the admin users controller" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      destination_root,
      "app/controllers/admin/users_controller.rb"
    )

    expect(File).to exist(controller_path)

    controller = File.read(controller_path)

    expect(controller).to include(
      "class Admin::UsersController < Admin::BaseController"
    )

    expect(controller).to include(
      "def index"
    )

    expect(controller).to include(
      "@users = User.all"
    )
  end

  it "creates the admin users index view with dynamic safe authentication model fields" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    FileUtils.mkdir_p(
      File.join(destination_root, "db")
    )

    File.write(
      File.join(destination_root, "db/schema.rb"),
      <<~RUBY
        ActiveRecord::Schema[8.0].define(version: 2026_01_01_000000) do
          create_table "users", force: :cascade do |t|
            t.string "display_name"
            t.string "company"
            t.string "customer_number"
            t.string "phone"
            t.string "email"
            t.string "api_token"
            t.string "reset_token"
            t.string "password_digest"
            t.datetime "created_at", null: false
            t.datetime "updated_at", null: false
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    view_path = File.join(
      destination_root,
      "app/views/admin/users/index.html.erb"
    )

    expect(File).to exist(view_path)

    view = File.read(view_path)

    expect(view).to include("Users")

    expect(view).to include(
      '<div class="b4um-grid">'
    )

    expect(view).to include(
      '<section class="b4um-card b4um-card--full">'
    )

    [
      "Display name",
      "Company",
      "Customer number",
      "Phone",
      "Email"
    ].each do |label|
      expect(view).to include(
        "<th>#{label}</th>"
      )
    end

    %w[
      display_name
      company
      customer_number
      phone
      email
    ].each do |field|
      expect(view).to include(
        "user.#{field}"
      )
    end

    %w[
      api_token
      reset_token
      password_digest
      created_at
      updated_at
    ].each do |field|
      expect(view).not_to include(
        "user.#{field}"
      )
    end

    expect(view).to include(
      "<th>Admin</th>"
    )

    expect(view).to include(
      "<th>Blocked</th>"
    )

    expect(view).to include(
      "<th>Actions</th>"
    )
  end

  it "falls back to email when no schema is available" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    view_path = File.join(
      destination_root,
      "app/views/admin/users/index.html.erb"
    )

    view = File.read(view_path)

    expect(view).to include(
      "<th>Email</th>"
    )

    expect(view).to include(
      "user.email"
    )

    expect(view).to include(
      "<th>Admin</th>"
    )

    expect(view).to include(
      "<th>Blocked</th>"
    )

    expect(view).to include(
      "<th>Actions</th>"
    )
  end

  it "links the admin dashboard to user management" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    view_path = File.join(
      destination_root,
      "app/views/admin/dashboard/index.html.erb"
    )

    view = File.read(view_path)

    expect(view).to include(
      'link_to "Manage users"'
    )

    expect(view).to include(
      "admin_users_path"
    )

    expect(view).to include(
      'class: "button button--primary"'
    )
  end

  it "adds the admin block user route" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    routes_path = File.join(
      destination_root,
      "config/routes.rb"
    )

    routes = File.read(routes_path)

    expect(routes).to include(
      "patch :block"
    )
  end

  it "adds the block action to the admin users controller" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      destination_root,
      "app/controllers/admin/users_controller.rb"
    )

    controller = File.read(controller_path)

    expect(controller).to include(
      "def block"
    )

    expect(controller).to include(
      "User.find(params[:id])"
    )

    expect(controller).to include(
      "update!(blocked: true)"
    )

    expect(controller).to include(
      "redirect_to admin_users_path"
    )
  end

  it "prevents an admin from blocking themselves" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      destination_root,
      "app/controllers/admin/users_controller.rb"
    )

    controller = File.read(controller_path)

    expect(controller).to include(
      "if user == current_user"
    )

    expect(controller).to include(
      'alert: "You cannot block your own account."'
    )
  end

  it "adds a block action to the admin users table" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    view_path = File.join(
      destination_root,
      "app/views/admin/users/index.html.erb"
    )

    view = File.read(view_path)

    expect(view).to include(
      "user != current_user"
    )

    expect(view).to include(
      "block_admin_user_path(user)"
    )

    expect(view).to include(
      "turbo_method: :patch"
    )

    expect(view).to include(
      'turbo_confirm: "Block this user?"'
    )

    expect(view).to include(
      'class: "button button--secondary"'
    )
  end

  it "adds the admin unblock user route" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    routes_path = File.join(
      destination_root,
      "config/routes.rb"
    )

    routes = File.read(routes_path)

    expect(routes).to include(
      "patch :unblock"
    )
  end

  it "adds the unblock action to the admin users controller" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      destination_root,
      "app/controllers/admin/users_controller.rb"
    )

    controller = File.read(controller_path)

    expect(controller).to include(
      "def unblock"
    )

    expect(controller).to include(
      "User.find(params[:id])"
    )

    expect(controller).to include(
      "update!(blocked: false)"
    )

    expect(controller).to include(
      "redirect_to admin_users_path"
    )

    expect(controller).to include(
      'notice: "User was unblocked."'
    )
  end

  it "adds an unblock action to the admin users table" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    view_path = File.join(
      destination_root,
      "app/views/admin/users/index.html.erb"
    )

    view = File.read(view_path)

    expect(view).to include(
      "user.blocked?"
    )

    expect(view).to include(
      "unblock_admin_user_path(user)"
    )

    expect(view).to include(
      'link_to "Unblock"'
    )

    expect(view).to include(
      "turbo_method: :patch"
    )

    expect(view).to include(
      'class: "button button--secondary"'
    )
  end

  it "adds the admin grant admin route" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    routes_path = File.join(
      destination_root,
      "config/routes.rb"
    )

    routes = File.read(routes_path)

    expect(routes).to include(
      "patch :grant_admin"
    )
  end

  it "adds the grant admin action to the admin users controller" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      destination_root,
      "app/controllers/admin/users_controller.rb"
    )

    controller = File.read(controller_path)

    expect(controller).to include(
      "def grant_admin"
    )

    expect(controller).to include(
      "User.find(params[:id])"
    )

    expect(controller).to include(
      "update!(admin: true)"
    )

    expect(controller).to include(
      "redirect_to admin_users_path"
    )

    expect(controller).to include(
      'notice: "Administrator rights were granted."'
    )
  end

  it "adds a grant admin action to the admin users table" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    view_path = File.join(
      destination_root,
      "app/views/admin/users/index.html.erb"
    )

    view = File.read(view_path)

    expect(view).to include(
      'link_to "Make admin"'
    )

    expect(view).to include(
      "grant_admin_admin_user_path(user)"
    )

    expect(view).to include(
      "if user.admin?"
    )

    expect(view).to include(
      "turbo_method: :patch"
    )

    expect(view).to include(
      'turbo_confirm: "Grant administrator rights to this user?"'
    )

    expect(view).to include(
      'class: "button button--secondary"'
    )
  end

  it "adds the admin revoke admin route" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    routes_path = File.join(
      destination_root,
      "config/routes.rb"
    )

    routes = File.read(routes_path)

    expect(routes).to include(
      "patch :revoke_admin"
    )
  end

  it "adds the revoke admin action to the admin users controller" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      destination_root,
      "app/controllers/admin/users_controller.rb"
    )

    controller = File.read(controller_path)

    expect(controller).to include(
      "def revoke_admin"
    )

    expect(controller).to include(
      "User.find(params[:id])"
    )

    expect(controller).to include(
      "update!(admin: false)"
    )

    expect(controller).to include(
      "redirect_to admin_users_path"
    )

    expect(controller).to include(
      'notice: "Administrator rights were revoked."'
    )
  end

  it "prevents revoking the last administrator" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      destination_root,
      "app/controllers/admin/users_controller.rb"
    )

    controller = File.read(controller_path)

    expect(controller).to include(
      "if user.admin? && User.where(admin: true).count == 1"
    )

    expect(controller).to include(
      'alert: "The last administrator cannot lose administrator rights."'
    )

    expect(controller).to include(
      "return"
    )
  end

  it "adds a revoke admin action to the admin users table" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    view_path = File.join(
      destination_root,
      "app/views/admin/users/index.html.erb"
    )

    view = File.read(view_path)

    expect(view).to include(
      'link_to "Remove admin"'
    )

    expect(view).to include(
      "revoke_admin_admin_user_path(user)"
    )

    expect(view).to include(
      "if user.admin?"
    )

    expect(view).to include(
      "turbo_method: :patch"
    )

    expect(view).to include(
      'turbo_confirm: "Remove administrator rights from this user?"'
    )

    expect(view).to include(
      'class: "button button--secondary"'
    )
  end

  it "adds the admin destroy user route" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    routes_path = File.join(
      destination_root,
      "config/routes.rb"
    )

    routes = File.read(routes_path)

    expect(routes).to include(
      "resources :users, only: [:index, :destroy]"
    )
  end

  it "adds the destroy action to the admin users controller" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      destination_root,
      "app/controllers/admin/users_controller.rb"
    )

    controller = File.read(controller_path)

    expect(controller).to include(
      "def destroy"
    )

    expect(controller).to include(
      "User.find(params[:id])"
    )

    expect(controller).to include(
      "user.destroy!"
    )

    expect(controller).to include(
      "redirect_to admin_users_path"
    )

    expect(controller).to include(
      'notice: "User was deleted."'
    )
  end

  it "prevents an admin from deleting themselves" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      destination_root,
      "app/controllers/admin/users_controller.rb"
    )

    controller = File.read(controller_path)

    expect(controller).to include(
      "if user == current_user"
    )

    expect(controller).to include(
      'alert: "You cannot delete your own account."'
    )

    expect(controller).to include(
      "return"
    )
  end

  it "adds a delete action to the admin users table" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    view_path = File.join(
      destination_root,
      "app/views/admin/users/index.html.erb"
    )

    view = File.read(view_path)

    expect(view).to include(
      'link_to "Delete"'
    )

    expect(view).to include(
      "admin_user_path(user)"
    )

    expect(view).to include(
      "user != current_user"
    )

    expect(view).to include(
      "turbo_method: :delete"
    )

    expect(view).to include(
      'turbo_confirm: "Delete this user permanently?"'
    )

    expect(view).to include(
      'class: "button button--secondary"'
    )
  end

  it "creates the admin creation task" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    task_path = File.join(
      destination_root,
      "lib/tasks/b4um_admin.rake"
    )

    expect(File).to exist(task_path)
  end

  it "uses the authentication model in the admin creation task" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    task_path = File.join(
      destination_root,
      "lib/tasks/b4um_admin.rake"
    )

    task = File.read(task_path)

    expect(task).to include(
      "User"
    )
  end

  it "asks again when a required administrator field is empty" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    File.write(
      File.join(destination_root, "app/models/user.rb"),
      <<~RUBY
        class User < ApplicationRecord
          has_secure_password

          validates :name, presence: true
        end
      RUBY
    )

    FileUtils.mkdir_p(
      File.join(destination_root, "db")
    )

    File.write(
      File.join(destination_root, "db/schema.rb"),
      <<~RUBY
        ActiveRecord::Schema[8.0].define(version: 2026_01_01_000000) do
          create_table "users", force: :cascade do |t|
            t.string "name"
            t.string "email"
            t.string "password_digest"
            t.datetime "created_at", null: false
            t.datetime "updated_at", null: false
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    task_path = File.join(
      destination_root,
      "lib/tasks/b4um_admin.rake"
    )

    task = File.read(task_path)

    expect(task).to include(
      'required = required_fields.include?("name")'
    )

    expect(task).to include(
      'required_marker = required ? " *" : ""'
    )

    expect(task).to include(
      "name = nil"
    )

    expect(task).to include(
      "loop do"
    )

    expect(task).to include(
      "print \"Name\#{required_marker}: \""
    )

    expect(task).to include(
      "name = STDIN.gets&.strip"
    )

    expect(task).to include(
      "break unless required && (name.nil? || name.empty?)"
    )

    expect(task).to include(
      'puts "Name cannot be empty."'
    )

    expect(task).not_to include(
      'abort "Name cannot be empty."'
    )

    expect(task).to include(
      "attributes[:name] = name"
    )
  end

  it "does not ask for a name when the authentication model has no name field" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    task_path = File.join(
      destination_root,
      "lib/tasks/b4um_admin.rake"
    )

    task = File.read(task_path)

    expect(task).to include(
      'print "Email *: "'
    )

    expect(task).not_to include(
      "name = STDIN.gets&.strip"
    )

    expect(task).not_to include(
      "name: name"
    )

    expect(task).to include(
      'print "Email *: "'
    )
  end

  it "supports additional authentication model fields when creating an administrator" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    FileUtils.mkdir_p(
      File.join(destination_root, "db")
    )

    File.write(
      File.join(destination_root, "db/schema.rb"),
      <<~RUBY
        ActiveRecord::Schema[8.0].define(version: 2026_01_01_000000) do
          create_table "users", force: :cascade do |t|
            t.string "first_name"
            t.string "last_name"
            t.string "company"
            t.string "email"
            t.string "password_digest"
            t.datetime "created_at", null: false
            t.datetime "updated_at", null: false
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    task_path = File.join(
      destination_root,
      "lib/tasks/b4um_admin.rake"
    )

    task = File.read(task_path)

    %w[
      first_name
      last_name
      company
    ].each do |field|
      expect(task).to include(
        "required = required_fields.include?(\"#{field}\")"
      )
    end

    expect(task).to include(
      "print \"First name\#{required_marker}: \""
    )

    expect(task).to include(
      "first_name = STDIN.gets&.strip"
    )

    expect(task).to include(
      "print \"Last name\#{required_marker}: \""
    )

    expect(task).to include(
      "last_name = STDIN.gets&.strip"
    )

    expect(task).to include(
      "print \"Company\#{required_marker}: \""
    )

    expect(task).to include(
      "company = STDIN.gets&.strip"
    )

    expect(task).to include(
      "attributes[:first_name] = first_name"
    )

    expect(task).to include(
      "attributes[:last_name] = last_name"
    )

    expect(task).to include(
      "attributes[:company] = company"
    )

    expect(task).to include(
      'print "Email *: "'
    )

    expect(task).not_to include(
      'print "Password digest'
    )

    expect(task).not_to include(
      'print "Created at'
    )

    expect(task).not_to include(
      'print "Updated at'
    )
  end

  it "only asks for supported authentication model fields when creating an administrator" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    FileUtils.mkdir_p(
      File.join(destination_root, "db")
    )

    File.write(
      File.join(destination_root, "db/schema.rb"),
      <<~RUBY
        ActiveRecord::Schema[8.0].define(version: 2026_01_01_000000) do
          create_table "users", force: :cascade do |t|
            t.string "name"
            t.string "company"
            t.text "description"
            t.boolean "newsletter"
            t.integer "login_count"
            t.date "birthday"
            t.string "email"
            t.string "password_digest"
            t.boolean "admin", default: false, null: false
            t.boolean "blocked", default: false, null: false
            t.datetime "created_at", null: false
            t.datetime "updated_at", null: false
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    task_path = File.join(
      destination_root,
      "lib/tasks/b4um_admin.rake"
    )

    task = File.read(task_path)

    expect(task).to include(
      "print \"Name\#{required_marker}: \""
    )

    expect(task).to include(
      "print \"Company\#{required_marker}: \""
    )

    expect(task).to include(
      "print \"Description\#{required_marker}: \""
    )

    expect(task).not_to include(
      'print "Newsletter'
    )

    expect(task).not_to include(
      'print "Login count'
    )

    expect(task).not_to include(
      'print "Birthday'
    )

    expect(task).not_to include(
      'print "Password digest'
    )

    expect(task).not_to include(
      'print "Admin'
    )

    expect(task).not_to include(
      'print "Blocked'
    )
  end

  it "marks required administrator fields from model presence validations" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    File.write(
      File.join(destination_root, "app/models/user.rb"),
      <<~RUBY
        class User < ApplicationRecord
          has_secure_password

          validates :first_name, :last_name, :company, presence: true
        end
      RUBY
    )

    FileUtils.mkdir_p(
      File.join(destination_root, "db")
    )

    File.write(
      File.join(destination_root, "db/schema.rb"),
      <<~RUBY
        ActiveRecord::Schema[8.0].define(version: 2026_01_01_000000) do
          create_table "users", force: :cascade do |t|
            t.string "first_name"
            t.string "last_name"
            t.string "company"
            t.string "phone"
            t.string "api_token"
            t.string "email"
            t.string "password_digest"
            t.datetime "created_at", null: false
            t.datetime "updated_at", null: false
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    task_path = File.join(
      destination_root,
      "lib/tasks/b4um_admin.rake"
    )

    task = File.read(task_path)

    expect(task).to include(
      "ActiveModel::Validations::PresenceValidator"
    )

    expect(task).to include(
      "required_fields"
    )

    %w[
      first_name
      last_name
      company
      phone
      api_token
    ].each do |field|
      expect(task).to include(
        "required = required_fields.include?(\"#{field}\")"
      )
    end

    expect(task).to include(
      'required_marker = required ? " *" : ""'
    )

    expect(task).to include(
      "print \"First name\#{required_marker}: \""
    )

    expect(task).to include(
      "print \"Last name\#{required_marker}: \""
    )

    expect(task).to include(
      "print \"Company\#{required_marker}: \""
    )

    expect(task).to include(
      "print \"Phone\#{required_marker}: \""
    )

    expect(task).to include(
      "print \"Api token\#{required_marker}: \""
    )

    expect(task).to include(
      "break unless required && (first_name.nil? || first_name.empty?)"
    )

    expect(task).to include(
      "break unless required && (last_name.nil? || last_name.empty?)"
    )

    expect(task).to include(
      "break unless required && (company.nil? || company.empty?)"
    )

    expect(task).to include(
      "break unless required && (phone.nil? || phone.empty?)"
    )

    expect(task).to include(
      "break unless required && (api_token.nil? || api_token.empty?)"
    )

    expect(task).to include(
      "attributes[:first_name] = first_name"
    )

    expect(task).to include(
      "attributes[:last_name] = last_name"
    )

    expect(task).to include(
      "attributes[:company] = company"
    )

    expect(task).to include(
      "attributes[:phone] = phone"
    )

    expect(task).to include(
      "attributes[:api_token] = api_token"
    )
  end

  it "marks normal account requirements as required after guest support" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    File.write(
      File.join(destination_root, "app/models/user.rb"),
      <<~RUBY
        class User < ApplicationRecord
          has_secure_password

          validates :first_name, :last_name, :email,
                    presence: true,
                    unless: :guest?

          validates :first_name, :email,
                    presence: true,
                    if: :guest?
        end
      RUBY
    )

    FileUtils.mkdir_p(
      File.join(destination_root, "db")
    )

    File.write(
      File.join(destination_root, "db/schema.rb"),
      <<~RUBY
        ActiveRecord::Schema[8.0].define(version: 2026_01_01_000000) do
          create_table "users", force: :cascade do |t|
            t.string "first_name"
            t.string "last_name"
            t.string "company"
            t.string "email"
            t.string "password_digest"
            t.boolean "guest", default: false, null: false
            t.datetime "guest_expires_at"
            t.boolean "admin", default: false, null: false
            t.boolean "blocked", default: false, null: false
            t.datetime "created_at", null: false
            t.datetime "updated_at", null: false
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    task_path = File.join(
      destination_root,
      "lib/tasks/b4um_admin.rake"
    )

    task = File.read(task_path)

    expect(task).to include(
      "validator.options[:unless] == :guest?"
    )

    expect(task).to include(
      'required = required_fields.include?("first_name")'
    )

    expect(task).to include(
      'required = required_fields.include?("last_name")'
    )

    expect(task).to include(
      'required_marker = required ? " *" : ""'
    )

    expect(task).to include(
      "break unless required && (first_name.nil? || first_name.empty?)"
    )

    expect(task).to include(
      "break unless required && (last_name.nil? || last_name.empty?)"
    )
  end

  it "does not mark conditionally validated administrator fields as always required" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    File.write(
      File.join(destination_root, "app/models/user.rb"),
      <<~RUBY
        class User < ApplicationRecord
          has_secure_password

          validates :first_name, presence: true
          validates :company, presence: true, if: :business_account?
        end
      RUBY
    )

    FileUtils.mkdir_p(
      File.join(destination_root, "db")
    )

    File.write(
      File.join(destination_root, "db/schema.rb"),
      <<~RUBY
        ActiveRecord::Schema[8.0].define(version: 2026_01_01_000000) do
          create_table "users", force: :cascade do |t|
            t.string "first_name"
            t.string "company"
            t.string "email"
            t.string "password_digest"
            t.datetime "created_at", null: false
            t.datetime "updated_at", null: false
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    task = File.read(
      File.join(
        destination_root,
        "lib/tasks/b4um_admin.rake"
      )
    )

    expect(task).to include(
      "validator.options[:if].nil?"
    )

    expect(task).to include(
      "validator.options[:unless].nil?"
    )
  end

  it "checks that the admin database fields exist before creating an administrator" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    task = File.read(
      File.join(
        destination_root,
        "lib/tasks/b4um_admin.rake"
      )
    )

    expect(task).to include(
      "missing_columns = %w[admin blocked] - model.column_names"
    )

    expect(task).to include(
      "unless missing_columns.empty?"
    )

    expect(task).to include(
      "Run bin/rails db:migrate before creating an administrator."
    )
  end

  it "asks for the administrator email in the admin creation task" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    task_path = File.join(
      destination_root,
      "lib/tasks/b4um_admin.rake"
    )

    task = File.read(task_path)

    expect(task).to include(
      'print "Email *: "'
    )

    expect(task).to include(
      "email = STDIN.gets&.strip"
    )
  end

  it "asks for the administrator password without echoing it" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    task_path = File.join(
      destination_root,
      "lib/tasks/b4um_admin.rake"
    )

    task = File.read(task_path)

    expect(task).to include(
      'require "io/console"'
    )

    expect(task).to include(
      'print "Password *: "'
    )

    expect(task).to include(
      "password = STDIN.noecho(&:gets)&.strip"
    )
  end

  it "asks for password confirmation in the admin creation task" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    task_path = File.join(
      destination_root,
      "lib/tasks/b4um_admin.rake"
    )

    task = File.read(task_path)

    expect(task).to include(
      'print "Confirm password *: "'
    )

    expect(task).to include(
      "password_confirmation = STDIN.noecho(&:gets)&.strip"
    )

    expect(task).to include(
      "break if password == password_confirmation"
    )

    expect(task).to include(
      'puts "Passwords do not match."'
    )

    expect(task).not_to include(
      'abort "Passwords do not match."'
    )
  end

  it "asks again when administrator credentials are empty" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    task_path = File.join(
      destination_root,
      "lib/tasks/b4um_admin.rake"
    )

    task = File.read(task_path)

    expect(task).to include(
      "email = nil"
    )

    expect(task).to include(
      "password = nil"
    )

    expect(task).to include(
      "password_confirmation = nil"
    )

    expect(task).to include(
      'print "Email *: "'
    )

    expect(task).to include(
      "break unless email.nil? || email.empty?"
    )

    expect(task).to include(
      'puts "Email cannot be empty."'
    )

    expect(task).not_to include(
      'abort "Email cannot be empty."'
    )

    expect(task).to include(
      'print "Password *: "'
    )

    expect(task).to include(
      "break unless password.nil? || password.empty?"
    )

    expect(task).to include(
      'puts "Password cannot be empty."'
    )

    expect(task).not_to include(
      'abort "Password cannot be empty."'
    )
  end

  it "creates an administrator in the admin creation task" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    task_path = File.join(
      destination_root,
      "lib/tasks/b4um_admin.rake"
    )

    task = File.read(task_path)

    expect(task).to include(
      "model.create!"
    )

    expect(task).to include(
      "email: email"
    )

    expect(task).to include(
      "password: password"
    )

    expect(task).to include(
      "password_confirmation: password_confirmation"
    )

    expect(task).to include(
      "admin: true"
    )
  end

  it "rejects an existing email in the admin creation task" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    task_path = File.join(
      destination_root,
      "lib/tasks/b4um_admin.rake"
    )

    task = File.read(task_path)

    expect(task).to include(
      "if model.exists?(email: email)"
    )

    expect(task).to include(
      'abort "A user with this email already exists."'
    )
  end

  it "reports successful administrator creation" do
    destination_root = File.expand_path(
      "../../tmp/admin_generator",
      __dir__
    )

    FileUtils.rm_rf(destination_root)

    create_authentication_setup(destination_root)

    generator = described_class.new(
      ["User"],
      {},
      destination_root: destination_root
    )

    generator.invoke_all

    task_path = File.join(
      destination_root,
      "lib/tasks/b4um_admin.rake"
    )

    task = File.read(task_path)

    expect(task).to include(
      'puts "Administrator'
    )

    expect(task).to include(
      'was created successfully."'
    )
  end
end
