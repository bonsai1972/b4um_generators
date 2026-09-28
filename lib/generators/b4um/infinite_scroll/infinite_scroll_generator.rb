# frozen_string_literal: true

require "rails/generators"

module B4um
  module Generators
    class InfiniteScrollGenerator < Rails::Generators::NamedBase
      source_root File.expand_path(
        "../pagination/templates",
        __dir__
      )

      class_option :per_page,
                   type: :numeric,
                   default: 20,
                   desc: "Number of records loaded per page"

      class << self
        def desc(_description = nil)
          "Adds B4UM infinite scroll to an existing resource."
        end
      end

      def validate_per_page
        return if options[:per_page].positive?

        raise Thor::Error, "--per-page must be greater than 0"
      end

      def validate_model
        return if File.exist?(File.join(destination_root, model_path))

        raise Thor::Error, "Model not found: #{model_path}"
      end

      def validate_controller
        return if File.exist?(
          File.join(destination_root, controller_path)
        )

        raise Thor::Error, "Controller not found: #{controller_path}"
      end

      def validate_index_view
        return if File.exist?(
          File.join(destination_root, index_view_path)
        )

        raise Thor::Error, "Index view not found: #{index_view_path}"
      end

      def create_pagination_concern
        template(
          "pagination.rb",
          "app/controllers/concerns/b4um_pagination.rb"
        )
      end

      def create_infinite_scroll_controller
        copy_file(
          File.expand_path(
            "templates/infinite_scroll_controller.js",
            __dir__
          ),
          "app/javascript/controllers/infinite_scroll_controller.js"
        )
      end

      def update_controller
        controller_content = File.read(
          File.join(destination_root, controller_path)
        )

        unless controller_content.include?("include B4umPagination")
          inject_into_class(
            controller_path,
            "#{class_name.pluralize}Controller",
            "  include B4umPagination\n\n"
          )

          controller_content = File.read(
            File.join(destination_root, controller_path)
          )
        end

        return if controller_content.include?(paginated_collection)

        if controller_content.match?(search_pattern)
          paginate_existing_search
          return
        end

        paginate_plain_collection(controller_content)
      end

      def update_index_view
        gsub_file(
          index_view_path,
          %r{\n*<%=\s*render\s+"shared/pagination",\s*pagination:\s*@pagination\s*%>\n*},
          "\n"
        )

        index_content = File.read(
          File.join(destination_root, index_view_path)
        )

        return if index_content.include?(
          'data-controller="infinite-scroll"'
        )

        append_to_file(
          index_view_path,
          <<~ERB

            <div
              data-controller="infinite-scroll"
              data-infinite-scroll-container-value="#{plural_table_name}"
              data-infinite-scroll-next-url-value="<%= url_for(request.query_parameters.merge(page: @pagination.next_page)) if @pagination.next_page %>"
            ></div>
          ERB
        )
      end

      def update_table_partial
        index_content = File.read(
          File.join(destination_root, index_view_path)
        )

        return unless index_content.match?(
          /render\s+["']table["']/
        )

        path = File.join(
          "app/views",
          file_name.pluralize,
          "_table.html.erb"
        )

        full_path = File.join(destination_root, path)

        return unless File.exist?(full_path)

        content = File.read(full_path)

        return if content.include?(%(<tbody id="#{plural_table_name}">))
        return unless content.include?("<tbody>")

        gsub_file(
          path,
          "<tbody>",
          %(<tbody id="#{plural_table_name}">)
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
          "app/models",
          "#{file_name}.rb"
        )
      end

      def controller_path
        File.join(
          "app/controllers",
          "#{file_name.pluralize}_controller.rb"
        )
      end

      def index_view_path
        File.join(
          "app/views",
          file_name.pluralize,
          "index.html.erb"
        )
      end
    end
  end
end
