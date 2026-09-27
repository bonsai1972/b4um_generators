# frozen_string_literal: true

require "rails/generators"
require "rails/generators/named_base"

module B4um
  module Generators
    class ReadableGenerator < Rails::Generators::NamedBase
      argument :attribute,
               type: :string,
               required: true,
               banner: "ATTRIBUTE"

      class << self
        def desc(_description = nil)
          "Adds a readable URL parameter to an existing model."
        end
      end

      def validate_model
        return if File.exist?(model_path)

        raise Thor::Error,
              "Model not found: app/models/#{file_name}.rb"
      end

      def validate_attribute
        return if model_class.column_names.include?(attribute)

        raise Thor::Error,
              "Attribute not found: #{class_name}##{attribute}"
      end

      def add_readable_param
        model_content = File.read(model_path)

        if model_content.match?(/^\s*def\s+to_param\b/)
          raise Thor::Error,
                "#{class_name} already defines to_param."
        end

        inject_into_class(
          model_path,
          class_name,
          <<~RUBY
            def to_param
              "\#{id} \#{#{attribute}}".parameterize
            end
          RUBY
        )

        say_status(
          :readable,
          "#{class_name} URLs now use #{attribute}",
          :green
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

      def model_class
        class_name.constantize
      rescue NameError
        raise Thor::Error,
              "Could not load model: #{class_name}"
      end
    end
  end
end
