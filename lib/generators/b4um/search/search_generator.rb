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

        plain_collection = "#{class_name}.all"
        sortable_collection = "#{class_name}.order(:position, :id)"

        collection =
          if controller_content.include?(
            "@#{file_name.pluralize} = #{sortable_collection}"
          )
            sortable_collection
          elsif controller_content.include?(
            "@#{file_name.pluralize} = #{plain_collection}"
          )
            plain_collection
          end

        unless collection
          raise Thor::Error,
                "Could not find the index collection in #{controller_path}"
        end

        old_index = "@#{file_name.pluralize} = #{collection}"

        search_code = [
          "@#{file_name.pluralize} = b4um_search(",
          "      #{collection},",
          "      params[:q]",
          "    )"
        ].join("\n")

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

      def update_empty_state
        view_file = File.join(
          destination_root,
          index_view_path
        )

        view_content = File.read(view_file)

        return if view_content.include?(
          "<% if params[:q].present? %>"
        )

        title = file_name.pluralize.humanize.downcase
        singular = file_name.humanize.downcase

        empty_state_pattern = %r{
          (?<indent>[ \t]*)
          <section\ class="b4um-empty-state">\s*
          <h2\ class="b4um-empty-state__title">\s*
          No\ #{Regexp.escape(title)}\ yet\.\s*
          </h2>\s*
          <p\ class="b4um-empty-state__text">\s*
          Create\ your\ first\ #{Regexp.escape(singular)}\ to\ get\ started\.\s*
          </p>\s*
          </section>
        }x

        return unless view_content.match?(empty_state_pattern)

        new_empty_state = <<~ERB.chomp
          <section class="b4um-empty-state">
            <% if params[:q].present? %>
              <h2 class="b4um-empty-state__title">
                No #{title} found.
              </h2>

              <p class="b4um-empty-state__text">
                Try a different search term.
              </p>
            <% else %>
              <h2 class="b4um-empty-state__title">
                No #{title} yet.
              </h2>

              <p class="b4um-empty-state__text">
                Create your first #{singular} to get started.
              </p>
            <% end %>
          </section>
        ERB

        gsub_file(
          index_view_path,
          empty_state_pattern,
          new_empty_state
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
