# frozen_string_literal: true

require "rails/generators"

module B4um
  module Generators
    class AuthenticationGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs session-based authentication for B4UM."

      argument :authentication_model,
               type: :string,
               required: true,
               banner: "MODEL"

      class_option :protect,
                   type: :string,
                   required: false,
                   desc: "Comma-separated controllers to protect"

      def validate_authentication_model
        model_path = File.join(
          destination_root,
          "app/models",
          "#{authentication_model_name}.rb"
        )

        unless File.exist?(model_path)
          raise Thor::Error,
                "Authentication model #{authentication_class_name} was not found. " \
                "Expected: app/models/#{authentication_model_name}.rb"
        end

        model = File.read(model_path)

        unless model.match?(/\bhas_secure_password\b/)
          raise Thor::Error,
                "Authentication model #{authentication_class_name} must use " \
                "has_secure_password."
        end

        return if password_digest_column_defined?

        raise Thor::Error,
              "Authentication model #{authentication_class_name} requires a " \
              "password_digest column. " \
              "Create the model with: " \
              "bin/rails generate b4um:scaffold " \
              "#{authentication_class_name} email:string password_digest:string"
      end

      def validate_protected_controllers
        protected_controller_names.each do |controller_name|
          controller_path = File.join(
            "app/controllers",
            "#{controller_name.underscore}_controller.rb"
          )

          full_controller_path = File.join(
            destination_root,
            controller_path
          )

          next if File.exist?(full_controller_path)

          raise Thor::Error,
                "Protected controller #{controller_name.camelize}Controller " \
                "was not found: #{controller_path}"
        end
      end

      def validate_bcrypt
        gemfile_path = File.join(
          destination_root,
          "Gemfile"
        )

        unless File.exist?(gemfile_path)
          raise Thor::Error,
                "Gemfile not found. bcrypt is required for authentication."
        end

        gemfile = File.read(gemfile_path)

        return if gemfile.match?(
          /^\s*gem\s+["']bcrypt["'](?:\s*,.*)?$/
        )

        raise Thor::Error,
              "bcrypt is required for authentication. " \
              "Run bin/rails generate b4um:install and enable bcrypt, " \
              "or add gem \"bcrypt\" to your Gemfile and run bundle install."
      end

      def create_sessions_controller
        template(
          "sessions_controller.rb.tt",
          "app/controllers/sessions_controller.rb"
        )
      end

      def create_login_view
        template(
          "new.html.erb.tt",
          "app/views/sessions/new.html.erb"
        )
      end

      def add_authentication_helpers
        controller_path = "app/controllers/application_controller.rb"
        full_controller_path = File.join(destination_root, controller_path)

        unless File.exist?(full_controller_path)
          raise Thor::Error,
                "ApplicationController not found: #{controller_path}"
        end

        controller = File.read(full_controller_path)

        return if controller.include?(
          "helper_method :#{current_authentication_method}, :logged_in?"
        )

        inject_into_file(
          controller_path,
          before: /^end\s*$/
        ) do
          <<~RUBY

            helper_method :#{current_authentication_method}, :logged_in?

            private

            def #{current_authentication_method}
              @#{current_authentication_method} ||= #{authentication_class_name}.find_by(id: session[:#{authentication_model_name}_id])
            end

            def logged_in?
              #{current_authentication_method}.present?
            end

            def require_login
              return if logged_in?

              redirect_to login_path, alert: "Please log in first."
            end
          RUBY
        end
      end

      def add_session_routes
        routes_path = "config/routes.rb"
        full_routes_path = File.join(destination_root, routes_path)

        routes = File.read(full_routes_path)

        return if routes.include?(
          'get "login", to: "sessions#new", as: :login'
        )

        inject_into_file(
          routes_path,
          before: /^end\s*$/
        ) do
          <<~RUBY
            get "login", to: "sessions#new", as: :login
            post "login", to: "sessions#create"
            delete "logout", to: "sessions#destroy", as: :logout
          RUBY
        end
      end

      def add_navigation_links
        navigation_path = "app/views/shared/_navigation.html.erb"
        full_navigation_path = File.join(
          destination_root,
          navigation_path
        )

        return unless File.exist?(full_navigation_path)

        navigation = File.read(full_navigation_path)

        return if navigation.include?(
          'navigation_button_to "Logout", logout_path, method: :delete'
        )

        marker = "<%# B4UM_NAVIGATION_LINKS %>"

        return unless navigation.include?(marker)

        authentication_links = <<~ERB
          <% if logged_in? %>
            <%= navigation_button_to "Logout", logout_path, method: :delete %>
          <% else %>
            <%= navigation_link_to "Login",
                                   login_path,
                                   controller: :sessions,
                                   action: :new %>
          <% end %>

          <%# B4UM_NAVIGATION_LINKS %>
        ERB

        gsub_file(
          navigation_path,
          marker,
          authentication_links.chomp
        )
      end

      def protect_controllers
        protected_controller_names.each do |controller_name|
          controller_path = File.join(
            "app/controllers",
            "#{controller_name.underscore}_controller.rb"
          )

          full_controller_path = File.join(
            destination_root,
            controller_path
          )

          controller = File.read(full_controller_path)

          next if controller.include?(
            "before_action :require_login, except: [:index, :show]"
          )

          inject_into_file(
            controller_path,
            after: /^class .*Controller < ApplicationController\s*$/
          ) do
            "\n  before_action :require_login, except: [:index, :show]"
          end
        end
      end

      private

      def protected_controller_names
        options[:protect]
          .to_s
          .split(",")
          .map(&:strip)
          .reject(&:empty?)
      end

      def authentication_class_name
        authentication_model.to_s.classify
      end

      def authentication_model_name
        authentication_model.to_s.underscore
      end

      def current_authentication_method
        "current_#{authentication_model_name}"
      end

      def password_digest_column_defined?
        password_digest_defined_in_schema? ||
          password_digest_defined_in_migrations?
      end

      def password_digest_defined_in_schema?
        schema_path = File.join(
          destination_root,
          "db/schema.rb"
        )

        return false unless File.exist?(schema_path)

        schema = File.read(schema_path)
        table_name = authentication_model_name.pluralize

        table_match = schema.match(
          /create_table\s+["']#{Regexp.escape(table_name)}["'].*?do\s+\|t\|(.*?)^\s*end/m
        )

        return false unless table_match

        table_match[1].match?(
          /t\.\w+\s+["']password_digest["']/
        )
      end

      def password_digest_defined_in_migrations?
        migration_paths = Dir.glob(
          File.join(
            destination_root,
            "db/migrate/*.rb"
          )
        )

        table_name = authentication_model_name.pluralize

        migration_paths.any? do |migration_path|
          migration = File.read(migration_path)

          references_table =
            migration.match?(
              /create_table\s+[:'"]#{Regexp.escape(table_name)}['"]?/
            ) ||
            migration.match?(
              /change_table\s+[:'"]#{Regexp.escape(table_name)}['"]?/
            ) ||
            migration.match?(
              /add_column\s+[:'"]#{Regexp.escape(table_name)}['"]?/
            )

          references_table &&
            migration.match?(/\bpassword_digest\b/)
        end
      end
    end
  end
end
