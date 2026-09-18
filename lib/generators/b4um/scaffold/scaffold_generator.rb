# frozen_string_literal: true

require "rails/generators"
require "rails/generators/rails/scaffold/scaffold_generator"

module B4um
  module Generators
    class ScaffoldGenerator < Rails::Generators::ScaffoldGenerator
      source_root File.expand_path("templates", __dir__)

      class << self
        def desc(_description = nil)
          "Generates a B4UM scaffold."
        end
      end

      def create_b4um_form
        form_path = File.join(
          "app/views",
          plural_table_name,
          "_form.html.erb"
        )

        remove_file form_path

        template(
          "_form.html.erb.tt",
          form_path
        )
      end

      def create_b4um_resource
        resource_path = File.join(
          "app/views",
          plural_table_name,
          "_#{singular_table_name}.html.erb"
        )

        remove_file resource_path

        template(
          "_resource.html.erb.tt",
          resource_path
        )
      end

      def create_b4um_index
        index_path = File.join(
          "app/views",
          plural_table_name,
          "index.html.erb"
        )

        remove_file index_path

        template(
          "index.html.erb.tt",
          index_path
        )
      end

      def create_b4um_show
        show_path = File.join(
          "app/views",
          plural_table_name,
          "show.html.erb"
        )

        remove_file show_path

        template(
          "show.html.erb.tt",
          show_path
        )
      end

      def create_b4um_new
        new_path = File.join(
          "app/views",
          plural_table_name,
          "new.html.erb"
        )

        remove_file new_path

        template(
          "new.html.erb.tt",
          new_path
        )
      end

      def create_b4um_edit
        edit_path = File.join(
          "app/views",
          plural_table_name,
          "edit.html.erb"
        )

        remove_file edit_path

        template(
          "edit.html.erb.tt",
          edit_path
        )
      end

      def add_secure_password
        return unless attributes.any? { |attribute| attribute.name == "password_digest" }

        inject_into_class(
          File.join("app/models", "#{singular_table_name}.rb"),
          class_name,
          "  has_secure_password\n"
        )
      end

      def add_bcrypt
        return unless attributes.any? { |attribute| attribute.name == "password_digest" }

        gemfile_path = "Gemfile"
        gemfile = File.read(gemfile_path)

        if gemfile.match?(/^#\s*gem ["']bcrypt["']/)
          uncomment_lines gemfile_path, /gem ["']bcrypt["']/
        elsif !gemfile.match?(/^gem ["']bcrypt["']/)
          gem "bcrypt", "~> 3.1"
        end
      end

      def update_password_params
        return unless attributes.any? { |attribute| attribute.name == "password_digest" }

        controller_path = File.join(
          "app/controllers",
          "#{plural_table_name}_controller.rb"
        )

        gsub_file(
          controller_path,
          ":password_digest",
          ":password, :password_confirmation"
        )
      end
    end
  end
end
