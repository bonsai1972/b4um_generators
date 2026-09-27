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
end
