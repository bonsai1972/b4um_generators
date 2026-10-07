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

      def update_in_place_helper
        helper_path = "app/helpers/b4um_in_place_helper.rb"

        full_helper_path = File.join(
          destination_root,
          helper_path
        )

        return unless File.exist?(full_helper_path)

        helper = File.read(full_helper_path)

        return if helper.include?(
          "def b4um_in_place_editing_allowed?\n    logged_in?"
        )

        gsub_file(
          helper_path,
          "def b4um_in_place_editing_allowed?\n    true",
          "def b4um_in_place_editing_allowed?\n    logged_in?"
        )
      end

      def protect_in_place_controllers
        controllers_path = File.join(
          destination_root,
          "app/controllers"
        )

        return unless Dir.exist?(controllers_path)

        Dir.glob(
          File.join(controllers_path, "*_controller.rb")
        ).each do |full_controller_path|
          controller = File.read(full_controller_path)

          next unless controller.include?("IN_PLACE_FIELDS")

          callback =
            "before_action :require_login, except: [:index, :show]"

          next if controller.include?(callback)

          controller_path = full_controller_path.delete_prefix(
            "#{destination_root}/"
          )

          inject_into_file(
            controller_path,
            after: /^class .*Controller < ApplicationController\s*$/
          ) do
            "\n  #{callback}"
          end
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

        if navigation.include?(
          'navigation_button_to "Logout", logout_path, method: :delete'
        )
          add_register_navigation_link(
            navigation_path,
            navigation
          )
          return
        end

        marker = "<%# B4UM_NAVIGATION_LINKS %>"

        return unless navigation.include?(marker)

        controller_name = authentication_model_name.pluralize
        new_resource_path =
          "new_#{authentication_model_name}_path"

        authentication_links = <<~ERB
          <% if logged_in? %>
            <%= navigation_button_to "Logout", logout_path, method: :delete %>
          <% else %>
            <%= navigation_link_to "Register",
                                   #{new_resource_path},
                                   controller: :#{controller_name},
                                   action: :new %>
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

      def protect_authentication_resource
        controller_path = authentication_resource_controller_path
        full_controller_path = File.join(
          destination_root,
          controller_path
        )

        return unless File.exist?(full_controller_path)

        add_authentication_resource_callbacks(controller_path)
        add_authentication_resource_authorization(controller_path)
        redirect_destroyed_authentication_resource_to_root(controller_path)
      end

      def sign_in_after_registration
        controller_path = authentication_resource_controller_path

        full_controller_path = File.join(
          destination_root,
          controller_path
        )

        return unless File.exist?(full_controller_path)

        controller = File.read(full_controller_path)

        session_assignment =
          "session[:#{authentication_model_name}_id] = " \
          "@#{authentication_model_name}.id"

        return if controller.include?(session_assignment)

        save_pattern =
          /^(\s*)if @#{Regexp.escape(authentication_model_name)}\.save\s*$/

        return unless controller.match?(save_pattern)

        inject_into_file(
          controller_path,
          after: save_pattern
        ) do
          "\n\\1  #{session_assignment}"
        end
      end

      def add_profile_navigation
        navigation_path = "app/views/shared/_navigation.html.erb"

        full_navigation_path = File.join(
          destination_root,
          navigation_path
        )

        return unless File.exist?(full_navigation_path)

        navigation = File.read(full_navigation_path)

        resource_name = authentication_class_name.pluralize
        controller_name = authentication_model_name.pluralize

        resource_pattern = /
          ^[ \t]*<%=\s*navigation_link_to\s+"#{Regexp.escape(resource_name)}",
          .*?
          controller:\s*:#{Regexp.escape(controller_name)}
          \s*%>\s*
        /mx

        if navigation.match?(resource_pattern)
          gsub_file(
            navigation_path,
            resource_pattern,
            ""
          )
        end

        navigation = File.read(full_navigation_path)

        return if navigation.include?(
          'navigation_link_to "Profile"'
        )

        login_marker = "<% if logged_in? %>"

        return unless navigation.include?(login_marker)

        profile_link = <<~ERB
          <% if logged_in? %>
            <%= navigation_link_to "Profile",
                                   #{current_authentication_method},
                                   controller: :#{controller_name},
                                   action: :show %>
        ERB

        gsub_file(
          navigation_path,
          login_marker,
          profile_link.chomp
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

      def protect_show_actions
        protected_controller_names.each do |controller_name|
          protect_show_actions_for(controller_name)
        end
      end

      def protect_index_actions
        protected_controller_names.each do |controller_name|
          protect_index_actions_for(controller_name)
        end
      end

      private

      def add_register_navigation_link(navigation_path, navigation)
        return if navigation.include?(
          'navigation_link_to "Register",'
        )

        controller_name = authentication_model_name.pluralize
        new_resource_path =
          "new_#{authentication_model_name}_path"

        login_pattern = /
          ^([ \t]*)<%=\s*navigation_link_to\s+"Login",
        /x

        return unless navigation.match?(login_pattern)

        register_link = <<~ERB
          <%= navigation_link_to "Register",
                                 #{new_resource_path},
                                 controller: :#{controller_name},
                                 action: :new %>
        ERB

        gsub_file(
          navigation_path,
          login_pattern
        ) do |match|
          indentation = match[/\A[ \t]*/]

          indented_register = register_link.lines.map do |line|
            "#{indentation}#{line}"
          end.join

          "#{indented_register}#{match}"
        end
      end

      def authentication_resource_controller_path
        File.join(
          "app/controllers",
          "#{authentication_model_name.pluralize}_controller.rb"
        )
      end

      def redirect_destroyed_authentication_resource_to_root(controller_path)
        resource_path =
          "#{authentication_model_name.pluralize}_path"

        redirect =
          "redirect_to #{resource_path}, status: :see_other"

        return unless controller_contains?(controller_path, redirect)

        gsub_file(
          controller_path,
          redirect,
          "redirect_to root_path, status: :see_other"
        )
      end

      def add_authentication_resource_callbacks(controller_path)
        add_require_login_callback(controller_path)
        add_prevent_authentication_index_callback(controller_path)
        add_require_current_authentication_callback(controller_path)
        add_clear_authentication_session_callback(controller_path)
      end

      def add_require_login_callback(controller_path)
        callback = "before_action :require_login, except: %i[ new create ]"

        return if controller_contains?(controller_path, callback)

        inject_into_file(
          controller_path,
          after: /^class .*Controller < ApplicationController\s*$/
        ) do
          "\n  #{callback}"
        end
      end

      def add_prevent_authentication_index_callback(controller_path)
        callback =
          "before_action :prevent_authentication_index, only: :index"

        return if controller_contains?(controller_path, callback)

        inject_into_file(
          controller_path,
          after: /^\s*before_action :require_login, except: %i\[ new create \]\s*$/
        ) do
          "\n  #{callback}"
        end
      end

      def add_require_current_authentication_callback(controller_path)
        callback =
          "before_action :require_current_#{authentication_model_name}, " \
          "only: %i[ show edit update destroy ]"

        return if controller_contains?(controller_path, callback)

        set_callback =
          /^\s*before_action :set_#{authentication_model_name}, only: %i\[ show edit update destroy \]\s*$/

        if controller_matches?(controller_path, set_callback)
          inject_into_file(
            controller_path,
            after: set_callback
          ) do
            "\n  #{callback}"
          end
        else
          inject_into_file(
            controller_path,
            after: /^class .*Controller < ApplicationController\s*$/
          ) do
            "\n  #{callback}"
          end
        end
      end

      def add_clear_authentication_session_callback(controller_path)
        callback =
          "after_action :clear_authentication_session, only: :destroy"

        return if controller_contains?(controller_path, callback)

        current_user_callback =
          /^\s*before_action :require_current_#{authentication_model_name}, only: %i\[ show edit update destroy \]\s*$/

        inject_into_file(
          controller_path,
          after: current_user_callback
        ) do
          "\n  #{callback}"
        end
      end

      def add_authentication_resource_authorization(controller_path)
        add_prevent_authentication_index_method(controller_path)
        add_require_current_authentication_method(controller_path)
        add_clear_authentication_session_method(controller_path)
      end

      def add_prevent_authentication_index_method(controller_path)
        method_name = "def prevent_authentication_index"

        return if controller_contains?(controller_path, method_name)

        inject_private_method(
          controller_path,
          <<~RUBY
            def prevent_authentication_index
              redirect_to #{current_authentication_method}
            end
          RUBY
        )
      end

      def add_require_current_authentication_method(controller_path)
        method_name =
          "def require_current_#{authentication_model_name}"

        return if controller_contains?(controller_path, method_name)

        inject_private_method(
          controller_path,
          <<~RUBY
            def require_current_#{authentication_model_name}
              return if @#{authentication_model_name} == #{current_authentication_method}

              redirect_to root_path, alert: "Access denied."
            end
          RUBY
        )
      end

      def add_clear_authentication_session_method(controller_path)
        method_name = "def clear_authentication_session"

        return if controller_contains?(controller_path, method_name)

        inject_private_method(
          controller_path,
          <<~RUBY
            def clear_authentication_session
              session.delete(:#{authentication_model_name}_id)
            end
          RUBY
        )
      end

      def inject_private_method(controller_path, method_body)
        full_controller_path = File.join(
          destination_root,
          controller_path
        )

        content = File.read(full_controller_path)

        class_end_position = content.rindex(/^end\s*$/)

        unless class_end_position
          raise Thor::Error,
                "Could not find the closing class end in #{controller_path}"
        end

        indented_body = method_body.lines.map do |line|
          line.strip.empty? ? "\n" : "  #{line}"
        end.join

        updated_content = content.dup

        updated_content.insert(
          class_end_position,
          "\n#{indented_body}"
        )

        File.write(
          full_controller_path,
          updated_content
        )
      end

      def controller_contains?(controller_path, content)
        full_controller_path = File.join(
          destination_root,
          controller_path
        )

        File.read(full_controller_path).include?(content)
      end

      def controller_matches?(controller_path, pattern)
        full_controller_path = File.join(
          destination_root,
          controller_path
        )

        File.read(full_controller_path).match?(pattern)
      end

      def protect_index_actions_for(controller_name)
        index_path = File.join(
          "app/views",
          controller_name.underscore,
          "index.html.erb"
        )

        full_index_path = File.join(
          destination_root,
          index_path
        )

        return unless File.exist?(full_index_path)

        content = File.read(full_index_path)

        return if content.include?("<% if logged_in? %>")

        pattern = /
          ^[ \t]*<%=\s*link_to\s+"New\s+[^"]+",.*?%>
        /mx

        return unless content.match?(pattern)

        wrap_protected_action(index_path, pattern)
      end

      def protect_show_actions_for(controller_name)
        show_path = File.join(
          "app/views",
          controller_name.underscore,
          "show.html.erb"
        )

        full_show_path = File.join(destination_root, show_path)

        return unless File.exist?(full_show_path)

        content = File.read(full_show_path)

        return if content.include?("<% if logged_in? %>")

        protect_show_edit_action(show_path, content)
        protect_show_destroy_action(show_path, content)
      end

      def protect_show_edit_action(show_path, content)
        pattern = /
          ^[ \t]*<%=\s*link_to\s+"Edit",.*?%>
        /mx

        return unless content.match?(pattern)

        wrap_protected_action(show_path, pattern)
      end

      def protect_show_destroy_action(show_path, content)
        pattern = /
          ^[ \t]*<%=\s*button_to\s+"Destroy",.*?%>
        /mx

        return unless content.match?(pattern)

        wrap_protected_action(show_path, pattern)
      end

      def wrap_protected_action(view_path, pattern)
        gsub_file(view_path, pattern) do |match|
          lines = match.lines
          indentation = lines.first[/\A\s*/]

          indented_match = lines.map do |line|
            "#{indentation}  #{line.delete_prefix(indentation)}"
          end.join

          [
            "#{indentation}<% if logged_in? %>",
            indented_match.chomp,
            "#{indentation}<% end %>"
          ].join("\n")
        end
      end

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
