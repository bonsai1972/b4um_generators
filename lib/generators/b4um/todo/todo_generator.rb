# frozen_string_literal: true

require "rails/generators"
require "rails/generators/named_base"

module B4um
  module Generators
    class TodoGenerator < Rails::Generators::NamedBase
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      class_option :owner,
                   type: :string,
                   default: nil,
                   desc: "Associates tasks with the specified owner model."

      class << self
        def desc(_description = nil)
          "Creates a complete To-Do list with Turbo and Stimulus."
        end
      end

      def validate_owner
        return if options[:owner].nil?

        owner_name = options[:owner].to_s

        return if owner_name.match?(/\A[A-Z][A-Za-z0-9]*\z/)

        raise Thor::Error,
              "Invalid owner model: #{owner_name}"
      end

      def create_todo_migration
        return if todo_migration_exists?

        migration_template(
          "create_tasks.rb.tt",
          "db/migrate/create_#{plural_table_name}.rb"
        )
      end

      def self.next_migration_number(_dirname)
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end

      def create_todo_model
        model_path = "app/models/#{file_path}.rb"

        return if File.exist?(
          File.join(destination_root, model_path)
        )

        template(
          "task.rb.tt",
          model_path
        )
      end

      def update_owner_model
        return unless owner?

        owner_path = "app/models/#{owner_file_name}.rb"

        unless File.exist?(
          File.join(destination_root, owner_path)
        )
          raise Thor::Error,
                "Owner model not found: #{owner_path}"
        end

        association = "has_many :#{plural_table_name}, dependent: :destroy"

        return if File.read(
          File.join(destination_root, owner_path)
        ).include?(association)

        inject_into_class(
          owner_path,
          owner_class_name,
          "  #{association}\n"
        )
      end

      def create_todo_controller
        controller_path = "app/controllers/#{plural_table_name}_controller.rb"

        return if File.exist?(
          File.join(destination_root, controller_path)
        )

        template(
          "tasks_controller.rb.tt",
          controller_path
        )
      end

      def add_todo_routes
        routes_path = "config/routes.rb"

        full_path = File.join(destination_root, routes_path)

        raise Thor::Error, "Routes file not found: #{routes_path}" unless File.exist?(full_path)

        routes_content = File.read(full_path)

        resource_name = plural_table_name

        return if routes_content.match?(
          /^\s*resources\s+:#{Regexp.escape(resource_name)}\b/
        )

        route(
          "resources :#{resource_name}, only: %i[index create update destroy]"
        )
      end

      def create_todo_views
        views_path = "app/views/#{plural_table_name}"

        {
          "index.html.erb.tt" => "index.html.erb",
          "_task.html.erb.tt" => "_task.html.erb",
          "_progress.html.erb.tt" => "_progress.html.erb"
        }.each do |template_name, output_name|
          destination = "#{views_path}/#{output_name}"

          next if File.exist?(
            File.join(destination_root, destination)
          )

          template(template_name, destination)
        end
      end

      def create_todo_stylesheet
        stylesheet_path = "app/assets/stylesheets/b4um_todo.css"

        return if File.exist?(
          File.join(destination_root, stylesheet_path)
        )

        copy_file(
          "todo.css",
          stylesheet_path
        )
      end

      def create_todo_stimulus_controller
        controller_path = "app/javascript/controllers/b4um_todo_controller.js"

        return if File.exist?(
          File.join(destination_root, controller_path)
        )

        copy_file(
          "todo_controller.js",
          controller_path
        )
      end

      private

      def current_owner_method
        "current_#{owner_file_name}"
      end

      def migration_version
        version = Gem.loaded_specs.fetch("railties").version

        "#{version.segments[0]}.#{version.segments[1]}"
      end

      def todo_migration_exists?
        Dir.glob(
          File.join(
            destination_root,
            "db/migrate/*_create_#{plural_table_name}.rb"
          )
        ).any?
      end

      def owner?
        options[:owner].present?
      end

      def owner_class_name
        options[:owner].to_s.camelize
      end

      def owner_file_name
        owner_class_name.underscore
      end

      def owner_reference_name
        owner_file_name
      end
    end
  end
end
