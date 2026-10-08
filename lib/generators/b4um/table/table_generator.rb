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

      class_option :select,
                   type: :string,
                   desc: "Renders a field as a select value. Example: status:Active=Aktiv,Inactive=Inaktiv"

      class_option :radio,
                   type: :string,
                   desc: "Renders a field as a radio value. Example: condition:new=Neu,used=Gebraucht"

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

      def validate_editor_configurations
        configurations = {
          select: select_configuration,
          radio: radio_configuration
        }

        configurations.each do |option_name, configuration|
          validate_editor_configuration(
            option_name,
            configuration
          )
        end

        validate_editor_configuration_conflict(configurations)
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

      def update_index_layout
        return unless File.exist?(index_path)

        index = File.read(index_path)

        updated_index = index.sub(
          /render\s+["'](?:bento|table|list|alternating)["']/,
          'render "table"'
        )

        return if updated_index == index

        File.write(index_path, updated_index)
      end

      private

      def model_class
        class_name.constantize
      end

      def database_columns
        model_class.columns.index_by(&:name)
      end

      def rich_text_fields
        model_class.reflect_on_all_associations(:has_one)
                   .filter_map do |association|
                     association.name.to_s.delete_prefix("rich_text_") if
                       association.name.to_s.start_with?("rich_text_")
                   end
      end

      def single_attachment_fields
        model_class.reflect_on_all_attachments
                   .select { |reflection| reflection.macro == :has_one_attached }
                   .map { |reflection| reflection.name.to_s }
      end

      def multiple_attachment_fields
        model_class.reflect_on_all_attachments
                   .select { |reflection| reflection.macro == :has_many_attached }
                   .map { |reflection| reflection.name.to_s }
      end

      def available_field_names
        (
          database_field_names +
          rich_text_fields +
          single_attachment_fields +
          multiple_attachment_fields
        ).uniq
      end

      def database_field_names
        database_columns.keys - %w[id created_at updated_at]
      end

      def field_type(field)
        return :rich_text if rich_text_fields.include?(field)
        return :attachment if single_attachment_fields.include?(field)
        return :attachments if multiple_attachment_fields.include?(field)

        database_columns.fetch(field).type
      end

      def table_field_names
        return available_field_names if fields.empty?

        fields.map { |field| field.split(":", 2).first }
      end

      def validate_editor_configuration(option_name, configuration)
        return unless options[option_name].present?

        unless configuration
          raise Thor::Error,
                "Invalid --#{option_name} configuration. " \
                "Expected FIELD:VALUE[,VALUE...]"
        end

        return if table_field_names.include?(configuration[:field])

        raise Thor::Error,
              "--#{option_name} field #{configuration[:field]} " \
              "must be one of the generated fields: #{fields.join(", ")}"
      end

      def validate_editor_configuration_conflict(configurations)
        select = configurations[:select]
        radio = configurations[:radio]

        return unless select && radio
        return unless select[:field] == radio[:field]

        raise Thor::Error,
              "Field #{select[:field]} cannot use both --select and --radio"
      end

      def select_configuration
        field_configuration(:select)
      end

      def radio_configuration
        field_configuration(:radio)
      end

      def field_configuration(option_name)
        value = options[option_name]
        return unless value.present?

        field, values = value.split(":", 2)

        return unless field.present? && values.present?

        choices = field_choices(values)
        return if choices.empty?

        {
          field: field,
          values: choices
        }
      end

      def field_choices(values)
        values.split(",").filter_map do |choice|
          value, label = choice.strip.split("=", 2)

          next if value.blank?

          {
            value: value,
            label: label.presence || value
          }
        end
      end

      def select_field?(field)
        configuration = select_configuration

        configuration &&
          configuration[:field] == field &&
          configuration[:values].any?
      end

      def radio_field?(field)
        configuration = radio_configuration

        configuration &&
          configuration[:field] == field &&
          configuration[:values].any?
      end

      def table_attributes
        table_field_names.map do |field|
          TableAttribute.new(
            field,
            field_type(field)
          )
        end
      end

      def index_path
        File.join(
          destination_root,
          "app/views",
          plural_table_name,
          "index.html.erb"
        )
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
