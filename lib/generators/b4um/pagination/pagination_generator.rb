# frozen_string_literal: true

require "rails/generators"
require "rails/generators/named_base"

module B4um
  module Generators
    class PaginationGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      class_option :per_page,
                   type: :numeric,
                   default: 20,
                   desc: "Number of records per page"

      class << self
        def desc(_description = nil)
          "Adds B4UM pagination to an existing resource."
        end
      end

      def validate_model
        return if File.exist?(model_path)

        raise Thor::Error,
              "Model not found: app/models/#{file_name}.rb"
      end

      def validate_controller
        return if File.exist?(controller_path)

        raise Thor::Error,
              "Controller not found: app/controllers/#{plural_table_name}_controller.rb"
      end

      def validate_index_view
        return if File.exist?(index_view_path)

        raise Thor::Error,
              "Index view not found: app/views/#{plural_table_name}/index.html.erb"
      end

      def validate_per_page
        return if options[:per_page].positive?

        raise Thor::Error,
              "--per-page must be greater than 0"
      end

      def create_pagination_concern
        template(
          "pagination.rb",
          "app/controllers/concerns/b4um_pagination.rb"
        )
      end

      def create_pagination_partial
        template(
          "_pagination.html.erb.tt",
          "app/views/shared/_pagination.html.erb"
        )
      end

      def update_controller
        controller_content = File.read(controller_path)

        unless controller_content.include?("include B4umPagination")
          inject_into_class(
            controller_path,
            "#{class_name.pluralize}Controller",
            "  include B4umPagination\n\n"
          )

          controller_content = File.read(controller_path)
        end

        return if controller_content.include?(paginated_collection)

        if controller_content.match?(search_pattern)
          paginate_existing_search
          return
        end

        paginate_plain_collection(controller_content)
      end

      def update_index_view
        index_content = File.read(index_view_path)

        return if index_content.include?('render "shared/pagination"')

        append_to_file(
          index_view_path,
          <<~ERB

            <%= render "shared/pagination", pagination: @pagination %>
          ERB
        )
      end

      private

      def paginated_collection
        "@#{plural_table_name}, @pagination = b4um_paginate("
      end

      def search_pattern
        /
          @#{Regexp.escape(plural_table_name)}\s*=\s*
          b4um_search\(\s*
          #{Regexp.escape(class_name)}\.all,\s*
          params\[:q\]\s*
          \)
        /x
      end

      def paginate_existing_search
        gsub_file(
          controller_path,
          search_pattern,
          [
            "@#{plural_table_name}, @pagination = b4um_paginate(",
            "      b4um_search(",
            "        #{class_name}.all,",
            "        params[:q]",
            "      ),",
            "      per_page: #{options[:per_page]}",
            "    )"
          ].join("\n")
        )
      end

      def paginate_plain_collection(controller_content)
        old_index = "@#{plural_table_name} = #{class_name}.all"

        unless controller_content.include?(old_index)
          raise Thor::Error,
                "Could not find the index collection in app/controllers/#{plural_table_name}_controller.rb"
        end

        gsub_file(
          controller_path,
          old_index,
          [
            "@#{plural_table_name}, @pagination = b4um_paginate(",
            "      #{class_name}.all,",
            "      per_page: #{options[:per_page]}",
            "    )"
          ].join("\n")
        )
      end

      def model_path
        File.join(
          destination_root,
          "app/models",
          "#{file_name}.rb"
        )
      end

      def controller_path
        File.join(
          destination_root,
          "app/controllers",
          "#{plural_table_name}_controller.rb"
        )
      end

      def index_view_path
        File.join(
          destination_root,
          "app/views",
          plural_table_name,
          "index.html.erb"
        )
      end
    end
  end
end
