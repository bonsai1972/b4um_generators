# frozen_string_literal: true

require "rails/generators"
require "rails/generators/named_base"

module B4um
  module Generators
    class TableGenerator < Rails::Generators::NamedBase
      TableAttribute = Data.define(:name, :type)
      source_root File.expand_path("templates", __dir__)

      argument :fields,
               type: :array,
               default: [],
               banner: "field:type field:type"

      class << self
        def desc(_description = nil)
          "Generates a B4UM table partial for an existing model."
        end
      end

      def validate_model
        return if File.exist?(model_path)

        raise Thor::Error,
              "Model not found: app/models/#{file_name}.rb"
      end

      def create_table_partial
        template(
          "_table.html.erb.tt",
          File.join(
            "app/views",
            plural_table_name,
            "_table.html.erb"
          )
        )
      end

      private

      def table_attributes
        fields.map do |field|
          name, type = field.split(":", 2)

          TableAttribute.new(
            name,
            (type || "string").to_sym
          )
        end
      end

      def model_path
        File.join(
          destination_root,
          "app/models",
          "#{file_name}.rb"
        )
      end
    end
  end
end
