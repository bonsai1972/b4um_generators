# frozen_string_literal: true

require "rails/generators"
require "rails/generators/migration"

module B4um
  module Generators
    class GuestGenerator < Rails::Generators::NamedBase
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      class_option :required,
                   type: :string,
                   desc: "Fields required for guest access. Example: name,email"

      class_option :expires_in,
                   type: :numeric,
                   default: 7,
                   desc: "Number of days before guest access expires"

      def initialize(args, options, config)
        super

        validate_authentication_model
        validate_authentication_setup
        validate_required_fields
        validate_expiration
      end

      def create_guest_fields_migration
        return if guest_fields_exist?

        migration_template(
          "add_guest_fields_migration.rb.tt",
          "db/migrate/add_guest_fields_to_#{authentication_model_name.pluralize}.rb"
        )
      end

      def self.next_migration_number(dirname)
        migration_number = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i

        existing_numbers =
          Dir[File.join(dirname, "*.rb")]
          .filter_map do |path|
            File.basename(path)[/\A(\d+)_/, 1]&.to_i
          end

        migration_number += 1 while existing_numbers.include?(migration_number)

        migration_number.to_s
      end

      def add_guest_status_helpers
        model_path =
          "app/models/#{authentication_model_name}.rb"

        full_model_path = File.join(
          destination_root,
          model_path
        )

        model = File.read(full_model_path)

        missing_helpers = []

        unless model.include?("def guest_expired?")
          missing_helpers << <<~RUBY
            def guest_expired?
              guest? &&
                guest_expires_at.present? &&
                guest_expires_at <= Time.current
            end
          RUBY
        end

        unless model.include?("def guest_expiring_soon?")
          missing_helpers << <<~RUBY
            def guest_expiring_soon?
              guest? &&
                guest_expires_at.present? &&
                !guest_expired? &&
                guest_expires_at <= 24.hours.from_now
            end
          RUBY
        end

        return if missing_helpers.empty?

        class_end_position = model.rindex(/^end\s*$/)

        unless class_end_position
          raise Thor::Error,
                "Could not find the end of #{authentication_class_name}."
        end

        guest_helpers =
          missing_helpers
          .map { |helper| helper.lines.map { |line| "  #{line}" }.join }
          .join("\n")

        model.insert(
          class_end_position,
          "\n#{guest_helpers}\n"
        )

        File.write(
          full_model_path,
          model
        )
      end

      def add_guest_validations
        model_path =
          "app/models/#{authentication_model_name}.rb"

        full_model_path = File.join(
          destination_root,
          model_path
        )

        model = File.read(full_model_path)

        model.gsub!(
          /^(\s*validates\s+:[^\n]+,\s+presence:\s+true)\s*$/,
          '\1, unless: :guest?'
        )

        validations = guest_required_validations

        missing_validations =
          validations.reject do |validation|
            model.include?(validation.strip)
          end

        if missing_validations.any?
          class_end_position = model.rindex(/^end\s*$/)

          unless class_end_position
            raise Thor::Error,
                  "Could not find the end of #{authentication_class_name}."
          end

          model.insert(
            class_end_position,
            "\n#{missing_validations.join}"
          )
        end

        File.write(
          full_model_path,
          model
        )
      end

      def guest_required_validations
        boolean_fields, presence_fields =
          guest_required_fields.partition do |field|
            guest_field_type(field) == :boolean
          end

        validations = []

        if presence_fields.any?
          fields =
            presence_fields
            .map { |field| ":#{field}" }
            .join(", ")

          validations << "  validates #{fields}, " \
                         "presence: true, if: :guest?\n"
        end

        boolean_fields.each do |field|
          validations << "  validates :#{field}, " \
                         "acceptance: true, if: :guest?\n"
        end

        validations
      end

      def add_guest_expiration_to_authentication
        controller_path =
          "app/controllers/application_controller.rb"

        full_controller_path = File.join(
          destination_root,
          controller_path
        )

        controller = File.read(full_controller_path)

        return if controller.include?(
          "if #{authentication_model_name}&.guest_expired?"
        )

        simple_method_pattern = /
          ^\s*def\ #{Regexp.escape(current_authentication_method)}\n
          \s+@#{Regexp.escape(current_authentication_method)}\s*\|\|=\s*
          #{Regexp.escape(authentication_class_name)}\.find_by\(
          id:\s*session\[:#{Regexp.escape(authentication_model_name)}_id\]
          \)\n
          \s*end
        /x

        blocked_method_pattern = /
          ^\s*def\ #{Regexp.escape(current_authentication_method)}\n
          \s+@#{Regexp.escape(current_authentication_method)}\s*\|\|=\s*
          #{Regexp.escape(authentication_class_name)}\.find_by\(
          id:\s*session\[:#{Regexp.escape(authentication_model_name)}_id\]
          \)\n
          \s*
          if\s+@#{Regexp.escape(current_authentication_method)}&\.blocked\?\n
          \s+session\.delete\(
          :#{Regexp.escape(authentication_model_name)}_id
          \)\n
          \s+@#{Regexp.escape(current_authentication_method)}\s*=\s*nil\n
          \s*end\n
          \s*
          @#{Regexp.escape(current_authentication_method)}\n
          \s*end
        /x

        if controller.match?(blocked_method_pattern)
          replacement =
            guest_aware_authentication_method(
              include_blocked_check: true
            )

          pattern = blocked_method_pattern
        elsif controller.match?(simple_method_pattern)
          replacement =
            guest_aware_authentication_method(
              include_blocked_check: false
            )

          pattern = simple_method_pattern
        else
          raise Thor::Error,
                "Could not update #{current_authentication_method} " \
                "in app/controllers/application_controller.rb"
        end

        controller.sub!(
          pattern,
          replacement
        )

        File.write(
          full_controller_path,
          controller
        )
      end

      def add_guest_expiration_view_helper
        controller_path =
          "app/controllers/application_controller.rb"

        full_controller_path = File.join(
          destination_root,
          controller_path
        )

        controller = File.read(full_controller_path)

        return if controller.include?(
          "helper_method :guest_expiring_soon?"
        )

        helper_code = <<~RUBY

          helper_method :guest_expiring_soon?

          def guest_expiring_soon?
            #{current_authentication_method}&.guest_expiring_soon? || false
          end
        RUBY

        class_end_position = controller.rindex(/^end\s*$/)

        unless class_end_position
          raise Thor::Error,
                "Could not find the end of ApplicationController."
        end

        controller.insert(
          class_end_position,
          helper_code
        )

        File.write(
          full_controller_path,
          controller
        )
      end

      def create_guest_cleanup_task
        template(
          "b4um_guests.rake.tt",
          "lib/tasks/b4um_guests.rake"
        )
      end

      def create_guest_expiration_warning
        template(
          "guest_expiration_warning.html.erb.tt",
          "app/views/shared/_guest_expiration_warning.html.erb"
        )
      end

      def add_guest_expiration_warning_to_layout
        layout_path =
          "app/views/layouts/application.html.erb"

        full_layout_path = File.join(
          destination_root,
          layout_path
        )

        return unless File.exist?(full_layout_path)

        layout = File.read(full_layout_path)

        warning_render =
          '<%= render "shared/guest_expiration_warning" %>'

        return if layout.include?(warning_render)

        flash_render =
          '<%= render "shared/flash" %>'

        return unless layout.include?(flash_render)

        layout.sub!(
          flash_render,
          "#{flash_render}\n      #{warning_render}"
        )

        File.write(
          full_layout_path,
          layout
        )
      end

      def create_guests_controller
        template(
          "guests_controller.rb.tt",
          "app/controllers/guests_controller.rb"
        )
      end

      def add_guest_routes
        routes_path = File.join(
          destination_root,
          "config/routes.rb"
        )

        routes = File.read(routes_path)

        guest_routes = [
          'get "/guest", to: "guests#new", as: :guest',
          'post "/guest", to: "guests#create"',
          'delete "/guest", to: "guests#destroy"',
          'get "/guest/convert", to: "guests#edit", as: :convert_guest',
          'patch "/guest/convert", to: "guests#update"'
        ]

        missing_routes = guest_routes.reject do |route|
          routes.include?(route)
        end

        return if missing_routes.empty?

        route_block_end = routes.rindex(/^end\s*$/)

        unless route_block_end
          raise Thor::Error,
                "Could not find the routes block in config/routes.rb."
        end

        routes.insert(
          route_block_end,
          "#{missing_routes.join("\n")}\n"
        )

        File.write(
          routes_path,
          routes
        )
      end

      def create_guest_form
        template(
          "new.html.erb.tt",
          "app/views/guests/new.html.erb"
        )
      end

      def create_guest_conversion_form
        template(
          "edit.html.erb.tt",
          "app/views/guests/edit.html.erb"
        )
      end

      private

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

        guest_aware_current_user =
          "if #{authentication_model_name}&.guest_expired?"

        unless application_controller.include?(current_user_assignment) ||
               application_controller.include?(guest_aware_current_user)
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

      def validate_required_fields
        required_fields = options[:required]
                          .to_s
                          .split(",")
                          .map(&:strip)
                          .reject(&:empty?)

        if required_fields.empty?
          raise Thor::Error,
                "At least one required guest field must be specified."
        end

        unknown_fields = required_fields - guest_model_fields

        unless unknown_fields.empty?
          raise Thor::Error,
                "Unknown required guest field: #{unknown_fields.first}"
        end

        invalid_fields = required_fields - guest_available_fields

        return if invalid_fields.empty?

        raise Thor::Error,
              "Invalid required guest field: #{invalid_fields.first}"
      end

      def validate_expiration
        return if options[:expires_in].to_i >= 1

        raise Thor::Error,
              "Guest expiration must be at least one day."
      end

      def guest_fields_exist?
        fields = guest_model_fields

        fields.include?("guest") &&
          fields.include?("guest_expires_at")
      end

      def guest_model_fields
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

        table_match[1].scan(
          /^\s*t\.\w+\s+"([^"]+)"/
        ).flatten
      end

      def guest_available_fields
        excluded_fields = %w[
          id
          admin
          blocked
          guest
          guest_expires_at
          created_at
          updated_at
        ]

        sensitive_field_pattern = /(?:password|token|secret|digest)/i

        guest_model_fields.reject do |field|
          excluded_fields.include?(field) ||
            field.match?(sensitive_field_pattern)
        end
      end

      def guest_required_fields
        options[:required]
          .to_s
          .split(",")
          .map(&:strip)
          .reject(&:empty?)
      end

      def account_required_fields
        model_path = File.join(
          destination_root,
          "app/models",
          "#{authentication_model_name}.rb"
        )

        model = File.read(model_path)

        model
          .scan(
            /validates\s+((?::[a-zA-Z_]\w*\s*,?\s*)+),\s*presence:\s+true/
          )
          .flat_map do |match|
            match.first.scan(/:([a-zA-Z_]\w*)/).flatten
          end
          .uniq
      end

      def guest_field_type(field)
        schema_path = File.join(
          destination_root,
          "db/schema.rb"
        )

        schema = File.read(schema_path)
        table_name = authentication_model_name.pluralize

        table_match = schema.match(
          /create_table "#{Regexp.escape(table_name)}".*?do \|t\|(.*?)^\s*end/m
        )

        return :string unless table_match

        field_match = table_match[1].match(
          /^\s*t\.(\w+)\s+"#{Regexp.escape(field)}"/
        )

        return :string unless field_match

        field_match[1].to_sym
      end

      def authentication_model_name
        name.underscore
      end

      def authentication_class_name
        name.camelize
      end

      def current_authentication_method
        "current_#{authentication_model_name}"
      end

      def guest_aware_authentication_method(include_blocked_check:)
        lines = [
          "def #{current_authentication_method}",
          "  return @#{current_authentication_method} " \
          "if defined?(@#{current_authentication_method})",
          "",
          "  #{authentication_model_name} = " \
          "#{authentication_class_name}.find_by(",
          "    id: session[:#{authentication_model_name}_id]",
          "  )",
          "",
          "  if #{authentication_model_name}&.guest_expired?",
          "    session.delete(:#{authentication_model_name}_id)",
          "    #{authentication_model_name}.destroy!",
          "    @#{current_authentication_method} = nil",
          "    return nil",
          "  end"
        ]

        if include_blocked_check
          lines.push(
            "",
            "  if #{authentication_model_name}&.blocked?",
            "    session.delete(:#{authentication_model_name}_id)",
            "    @#{current_authentication_method} = nil",
            "    return nil",
            "  end"
          )
        end

        lines.push(
          "",
          "  @#{current_authentication_method} = " \
          "#{authentication_model_name}",
          "end"
        )

        lines
          .map { |line| line.empty? ? line : "  #{line}" }
          .join("\n")
      end
    end
  end
end
