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
    end
  end
end
