# frozen_string_literal: true

require "rails/generators"
require "rails/generators/migration"

module B4um
  module Generators
    class AdminGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Adds admin user management to an existing B4UM authentication model."

      argument :authentication_model,
               type: :string,
               required: true,
               banner: "MODEL"

      def validate_authentication_model
        model_path = File.join(
          destination_root,
          "app/models",
          "#{authentication_model_name}.rb"
        )

        return if File.exist?(model_path)

        raise Thor::Error,
              "Authentication model #{authentication_class_name} was not found. " \
              "Expected: app/models/#{authentication_model_name}.rb"
      end

      def validate_authentication_setup
        application_controller_path = File.join(
          destination_root,
          "app/controllers/application_controller.rb"
        )

        authentication_helper =
          "helper_method :#{current_authentication_method}, :logged_in?"

        authentication_installed =
          File.exist?(application_controller_path) &&
          File.read(application_controller_path).include?(authentication_helper)

        unless authentication_installed
          raise Thor::Error,
                "b4um authentication is not installed for " \
                "#{authentication_class_name}. " \
                "Run: bin/rails generate b4um:authentication " \
                "#{authentication_class_name}"
        end

        application_controller =
          File.read(application_controller_path)

        current_user_assignment =
          "@#{current_authentication_method} ||= " \
          "#{authentication_class_name}.find_by(" \
          "id: session[:#{authentication_model_name}_id])"

        unless application_controller.include?(current_user_assignment)
          raise Thor::Error,
                "Could not find the current authentication method " \
                "in app/controllers/application_controller.rb"
        end

        sessions_controller_path = File.join(
          destination_root,
          "app/controllers/sessions_controller.rb"
        )

        unless File.exist?(sessions_controller_path)
          raise Thor::Error,
                "SessionsController not found: " \
                "app/controllers/sessions_controller.rb"
        end

        sessions_controller = File.read(sessions_controller_path)

        session_assignment =
          "session[:#{authentication_model_name}_id] = " \
          "#{authentication_model_name}.id"

        return if sessions_controller.include?(session_assignment)

        raise Thor::Error,
              "Could not find the authentication session assignment " \
              "in app/controllers/sessions_controller.rb"
      end

      def protect_admin_fields
        controller_path = File.join(
          destination_root,
          "app/controllers",
          "#{authentication_model_name.pluralize}_controller.rb"
        )

        return unless File.exist?(controller_path)

        controller = File.read(controller_path)

        params_method = controller.match(
          /def #{Regexp.escape(authentication_model_name)}_params\b.*?^\s*end$/m
        )

        return unless params_method

        protected_params = params_method[0].dup

        %w[admin blocked].each do |field|
          protected_params.gsub!(
            /:#{field}\s*,?/,
            ""
          )
        end

        controller.sub!(
          params_method[0],
          protected_params
        )

        File.write(
          controller_path,
          controller
        )
      end

      def create_admin_fields_migration
        return if admin_fields_exist?

        migration_template(
          "add_admin_fields_migration.rb.tt",
          "db/migrate/add_admin_fields_to_#{authentication_model_name.pluralize}.rb"
        )
      end

      def add_admin_helper
        controller_path = "app/controllers/application_controller.rb"

        full_controller_path = File.join(
          destination_root,
          controller_path
        )

        controller = File.read(full_controller_path)

        require_admin = [
          "",
          "  def require_admin",
          "    return if logged_in? && #{current_authentication_method}.admin?",
          "",
          '    redirect_to root_path, alert: "Access denied."',
          "  end",
          ""
        ].join("\n")

        if behavior == :revoke
          return unless controller.include?(require_admin)

          File.write(
            full_controller_path,
            controller.sub(require_admin, "")
          )

          return
        end

        return if controller.include?("def require_admin")

        class_end_position = controller.rindex(/^end\s*$/)

        unless class_end_position
          raise Thor::Error,
                "Could not find the end of ApplicationController."
        end

        controller.insert(
          class_end_position,
          require_admin
        )

        File.write(
          full_controller_path,
          controller
        )
      end

      def create_admin_base_controller
        template(
          "admin_base_controller.rb.tt",
          "app/controllers/admin/base_controller.rb"
        )
      end

      def create_admin_dashboard_controller
        template(
          "admin_dashboard_controller.rb.tt",
          "app/controllers/admin/dashboard_controller.rb"
        )
      end

      def create_admin_users_controller
        template(
          "admin_users_controller.rb.tt",
          "app/controllers/admin/users_controller.rb"
        )
      end

      def create_admin_dashboard_view
        template(
          "admin_dashboard.html.erb.tt",
          "app/views/admin/dashboard/index.html.erb"
        )
      end

      def create_admin_users_index_view
        template(
          "admin_users_index.html.erb.tt",
          "app/views/admin/users/index.html.erb"
        )
      end

      def create_admin_creation_task
        template(
          "b4um_admin.rake.tt",
          "lib/tasks/b4um_admin.rake"
        )
      end

      def add_admin_route
        routes_path = "config/routes.rb"
        full_routes_path = File.join(destination_root, routes_path)

        unless File.exist?(full_routes_path)
          raise Thor::Error,
                "Routes not found: #{routes_path}"
        end

        if behavior == :revoke
          routes = File.read(full_routes_path)

          routes.gsub!(
            /^  #{Regexp.escape(admin_root_route)}\n?/,
            ""
          )

          routes.gsub!(
            /^#{Regexp.escape(indented_admin_users_route)}\n?/,
            ""
          )

          File.write(
            full_routes_path,
            routes
          )

          return
        end

        admin_users_route_status =
          upgrade_existing_admin_users_route(
            routes_path,
            full_routes_path
          )

        routes = File.read(full_routes_path)

        routes_to_add = missing_admin_routes(
          routes,
          admin_users_route_exists:
            admin_users_route_status == :upgraded
        )

        return if routes_to_add.empty?

        inject_into_file(
          routes_path,
          before: /^end\s*$/
        ) do
          "#{routes_to_add.join("\n")}\n"
        end
      end

      def invalidate_blocked_sessions
        controller_path = "app/controllers/application_controller.rb"

        full_controller_path = File.join(
          destination_root,
          controller_path
        )

        controller = File.read(full_controller_path)

        current_user_assignment =
          "@#{current_authentication_method} ||= " \
          "#{authentication_class_name}.find_by(" \
          "id: session[:#{authentication_model_name}_id])"

        blocked_session_block = [
          current_user_assignment,
          "",
          "if @#{current_authentication_method}&.blocked?",
          "  session.delete(:#{authentication_model_name}_id)",
          "  @#{current_authentication_method} = nil",
          "end",
          "",
          "@#{current_authentication_method}"
        ]

        if behavior == :revoke
          blocked_pattern = /
            ^(?<indent>[ \t]*)#{Regexp.escape(current_user_assignment)}\n
            \n
            ^\k<indent>if\ @#{Regexp.escape(current_authentication_method)}&\.blocked\?\n
            ^\k<indent>\ \ session\.delete\(:#{Regexp.escape(authentication_model_name)}_id\)\n
            ^\k<indent>\ \ @#{Regexp.escape(current_authentication_method)}\ =\ nil\n
            ^\k<indent>end\n
            \n
            ^\k<indent>@#{Regexp.escape(current_authentication_method)}$
          /x

          match = controller.match(blocked_pattern)

          return unless match

          replacement =
            "#{match[:indent]}#{current_user_assignment}"

          File.write(
            full_controller_path,
            controller.sub(
              blocked_pattern,
              replacement
            )
          )

          return
        end

        return if controller.include?(
          "if @#{current_authentication_method}&.blocked?"
        )

        assignment_match = controller.match(
          /^([ \t]*)#{Regexp.escape(current_user_assignment)}$/
        )

        unless assignment_match
          raise Thor::Error,
                "Could not find the current authentication method " \
                "in #{controller_path}"
        end

        indentation = assignment_match[1]

        replacement = blocked_session_block
                      .map do |line|
                        line.empty? ? line : "#{indentation}#{line}"
                      end
                      .join("\n")

        gsub_file(
          controller_path,
          /^#{Regexp.escape(indentation)}#{Regexp.escape(current_user_assignment)}$/,
          replacement
        )
      end

      def prevent_blocked_login
        controller_path = "app/controllers/sessions_controller.rb"

        full_controller_path = File.join(
          destination_root,
          controller_path
        )

        unless File.exist?(full_controller_path)
          raise Thor::Error,
                "SessionsController not found: #{controller_path}"
        end

        controller = File.read(full_controller_path)

        session_assignment =
          "session[:#{authentication_model_name}_id] = " \
          "#{authentication_model_name}.id"

        login_redirect =
          'redirect_to root_path, notice: "Successfully logged in."'

        if behavior == :revoke
          blocked_login_pattern = /
            ^(?<indent>[ \t]*)if\ #{Regexp.escape(authentication_model_name)}\.blocked\?\n
            ^\k<indent>\ \ flash\.now\[:alert\]\ =\ "Account\ is\ blocked\."\n
            ^\k<indent>\ \ render\ :new,\ status:\ :unprocessable_content\n
            ^\k<indent>else\n
            ^\k<indent>\ \ #{Regexp.escape(session_assignment)}\n
            \n
            ^\k<indent>\ \ #{Regexp.escape(login_redirect)}\n
            ^\k<indent>end$
          /x

          match = controller.match(blocked_login_pattern)

          return unless match

          indentation = match[:indent]

          replacement = [
            "#{indentation}#{session_assignment}",
            "",
            "#{indentation}#{login_redirect}"
          ].join("\n")

          File.write(
            full_controller_path,
            controller.sub(
              blocked_login_pattern,
              replacement
            )
          )

          return
        end

        return if controller.include?(
          "if #{authentication_model_name}.blocked?"
        )

        session_match = controller.match(
          /^(\s*)#{Regexp.escape(session_assignment)}$/
        )

        unless session_match
          raise Thor::Error,
                "Could not find the authentication session assignment " \
                "in #{controller_path}"
        end

        indent = session_match[1]
        inner_indent = "#{indent}  "

        replacement = [
          "#{indent}if #{authentication_model_name}.blocked?",
          "#{inner_indent}flash.now[:alert] = \"Account is blocked.\"",
          "#{inner_indent}render :new, status: :unprocessable_content",
          "#{indent}else",
          "#{inner_indent}#{session_assignment}"
        ].join("\n")

        gsub_file(
          controller_path,
          /^#{Regexp.escape(indent)}#{Regexp.escape(session_assignment)}$/,
          replacement
        )

        controller = File.read(full_controller_path)

        redirect_match = controller.match(
          /^(\s*)#{Regexp.escape(login_redirect)}$/
        )

        unless redirect_match
          raise Thor::Error,
                "Could not find the successful login redirect " \
                "in #{controller_path}"
        end

        redirect_indent = redirect_match[1]

        gsub_file(
          controller_path,
          /^#{Regexp.escape(redirect_indent)}#{Regexp.escape(login_redirect)}$/,
          [
            "",
            "#{inner_indent}#{login_redirect}",
            "#{indent}end"
          ].join("\n")
        )
      end

      def self.next_migration_number(_dirname)
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end

      private

      def upgrade_existing_admin_users_route(
        _routes_path,
        full_routes_path
      )
        routes = File.read(full_routes_path)

        namespace_match = routes.match(
          /^([ \t]*)namespace :admin do\s*$/
        )

        return :unchanged unless namespace_match

        namespace_indent = namespace_match[1]
        route_indent = "#{namespace_indent}  "

        namespace_start = namespace_match.end(0)

        namespace_end = routes.match(
          /^#{Regexp.escape(namespace_indent)}end\s*$/,
          namespace_start
        )

        return :unchanged unless namespace_end

        namespace_body = routes[
          namespace_start...namespace_end.begin(0)
        ]

        old_route_match = namespace_body.match(
          /^#{Regexp.escape(route_indent)}#{Regexp.escape(old_admin_users_route)}$/
        )

        return :unchanged unless old_route_match

        replacement = admin_users_resources
                      .lines
                      .map { |line| "#{route_indent}#{line}" }
                      .join
                      .chomp

        route_start =
          namespace_start + old_route_match.begin(0)

        route_end =
          namespace_start + old_route_match.end(0)

        routes[route_start...route_end] = replacement

        File.write(
          full_routes_path,
          routes
        )

        :upgraded
      end

      def missing_admin_routes(
        routes,
        admin_users_route_exists: false
      )
        routes_to_add = []

        routes_to_add << "  #{admin_root_route}" unless routes.include?(admin_root_route)

        unless admin_users_route_exists ||
               routes.include?(admin_users_route)
          routes_to_add << indented_admin_users_route
        end

        routes_to_add
      end

      def admin_root_route
        'get "admin", to: "admin/dashboard#index", as: :admin_root'
      end

      def admin_users_route
        resources = admin_users_resources
                    .lines
                    .map { |line| "  #{line}" }
                    .join
                    .chomp

        [
          "namespace :admin do",
          resources,
          "end"
        ].join("\n")
      end

      def admin_users_resources
        <<~RUBY.chomp
          resources :users, only: [:index, :destroy] do
            member do
              patch :block
              patch :unblock
              patch :grant_admin
              patch :revoke_admin
            end
          end
        RUBY
      end

      def old_admin_users_route
        "resources :users, only: [:index]"
      end

      def indented_admin_users_route
        admin_users_route
          .lines
          .map { |line| "  #{line}" }
          .join
          .chomp
      end

      def admin_creation_fields
        schema_path = File.join(
          destination_root,
          "db/schema.rb"
        )

        return [] unless File.exist?(schema_path)

        schema = File.read(schema_path)
        table_name = authentication_model_name.pluralize

        table_match = schema.match(
          /create_table "#{Regexp.escape(table_name)}".*?do \|t\|(.*?)^\s*end/m
        )

        return [] unless table_match

        excluded_fields = %w[
          id
          email
          password_digest
          admin
          blocked
          created_at
          updated_at
        ]

        fields = table_match[1].scan(
          /^\s*t\.(string|text)\s+"([^"]+)"/
        )

        fields.filter_map do |_type, field|
          field unless excluded_fields.include?(field)
        end
      end

      def admin_user_display_fields
        schema_path = File.join(
          destination_root,
          "db/schema.rb"
        )

        return ["email"] unless File.exist?(schema_path)

        schema = File.read(schema_path)
        table_name = authentication_model_name.pluralize

        table_match = schema.match(
          /create_table "#{Regexp.escape(table_name)}".*?do \|t\|(.*?)^\s*end/m
        )

        return ["email"] unless table_match

        excluded_fields = %w[
          id
          admin
          blocked
          created_at
          updated_at
        ]

        sensitive_field_pattern = /(?:password|token|secret|digest)/i

        fields = table_match[1].scan(
          /^\s*t\.\w+\s+"([^"]+)"/
        ).flatten

        fields.reject! do |field|
          excluded_fields.include?(field) ||
            field.match?(sensitive_field_pattern)
        end

        fields.empty? ? ["email"] : fields
      end

      def admin_user_field_label(field)
        field.humanize
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

      def admin_fields_exist?
        admin_column_exists? && blocked_column_exists?
      end

      def admin_column_exists?
        schema_table&.match?(/t\.boolean\s+"admin"/) || false
      end

      def blocked_column_exists?
        schema_table&.match?(/t\.boolean\s+"blocked"/) || false
      end

      def schema_table
        schema_path = File.join(destination_root, "db/schema.rb")

        return unless File.exist?(schema_path)

        schema = File.read(schema_path)

        table_name = authentication_model_name.pluralize

        table_pattern = /
          create_table\s+"#{Regexp.escape(table_name)}".*?^  end
        /mx

        schema[table_pattern]
      end
    end
  end
end
