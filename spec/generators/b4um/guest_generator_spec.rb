# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

require_relative "../../../lib/generators/b4um/guest/guest_generator"

RSpec.describe B4um::Generators::GuestGenerator do
  before do
    @destination_root = Dir.mktmpdir

    FileUtils.mkdir_p(
      File.join(@destination_root, "db")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    File.write(
      File.join(@destination_root, "app/models/user.rb"),
      <<~RUBY
        class User < ApplicationRecord
          has_secure_password
        end
      RUBY
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/controllers")
    )

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

    File.write(
      File.join(
        @destination_root,
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

    FileUtils.mkdir_p(
      File.join(@destination_root, "config")
    )

    File.write(
      File.join(@destination_root, "config/routes.rb"),
      <<~RUBY
        Rails.application.routes.draw do
        end
      RUBY
    )

    File.write(
      File.join(@destination_root, "db/schema.rb"),
      <<~RUBY
        ActiveRecord::Schema[8.0].define(version: 2026_10_11_000000) do
          create_table "users", force: :cascade do |t|
            t.string "first_name"
            t.string "last_name"
            t.string "company"
            t.string "phone"
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
  end

  after do
    FileUtils.remove_entry(@destination_root)
  end

  it "loads the b4um guest generator" do
    expect(described_class).to be < Rails::Generators::NamedBase
  end

  it "provides a required fields option" do
    option = described_class.class_options[:required]

    expect(option).not_to be_nil
    expect(option.type).to eq(:string)
  end

  it "requires at least one guest field" do
    expect do
      described_class.new(
        ["User"],
        {},
        destination_root: @destination_root
      )
    end.to raise_error(
      Thor::Error,
      "At least one required guest field must be specified."
    )
  end

  it "rejects required guest fields that do not exist" do
    expect do
      described_class.new(
        ["User"],
        {
          required: "first_name,unknown_field"
        },
        destination_root: @destination_root
      )
    end.to raise_error(
      Thor::Error,
      "Unknown required guest field: unknown_field"
    )
  end

  it "rejects technical and sensitive fields as required guest fields" do
    invalid_fields = %w[
      admin
      blocked
      password_digest
    ]

    invalid_fields.each do |field|
      expect do
        described_class.new(
          ["User"],
          {
            required: field
          },
          destination_root: @destination_root
        )
      end.to raise_error(
        Thor::Error,
        "Invalid required guest field: #{field}"
      )
    end
  end

  it "provides a guest expiration option with a seven day default" do
    option = described_class.class_options[:expires_in]

    expect(option).not_to be_nil
    expect(option.type).to eq(:numeric)
    expect(option.default).to eq(7)
  end

  it "rejects a guest expiration shorter than one day" do
    expect do
      described_class.new(
        ["User"],
        {
          required: "first_name,email",
          expires_in: 0
        },
        destination_root: @destination_root
      )
    end.to raise_error(
      Thor::Error,
      "Guest expiration must be at least one day."
    )
  end

  it "creates a migration for guest access fields" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    migrations = Dir[
      File.join(
        @destination_root,
        "db/migrate/*_add_guest_fields_to_users.rb"
      )
    ]

    expect(migrations.length).to eq(1)

    migration = File.read(migrations.first)

    expect(migration).to match(
      /add_column :users, :guest, :boolean,\s+default: false, null: false/
    )

    expect(migration).to match(
      /add_column :users,\s+:guest_expires_at, :datetime/
    )
  end

  it "uses a unique migration version when the current version already exists" do
    allow(Time).to receive(:now).and_return(
      Time.utc(2026, 10, 12, 19, 34, 48)
    )

    existing_migration = File.join(
      @destination_root,
      "db/migrate/20261012193448_add_admin_fields_to_users.rb"
    )

    FileUtils.mkdir_p(File.dirname(existing_migration))
    File.write(existing_migration, "# existing migration\n")

    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    migrations = Dir[
      File.join(
        @destination_root,
        "db/migrate/*_add_guest_fields_to_users.rb"
      )
    ]

    expect(migrations.length).to eq(1)

    guest_version = File.basename(migrations.first).split("_").first

    expect(guest_version).not_to eq("20261012193448")
  end

  it "creates a migration only for missing guest access fields" do
    File.write(
      File.join(@destination_root, "db/schema.rb"),
      <<~RUBY
        ActiveRecord::Schema[8.0].define(version: 2026_10_11_000000) do
          create_table "users", force: :cascade do |t|
            t.string "first_name"
            t.string "last_name"
            t.string "company"
            t.string "phone"
            t.string "email"
            t.string "password_digest"
            t.boolean "admin", default: false, null: false
            t.boolean "blocked", default: false, null: false
            t.boolean "guest", default: false, null: false
            t.datetime "created_at", null: false
            t.datetime "updated_at", null: false
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    migrations = Dir[
      File.join(
        @destination_root,
        "db/migrate/*_add_guest_fields_to_users.rb"
      )
    ]

    expect(migrations.length).to eq(1)

    migration = File.read(migrations.first)

    expect(migration).not_to match(
      /add_column :users, :guest, :boolean/
    )

    expect(migration).to match(
      /add_column :users,\s+:guest_expires_at, :datetime/
    )
  end

  it "creates a migration for the guest flag when only expiration already exists" do
    File.write(
      File.join(@destination_root, "db/schema.rb"),
      <<~RUBY
        ActiveRecord::Schema[8.0].define(version: 2026_10_11_000000) do
          create_table "users", force: :cascade do |t|
            t.string "first_name"
            t.string "last_name"
            t.string "company"
            t.string "phone"
            t.string "email"
            t.string "password_digest"
            t.boolean "admin", default: false, null: false
            t.boolean "blocked", default: false, null: false
            t.datetime "guest_expires_at"
            t.datetime "created_at", null: false
            t.datetime "updated_at", null: false
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    migrations = Dir[
      File.join(
        @destination_root,
        "db/migrate/*_add_guest_fields_to_users.rb"
      )
    ]

    expect(migrations.length).to eq(1)

    migration = File.read(migrations.first)

    expect(migration).to match(
      /add_column :users, :guest, :boolean,\s+default: false, null: false/
    )

    expect(migration).not_to match(
      /add_column :users,\s+:guest_expires_at, :datetime/
    )
  end

  it "requires an existing authentication model" do
    expect do
      generator = described_class.new(
        ["Account"],
        {
          required: "email"
        },
        destination_root: @destination_root
      )

      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      "Authentication model Account was not found. " \
      "Expected: app/models/account.rb"
    )
  end

  it "requires b4um authentication to be installed" do
    FileUtils.rm_f(
      File.join(
        @destination_root,
        "app/controllers/application_controller.rb"
      )
    )

    expect do
      generator = described_class.new(
        ["User"],
        {
          required: "first_name,email"
        },
        destination_root: @destination_root
      )

      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      "b4um authentication is not installed for User. " \
      "Run: bin/rails generate b4um:authentication User"
    )
  end

  it "requires the authentication session lookup" do
    application_controller_path = File.join(
      @destination_root,
      "app/controllers/application_controller.rb"
    )

    File.write(
      application_controller_path,
      <<~RUBY
        class ApplicationController < ActionController::Base
          helper_method :current_user, :logged_in?

          private

          def current_user
            @current_user
          end

          def logged_in?
            current_user.present?
          end
        end
      RUBY
    )

    expect do
      generator = described_class.new(
        ["User"],
        {
          required: "first_name,email"
        },
        destination_root: @destination_root
      )

      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      "Could not find the current authentication method " \
      "in app/controllers/application_controller.rb"
    )
  end

  it "requires the authentication session assignment" do
    sessions_controller_path = File.join(
      @destination_root,
      "app/controllers/sessions_controller.rb"
    )

    File.write(
      sessions_controller_path,
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

    expect do
      generator = described_class.new(
        ["User"],
        {
          required: "first_name,email"
        },
        destination_root: @destination_root
      )

      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      "Could not find the authentication session assignment " \
      "in app/controllers/sessions_controller.rb"
    )
  end

  it "adds guest status helpers to the authentication model" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    model = File.read(
      File.join(
        @destination_root,
        "app/models/user.rb"
      )
    )

    expect(model).to include("has_secure_password")
    expect(model).to include("def guest_expired?")
    expect(model).to include("def guest_expiring_soon?")
  end

  it "does not duplicate guest status helpers" do
    2.times do
      generator = described_class.new(
        ["User"],
        {
          required: "first_name,email"
        },
        destination_root: @destination_root
      )

      generator.invoke_all
    end

    model = File.read(
      File.join(
        @destination_root,
        "app/models/user.rb"
      )
    )

    expect(model.scan("def guest_expired?").count).to eq(1)
    expect(model.scan("def guest_expiring_soon?").count).to eq(1)
  end

  it "creates the guests controller" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      @destination_root,
      "app/controllers/guests_controller.rb"
    )

    expect(File).to exist(controller_path)

    controller = File.read(controller_path)

    expect(controller).to include(
      "class GuestsController < ApplicationController"
    )
    expect(controller).to include("def new")
    expect(controller).to include("def create")
  end

  it "adds guest routes" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    routes_path = File.join(
      @destination_root,
      "config/routes.rb"
    )

    routes = File.read(routes_path)

    expect(routes).to include(
      'get "/guest", to: "guests#new", as: :guest'
    )
    expect(routes).to include(
      'post "/guest", to: "guests#create"'
    )
  end

  it "does not duplicate guest routes" do
    2.times do
      generator = described_class.new(
        ["User"],
        {
          required: "first_name,email"
        },
        destination_root: @destination_root
      )

      generator.invoke_all
    end

    routes = File.read(
      File.join(
        @destination_root,
        "config/routes.rb"
      )
    )

    expect(
      routes.scan(
        'get "/guest", to: "guests#new", as: :guest'
      ).count
    ).to eq(1)

    expect(
      routes.scan(
        'post "/guest", to: "guests#create"'
      ).count
    ).to eq(1)
  end

  it "creates a guest form with all available guest fields" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    form_path = File.join(
      @destination_root,
      "app/views/guests/new.html.erb"
    )

    expect(File).to exist(form_path)

    form = File.read(form_path)

    expect(form).to include('class="page-header"')
    expect(form).to include('class="b4um-grid"')
    expect(form).to include('class="b4um-card b4um-card--full"')
    expect(form).to include('class: "form"')
    expect(form).to include('class="form-field"')
    expect(form).to include('class: "form-input"')
    expect(form).to include('class: "form-label"')
    expect(form).to include('class="form-actions"')
    expect(form).to include('class: "form-submit"')

    expect(form).to include("first_name")
    expect(form).to include("last_name")
    expect(form).to include("company")
    expect(form).to include("phone")
    expect(form).to include("email")

    expect(form).not_to include("password_digest")
    expect(form).not_to include("admin")
    expect(form).not_to include("blocked")
    expect(form).not_to include("guest_expires_at")
    expect(form).not_to include("created_at")
    expect(form).not_to include("updated_at")
  end

  it "marks only configured guest fields as required" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    form = File.read(
      File.join(
        @destination_root,
        "app/views/guests/new.html.erb"
      )
    )

    expect(form).to match(
      /form\.text_field :first_name,.*?required: true/m
    )

    expect(form).to match(
      /form\.email_field :email,.*?required: true/m
    )

    expect(form).to match(
      /form\.text_field :last_name,.*?required: false/m
    )

    expect(form).to match(
      /form\.text_field :company,.*?required: false/m
    )

    expect(form).to match(
      /form\.telephone_field :phone,.*?required: false/m
    )

    expect(form).to include(
      'form.label :first_name, "First name *", class: "form-label"'
    )

    expect(form).to include(
      'form.label :email, "Email *", class: "form-label"'
    )

    expect(form).to include(
      'form.label :last_name, "Last name", class: "form-label"'
    )

    expect(form).to include(
      'form.label :company, "Company", class: "form-label"'
    )

    expect(form).to include(
      'form.label :phone, "Phone", class: "form-label"'
    )
  end

  it "permits only available guest fields" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/guests_controller.rb"
      )
    )

    expect(controller).to include(
      "params.require(:guest).permit(" \
      ":first_name, :last_name, :company, :phone, :email)"
    )

    expect(controller).not_to match(
      /permit\([^)]*:password_digest/
    )
    expect(controller).not_to match(
      /permit\([^)]*:admin/
    )
    expect(controller).not_to match(
      /permit\([^)]*:blocked/
    )
    expect(controller).not_to match(
      /permit\([^)]*:guest(?:,|\))/
    )
    expect(controller).not_to match(
      /permit\([^)]*:guest_expires_at/
    )
  end

  it "creates guests with server-side guest status and configured expiration" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email",
        expires_in: 14
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/guests_controller.rb"
      )
    )

    expect(controller).to include(
      "user = User.new(guest_params)"
    )

    expect(controller).to include(
      "user.guest = true"
    )

    expect(controller).to include(
      "user.guest_expires_at = 14.days.from_now"
    )
  end

  it "assigns an internal password to the guest" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/guests_controller.rb"
      )
    )

    expect(controller).to include(
      "guest_password = SecureRandom.base64(32)"
    )

    expect(controller).to include(
      "user.password = guest_password"
    )

    expect(controller).to include(
      "user.password_confirmation = guest_password"
    )
  end

  it "saves the guest and starts a session or renders the form on failure" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/guests_controller.rb"
      )
    )

    expect(controller).to include(
      "if @user.save"
    )

    expect(controller).to include(
      "session[:user_id] = @user.id"
    )

    expect(controller).to include(
      "redirect_to root_path"
    )

    expect(controller).to include(
      "render :new, status: :unprocessable_content"
    )
  end

  it "makes unconditional presence validations guest-aware" do
    model_path = File.join(
      @destination_root,
      "app/models/user.rb"
    )

    File.write(
      model_path,
      <<~RUBY
        class User < ApplicationRecord
          has_secure_password

          validates :first_name, :last_name, :email, presence: true
          validates :company, presence: true, if: :business_account?
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {
        required: "email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    model = File.read(model_path)

    expect(model).to include(
      "validates :first_name, :last_name, :email, " \
      "presence: true, unless: :guest?"
    )

    expect(model).to include(
      "validates :email, presence: true, if: :guest?"
    )

    expect(model).to include(
      "validates :company, presence: true, if: :business_account?"
    )

    expect(model).not_to include(
      "validates :company, presence: true, " \
      "if: :business_account?, unless: :guest?"
    )
  end

  it "does not duplicate guest-aware validations" do
    model_path = File.join(
      @destination_root,
      "app/models/user.rb"
    )

    File.write(
      model_path,
      <<~RUBY
        class User < ApplicationRecord
          has_secure_password

          validates :first_name, :last_name, :email, presence: true
        end
      RUBY
    )

    2.times do
      generator = described_class.new(
        ["User"],
        {
          required: "email"
        },
        destination_root: @destination_root
      )

      generator.invoke_all
    end

    model = File.read(model_path)

    expect(
      model.scan(
        "validates :first_name, :last_name, :email, " \
        "presence: true, unless: :guest?"
      ).count
    ).to eq(1)

    expect(
      model.scan(
        "validates :email, presence: true, if: :guest?"
      ).count
    ).to eq(1)

    expect(model).not_to include(
      "unless: :guest?, unless: :guest?"
    )
  end

  it "uses the authentication model instance for the guest form" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/guests_controller.rb"
      )
    )

    expect(controller).to include(
      "def new\n    @user = User.new\n  end"
    )

    expect(controller).to include(
      "@user = User.new(guest_params)"
    )

    expect(controller).to include(
      "@user.guest = true"
    )

    expect(controller).to include(
      "@user.guest_expires_at = 7.days.from_now"
    )

    expect(controller).to include(
      "@user.password = guest_password"
    )

    expect(controller).to include(
      "@user.password_confirmation = guest_password"
    )

    expect(controller).to include(
      "if @user.save"
    )

    expect(controller).to include(
      "session[:user_id] = @user.id"
    )
  end

  it "binds the guest form to the model and displays validation errors" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    form = File.read(
      File.join(
        @destination_root,
        "app/views/guests/new.html.erb"
      )
    )

    expect(form).to include(
      "form_with model: @user,"
    )

    expect(form).to include(
      "url: guest_path,"
    )

    expect(form).to include(
      "scope: :guest,"
    )

    expect(form).to include(
      'class: "form" do |form|'
    )

    expect(form).to include(
      "if @user.errors.any?"
    )

    expect(form).to include(
      'class="error-messages"'
    )

    expect(form).to include(
      'pluralize(@user.errors.count, "error")'
    )

    expect(form).to include(
      "@user.errors.each do |error|"
    )

    expect(form).to include(
      "error.full_message"
    )
  end

  it "requires securerandom for the internal guest password" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/guests_controller.rb"
      )
    )

    expect(controller).to start_with(
      "require \"securerandom\"\n\n"
    )

    expect(controller).to include(
      "guest_password = SecureRandom.base64(32)"
    )
  end

  it "removes an expired guest from the current authentication session" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    application_controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/application_controller.rb"
      )
    )

    expect(application_controller).to match(
      /user = User\.find_by\(\s*id: session\[:user_id\]\s*\)/
    )

    expect(application_controller).to include(
      "if user&.guest_expired?"
    )

    expect(application_controller).to include(
      "session.delete(:user_id)"
    )

    expect(application_controller).to include(
      "user.destroy!"
    )

    expect(application_controller).to include(
      "return nil"
    )

    expect(application_controller).to include(
      "@current_user = user"
    )
  end

  it "creates a cleanup task for expired guests" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    cleanup_task_path = File.join(
      @destination_root,
      "lib/tasks/b4um_guests.rake"
    )

    expect(File).to exist(cleanup_task_path)

    cleanup_task = File.read(cleanup_task_path)

    expect(cleanup_task).to include(
      "namespace :b4um do"
    )

    expect(cleanup_task).to include(
      "namespace :guests do"
    )

    expect(cleanup_task).to include(
      "task cleanup: :environment do"
    )

    expect(cleanup_task).to match(
      /User\s*\.where\(guest: true\)/
    )

    expect(cleanup_task).to include(
      'where("guest_expires_at <= ?", Time.current)'
    )

    expect(cleanup_task).to include(
      "destroy_all"
    )
  end

  it "does not duplicate the guest cleanup task" do
    2.times do
      generator = described_class.new(
        ["User"],
        {
          required: "first_name,email"
        },
        destination_root: @destination_root
      )

      generator.invoke_all
    end

    cleanup_task_path = File.join(
      @destination_root,
      "lib/tasks/b4um_guests.rake"
    )

    cleanup_task = File.read(cleanup_task_path)

    expect(
      cleanup_task.scan("task cleanup: :environment do").count
    ).to eq(1)

    expect(
      cleanup_task.scan('where("guest_expires_at <= ?", Time.current)').count
    ).to eq(1)
  end

  it "provides a view helper for guests that expire soon" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    application_controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/application_controller.rb"
      )
    )

    expect(application_controller).to include(
      "helper_method :guest_expiring_soon?"
    )

    expect(application_controller).to include(
      "def guest_expiring_soon?"
    )

    expect(application_controller).to include(
      "current_user&.guest_expiring_soon? || false"
    )
  end

  it "does not duplicate the guest expiration view helper" do
    2.times do
      generator = described_class.new(
        ["User"],
        {
          required: "first_name,email"
        },
        destination_root: @destination_root
      )

      generator.invoke_all
    end

    application_controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/application_controller.rb"
      )
    )

    expect(
      application_controller.scan(
        "helper_method :guest_expiring_soon?"
      ).count
    ).to eq(1)

    expect(
      application_controller.scan(
        "def guest_expiring_soon?"
      ).count
    ).to eq(1)
  end

  it "creates a warning partial for guests that expire soon" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    warning_path = File.join(
      @destination_root,
      "app/views/shared/_guest_expiration_warning.html.erb"
    )

    expect(File).to exist(warning_path)

    warning = File.read(warning_path)

    expect(warning).to include(
      "<% if guest_expiring_soon? %>"
    )

    expect(warning).to include(
      'class="flash flash--alert"'
    )

    expect(warning).to include(
      "Your guest access expires soon."
    )
  end

  it "renders the guest expiration warning in the application layout" do
    layout_path = File.join(
      @destination_root,
      "app/views/layouts/application.html.erb"
    )

    FileUtils.mkdir_p(File.dirname(layout_path))

    File.write(
      layout_path,
      <<~ERB
        <!DOCTYPE html>
        <html>
          <body>
            <main class="container">
              <%= render "shared/flash" %>
              <%= yield %>
            </main>
          </body>
        </html>
      ERB
    )

    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    layout = File.read(layout_path)

    expect(layout).to include(
      '<%= render "shared/guest_expiration_warning" %>'
    )

    expect(
      layout.index('<%= render "shared/guest_expiration_warning" %>')
    ).to be > layout.index('<%= render "shared/flash" %>')
  end

  it "does not duplicate the guest expiration warning in the application layout" do
    layout_path = File.join(
      @destination_root,
      "app/views/layouts/application.html.erb"
    )

    FileUtils.mkdir_p(File.dirname(layout_path))

    File.write(
      layout_path,
      <<~ERB
        <!DOCTYPE html>
        <html>
          <body>
            <main class="container">
              <%= render "shared/flash" %>
              <%= yield %>
            </main>
          </body>
        </html>
      ERB
    )

    2.times do
      generator = described_class.new(
        ["User"],
        {
          required: "first_name,email"
        },
        destination_root: @destination_root
      )

      generator.invoke_all
    end

    layout = File.read(layout_path)

    expect(
      layout.scan(
        '<%= render "shared/guest_expiration_warning" %>'
      ).count
    ).to eq(1)
  end

  it "adds routes for converting a guest into a registered user" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    routes_path = File.join(
      @destination_root,
      "config/routes.rb"
    )

    routes = File.read(routes_path)

    expect(routes).to include(
      'get "/guest/convert", to: "guests#edit", as: :convert_guest'
    )

    expect(routes).to include(
      'patch "/guest/convert", to: "guests#update"'
    )
  end

  it "uses the current guest for the conversion form" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      @destination_root,
      "app/controllers/guests_controller.rb"
    )

    controller = File.read(controller_path)

    expect(controller).to include(
      "def edit"
    )

    expect(controller).to include(
      "@user = current_user"
    )
  end

  it "creates a conversion form for the current guest" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    form_path = File.join(
      @destination_root,
      "app/views/guests/edit.html.erb"
    )

    expect(File).to exist(form_path)

    form = File.read(form_path)

    expect(form).to include('class="page-header"')
    expect(form).to include('class="b4um-grid"')
    expect(form).to include('class="b4um-card b4um-card--full"')

    expect(form).to include(
      "form_with model: @user"
    )

    expect(form).to include(
      "url: convert_guest_path"
    )

    expect(form).to include(
      "method: :patch"
    )

    expect(form).to include(
      "form.password_field :password"
    )

    expect(form).to include(
      "form.password_field :password_confirmation"
    )
  end

  it "converts the current guest into a registered user" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      @destination_root,
      "app/controllers/guests_controller.rb"
    )

    controller = File.read(controller_path)

    expect(controller).to include(
      "def update"
    )

    expect(controller).to include(
      "@user = current_user"
    )

    expect(controller).to include(
      "@user.assign_attributes(conversion_params)"
    )

    expect(controller).to include(
      "@user.guest = false"
    )

    expect(controller).to include(
      "@user.guest_expires_at = nil"
    )

    expect(controller).to include(
      "if @user.save"
    )

    expect(controller).to include(
      "redirect_to root_path"
    )

    expect(controller).to include(
      "render :edit, status: :unprocessable_content"
    )
  end

  it "restricts guest conversion to the current guest" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      @destination_root,
      "app/controllers/guests_controller.rb"
    )

    controller = File.read(controller_path)

    expect(controller).to include(
      "before_action :require_guest, only: %i[edit update destroy]"
    )

    expect(controller).to include(
      "def require_guest"
    )

    expect(controller).to include(
      "return if current_user&.guest?"
    )

    expect(controller).to include(
      'redirect_to root_path, alert: "Guest access required."'
    )
  end

  it "requires a new password when converting a guest" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      @destination_root,
      "app/controllers/guests_controller.rb"
    )

    controller = File.read(controller_path)

    expect(controller).to include(
      "if conversion_params[:password].blank?"
    )

    expect(controller).to include(
      '@user.errors.add(:password, "can\'t be blank")'
    )

    expect(controller).to include(
      "render :edit, status: :unprocessable_content"
    )
  end

  it "restores guest status when conversion validation fails" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      @destination_root,
      "app/controllers/guests_controller.rb"
    )

    controller = File.read(controller_path)

    expect(controller).to include(
      "guest_expires_at = @user.guest_expires_at"
    )

    expect(controller).to include(
      "@user.guest = true"
    )

    expect(controller).to include(
      "@user.guest_expires_at = guest_expires_at"
    )

    expect(controller).to include(
      "render :edit, status: :unprocessable_content"
    )
  end

  it "reads conversion fields from the authentication model params" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      @destination_root,
      "app/controllers/guests_controller.rb"
    )

    controller = File.read(controller_path)

    expect(controller).to include(
      "params.require(:user).permit("
    )
  end

  it "includes all available profile fields in the conversion form using b4um form styling" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    form_path = File.join(
      @destination_root,
      "app/views/guests/edit.html.erb"
    )

    form = File.read(form_path)

    expect(form).to include("form.text_field :first_name")
    expect(form).to include("form.text_field :last_name")
    expect(form).to include("form.text_field :company")
    expect(form).to include("form.telephone_field :phone")
    expect(form).to include("form.email_field :email")

    expect(form).to include("form.password_field :password")
    expect(form).to include("form.password_field :password_confirmation")

    expect(form).to include('class: "form-input"')
    expect(form).to include('class: "form-label"')
    expect(form).to include('placeholder: " "')
    expect(form).to include('class: "form-submit"')

    expect(form).not_to include("form.text_field :admin")
    expect(form).not_to include("form.text_field :blocked")
    expect(form).not_to include("form.text_field :guest")
    expect(form).not_to include("form.text_field :guest_expires_at")
    expect(form).not_to include("form.text_field :password_digest")
  end

  it "marks normal account requirements in the conversion form" do
    model_path = File.join(
      @destination_root,
      "app/models/user.rb"
    )

    File.write(
      model_path,
      <<~RUBY
        class User < ApplicationRecord
          has_secure_password
          validates :first_name, :last_name, :email, presence: true
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    form = File.read(
      File.join(
        @destination_root,
        "app/views/guests/edit.html.erb"
      )
    )

    expect(form).to include(
      'form.label :first_name, "First name *", class: "form-label"'
    )

    expect(form).to include(
      'form.label :last_name, "Last name *", class: "form-label"'
    )

    expect(form).to include(
      'form.label :email, "Email *", class: "form-label"'
    )

    expect(form).to include(
      'form.label :company, "Company", class: "form-label"'
    )

    expect(form).to include(
      'form.label :phone, "Phone", class: "form-label"'
    )

    expect(form).to include(
      'form.label :password, "Password *", class: "form-label"'
    )

    expect(form).to include(
      "form.label :password_confirmation,"
    )

    expect(form).to include(
      '"Password confirmation *",'
    )
  end

  it "uses b4um field types consistently in the guest form" do
    schema_path = File.join(
      @destination_root,
      "db/schema.rb"
    )

    schema = File.read(schema_path)

    schema.sub!(
      't.string "phone"',
      "t.string \"phone\"\n    " \
      "t.string \"website\""
    )

    File.write(schema_path, schema)

    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    form_path = File.join(
      @destination_root,
      "app/views/guests/new.html.erb"
    )

    form = File.read(form_path)

    expect(form).to include("form.email_field :email")
    expect(form).to include("form.telephone_field :phone")
    expect(form).to include("form.url_field :website")

    expect(form).to include('class: "form-input"')
    expect(form).to include('class: "form-label"')
    expect(form).to include('class: "form-submit"')
  end

  it "allows the current guest to delete their guest account" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    routes_path = File.join(
      @destination_root,
      "config/routes.rb"
    )

    routes = File.read(routes_path)

    expect(routes).to include(
      'delete "/guest", to: "guests#destroy"'
    )

    controller_path = File.join(
      @destination_root,
      "app/controllers/guests_controller.rb"
    )

    controller = File.read(controller_path)

    expect(controller).to include(
      "before_action :require_guest, only: %i[edit update destroy]"
    )

    expect(controller).to include(
      "def destroy"
    )

    expect(controller).to include(
      "@user = current_user"
    )

    expect(controller).to include(
      "session.delete(:user_id)"
    )

    expect(controller).to include(
      "@user.destroy!"
    )

    expect(controller).to include(
      "redirect_to root_path"
    )
  end

  it "prevents logged in users from creating a guest account" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    controller_path = File.join(
      @destination_root,
      "app/controllers/guests_controller.rb"
    )

    controller = File.read(controller_path)

    expect(controller).to include(
      "before_action :require_logged_out, only: %i[new create]"
    )

    expect(controller).to include(
      "def require_logged_out"
    )

    expect(controller).to include(
      "return unless current_user"
    )

    expect(controller).to include(
      'redirect_to root_path, alert: "You are already logged in."'
    )
  end

  it "provides conversion and deletion actions in the guest expiration warning" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    warning_path = File.join(
      @destination_root,
      "app/views/shared/_guest_expiration_warning.html.erb"
    )

    warning = File.read(warning_path)

    expect(warning).to include(
      'link_to "Create account", convert_guest_path'
    )

    expect(warning).to include(
      'button_to "Delete guest account",'
    )

    expect(warning).to include(
      "guest_path,"
    )

    expect(warning).to include(
      "method: :delete"
    )

    expect(warning).to include(
      'data: { turbo_confirm: "Delete your guest account?" }'
    )
  end

  it "adds a missing guest expiration helper when another guest helper already exists" do
    model_path = File.join(
      @destination_root,
      "app/models/user.rb"
    )

    File.write(
      model_path,
      <<~RUBY
        class User < ApplicationRecord
          has_secure_password

          def guest_expired?
            guest? &&
              guest_expires_at.present? &&
              guest_expires_at <= Time.current
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    model = File.read(model_path)

    expect(model.scan("def guest_expired?").count).to eq(1)
    expect(model.scan("def guest_expiring_soon?").count).to eq(1)
  end

  it "adds a missing guest expired helper when the expiring soon helper already exists" do
    model_path = File.join(
      @destination_root,
      "app/models/user.rb"
    )

    File.write(
      model_path,
      <<~RUBY
        class User < ApplicationRecord
          has_secure_password

          def guest_expiring_soon?
            guest? &&
              guest_expires_at.present? &&
              !guest_expired? &&
              guest_expires_at <= 24.hours.from_now
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    model = File.read(model_path)

    expect(model.scan("def guest_expired?").count).to eq(1)
    expect(model.scan("def guest_expiring_soon?").count).to eq(1)
  end

  it "adds only missing guest routes when some guest routes already exist" do
    routes_path = File.join(
      @destination_root,
      "config/routes.rb"
    )

    File.write(
      routes_path,
      <<~RUBY
        Rails.application.routes.draw do
          get "/guest", to: "guests#new", as: :guest
          post "/guest", to: "guests#create"
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    routes = File.read(routes_path)

    expect(
      routes.scan('get "/guest", to: "guests#new", as: :guest').count
    ).to eq(1)

    expect(
      routes.scan('post "/guest", to: "guests#create"').count
    ).to eq(1)

    expect(
      routes.scan('delete "/guest", to: "guests#destroy"').count
    ).to eq(1)

    expect(
      routes.scan(
        'get "/guest/convert", to: "guests#edit", as: :convert_guest'
      ).count
    ).to eq(1)

    expect(
      routes.scan(
        'patch "/guest/convert", to: "guests#update"'
      ).count
    ).to eq(1)
  end

  it "uses acceptance validation for required boolean guest fields" do
    schema_path = File.join(
      @destination_root,
      "db/schema.rb"
    )

    schema = File.read(schema_path)

    schema.sub!(
      't.string "email"',
      <<~RUBY.chomp
        t.string "email"
        t.boolean "privacy_accepted"
      RUBY
    )

    File.write(schema_path, schema)

    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email,privacy_accepted"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    model = File.read(
      File.join(
        @destination_root,
        "app/models/user.rb"
      )
    )

    expect(model).to include(
      "validates :first_name, :email, presence: true, if: :guest?"
    )

    expect(model).to include(
      "validates :privacy_accepted, acceptance: true, if: :guest?"
    )

    expect(model).not_to include(
      "validates :first_name, :email, :privacy_accepted, " \
      "presence: true, if: :guest?"
    )
  end

  it "marks required boolean guest fields as required checkboxes" do
    schema_path = File.join(
      @destination_root,
      "db/schema.rb"
    )

    schema = File.read(schema_path)

    schema.sub!(
      't.string "email"',
      <<~RUBY.chomp
        t.string "email"
        t.boolean "privacy_accepted"
      RUBY
    )

    File.write(schema_path, schema)

    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email,privacy_accepted"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    form = File.read(
      File.join(
        @destination_root,
        "app/views/guests/new.html.erb"
      )
    )

    expect(form).to include(
      "form.check_box :privacy_accepted,"
    )

    expect(form).to match(
      /form\.check_box :privacy_accepted,.*?required: true/m
    )
  end

  it "indents guest status helpers inside the authentication model" do
    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    model = File.read(
      File.join(
        @destination_root,
        "app/models/user.rb"
      )
    )

    expired_line =
      model.lines.find do |line|
        line.include?("def guest_expired?")
      end

    expiring_soon_line =
      model.lines.find do |line|
        line.include?("def guest_expiring_soon?")
      end

    expect(expired_line.index("def guest_expired?")).to eq(2)

    expect(
      expiring_soon_line.index("def guest_expiring_soon?")
    ).to eq(2)
  end

  it "keeps optional boolean guest fields optional" do
    schema_path = File.join(
      @destination_root,
      "db/schema.rb"
    )

    schema = File.read(schema_path)

    schema.sub!(
      't.string "email"',
      <<~RUBY.chomp
        t.string "email"
        t.boolean "newsletter"
      RUBY
    )

    File.write(schema_path, schema)

    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    form = File.read(
      File.join(
        @destination_root,
        "app/views/guests/new.html.erb"
      )
    )

    model = File.read(
      File.join(
        @destination_root,
        "app/models/user.rb"
      )
    )

    expect(form).to include(
      "form.check_box :newsletter,"
    )

    expect(form).to match(
      /form\.check_box :newsletter,.*?required: false/m
    )

    expect(model).not_to include(
      "validates :newsletter, acceptance: true, if: :guest?"
    )
  end

  it "supports authentication methods already extended with blocked user handling" do
    application_controller_path = File.join(
      @destination_root,
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

            if @current_user&.blocked?
              session.delete(:user_id)
              @current_user = nil
            end

            @current_user
          end

          def logged_in?
            current_user.present?
          end

          def require_login
            return if logged_in?

            redirect_to login_path, alert: "Please log in first."
          end

          def require_admin
            return if logged_in? && current_user.admin?

            redirect_to root_path, alert: "Access denied."
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["User"],
      {
        required: "first_name,email"
      },
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.not_to raise_error

    controller = File.read(application_controller_path)

    expect(controller).to include(
      "if user&.guest_expired?"
    )

    expect(controller).to include(
      "if user&.blocked?"
    )

    expect(controller).to include(
      "session.delete(:user_id)"
    )
  end
end
