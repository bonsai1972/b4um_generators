# frozen_string_literal: true

require "rails/generators"
require "rails/generators/named_base"

module B4um
  module Generators
    class BentoGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      class_option :layout,
                   type: :string,
                   default: "grid",
                   enum: %w[bento grid list alternating],
                   desc: "Layout: bento, grid, list, or alternating"

      class << self
        def desc(_description = nil)
          "Generates a B4UM Bento partial for an existing model."
        end
      end

      def validate_model
        return if File.exist?(model_path)

        raise Thor::Error,
              "Model not found: app/models/#{file_name}.rb"
      end

      def validate_resource_partial
        return if File.exist?(resource_partial_path)

        raise Thor::Error,
              "Resource partial not found: app/views/#{plural_table_name}/_#{file_name}.html.erb"
      end

      def create_bento_partial
        template(
          template_name,
          File.join(
            "app/views",
            plural_table_name,
            "_bento.html.erb"
          )
        )
      end

      private

      def model_path
        File.join(
          destination_root,
          "app/models",
          "#{file_name}.rb"
        )
      end

      def resource_partial_path
        File.join(
          destination_root,
          "app/views",
          plural_table_name,
          "_#{file_name}.html.erb"
        )
      end

      def template_name
        case options[:layout]
        when "grid"
          "_grid.html.erb.tt"
        when "list"
          "_list.html.erb.tt"
        when "alternating"
          "_alternating.html.erb.tt"
        else
          "_bento.html.erb.tt"
        end
      end
    end
  end
end
