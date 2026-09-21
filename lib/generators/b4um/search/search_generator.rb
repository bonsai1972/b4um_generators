# frozen_string_literal: true

require "rails/generators"
require "erb"

module B4um
  module Generators
    class SearchGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      class << self
        def desc(_description = nil)
          "Adds B4UM search to an existing resource."
        end
      end

      def validate_model
        return if File.exist?(
          File.join(destination_root, model_path)
        )

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

      def create_search_concern
        template(
          "search.rb",
          "app/controllers/concerns/b4um_search.rb"
        )
      end

      def update_controller
        controller_content = File.read(
          File.join(destination_root, controller_path)
        )

        return if controller_content.include?("include B4umSearch")

        inject_into_class(
          controller_path,
          "#{class_name.pluralize}Controller",
          "  include B4umSearch\n\n"
        )
      end

      def update_index_action
        controller_file = File.join(
          destination_root,
          controller_path
        )

        controller_content = File.read(controller_file)

        search_pattern = /
  b4um_search\(\s*
  #{Regexp.escape(class_name)}\.all,\s*
  params\[:q\]\s*
  \)
/x

        return if controller_content.match?(search_pattern)

        pagination_pattern = /
          (@#{file_name.pluralize},\s*@pagination\s*=\s*b4um_paginate\(\s*)
          #{Regexp.escape(class_name)}\.all
          (\s*,)
        /x

        if controller_content.match?(pagination_pattern)
          gsub_file(
            controller_path,
            pagination_pattern,
            "\\1b4um_search(#{class_name}.all, params[:q])\\2"
          )

          return
        end

        old_index = "@#{file_name.pluralize} = #{class_name}.all"

        unless controller_content.include?(old_index)
          raise Thor::Error,
                "Could not find the index collection in #{controller_path}"
        end

        search_code = <<~RUBY.chomp
          @#{file_name.pluralize} = b4um_search(
            #{class_name}.all,
            params[:q]
          )
        RUBY

        gsub_file(
          controller_path,
          old_index,
          search_code
        )
      end

      def update_index_view
        view_content = File.read(
          File.join(destination_root, index_view_path)
        )

        return if view_content.include?(
          'class="b4um-search"'
        )

        template_content = ERB.new(
          File.read(
            File.join(
              self.class.source_root,
              "search_form.html.erb.tt"
            )
          )
        ).result(binding)

        prepend_to_file(
          index_view_path,
          "#{template_content}\n"
        )
      end

      private

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
