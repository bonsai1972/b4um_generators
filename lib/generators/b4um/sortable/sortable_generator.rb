# frozen_string_literal: true

require "rails/generators"
require "rails/generators/named_base"

module B4um
  module Generators
    class SortableGenerator < Rails::Generators::NamedBase
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      class_option :path,
                   type: :string,
                   default: nil,
                   desc: "Creates a separate sortable page under the given path."

      class << self
        def desc(_description = nil)
          "Adds sortable positioning to an existing B4UM resource."
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

      def create_position_migration
        return if position_column_exists?

        migration_template(
          "add_position_migration.rb.tt",
          "db/migrate/add_position_to_#{plural_table_name}.rb"
        )
      end

      def update_model
        model_content = File.read(model_path)

        return if model_content.include?("before_create :b4um_set_sortable_position")

        inject_into_class(
          model_path,
          class_name,
          <<~RUBY.indent(2)
            before_create :b4um_set_sortable_position
            after_destroy :b4um_compact_sortable_positions

            def b4um_set_sortable_position
              return if position.present?

              self.position = self.class.maximum(:position).to_i + 1
            end

            def b4um_compact_sortable_positions
              self.class
                  .where("position > ?", position)
                  .update_all("position = position - 1")
            end
          RUBY
        )

        say_status(
          :sortable,
          "#{class_name} now assigns sortable positions",
          :green
        )
      end

      def update_controller
        controller_content = File.read(controller_path)

        update_index_order(controller_content)
        add_sort_action
      end

      def add_sort_route
        routes_path = File.join(
          destination_root,
          "config/routes.rb"
        )

        unless File.exist?(routes_path)
          raise Thor::Error,
                "Routes not found: config/routes.rb"
        end

        routes = File.read(routes_path)

        if options[:path].present?
          add_separate_sort_routes(routes)
          return
        end

        return if sort_route_exists?(routes)
        return if separate_sort_route_exists?(routes)

        add_sort_route_to_resources(routes)
      end

      def create_sortable_controller
        copy_file(
          File.expand_path(
            "templates/sortable_controller.js",
            __dir__
          ),
          "app/javascript/controllers/sortable_controller.js"
        )
      end

      def create_sortable_partial
        template(
          "_sortable.html.erb.tt",
          File.join(
            "app/views",
            plural_table_name,
            "_sortable.html.erb"
          )
        )
      end

      def create_sortable_view
        return unless options[:path].present?

        template(
          "sort.html.erb.tt",
          File.join(
            "app/views",
            plural_table_name,
            "sort.html.erb"
          )
        )
      end

      def update_index_layout
        return unless File.exist?(index_path)

        index = File.read(index_path)

        if options[:path].present?
          restore_index_layout(index)
        else
          use_sortable_index_layout(index)
        end
      end

      def self.next_migration_number(_dirname)
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end

      private

      def use_sortable_index_layout(index)
        updated_index = index.sub(
          /render\s+["'](?:bento|table|list|alternating|sortable)["']/,
          'render "sortable"'
        )

        return if updated_index == index

        File.write(index_path, updated_index)
      end

      def restore_index_layout(index)
        return unless index.match?(
          /render\s+["']sortable["']/
        )

        layout = original_index_layout

        return unless layout

        updated_index = index.sub(
          /render\s+["']sortable["']/,
          %(render "#{layout}")
        )

        File.write(index_path, updated_index)
      end

      def original_index_layout
        %w[bento table list alternating].find do |layout|
          File.exist?(
            File.join(
              destination_root,
              "app/views",
              plural_table_name,
              "_#{layout}.html.erb"
            )
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

      def update_index_order(controller_content)
        return if controller_content.include?(
          "#{class_name}.order(:position, :id)"
        )

        old_scope = "#{class_name}.all"

        unless controller_content.include?(old_scope)
          raise Thor::Error,
                "Could not find #{class_name}.all in app/controllers/#{plural_table_name}_controller.rb"
        end

        gsub_file(
          controller_path,
          old_scope,
          "#{class_name}.order(:position, :id)"
        )
      end

      def add_sort_action
        controller_content = File.read(controller_path)

        if controller_content.match?(/^\s*def\s+sort\b/)
          add_sort_page_support(controller_content)
          return
        end

        get_handling =
          if options[:path].present?
            <<~RUBY
              if request.get?
                @#{plural_table_name} = #{class_name}.order(:position, :id)
                return
              end

            RUBY
          else
            ""
          end

        action = <<~RUBY.indent(2)
          def sort
          #{get_handling.indent(2)}  record = #{class_name}.find_by(id: params[:id])
            target_position = params[:position].to_i
            maximum_position = #{class_name}.count

            unless record &&
                   target_position.between?(1, maximum_position)
              head :unprocessable_content
              return
            end

            if target_position == record.position
              head :no_content
              return
            end

            old_position = record.position

            #{class_name}.transaction do
              if target_position < old_position
                #{class_name}
                  .where(position: target_position...old_position)
                  .where.not(id: record.id)
                  .update_all("position = position + 1")
              elsif target_position > old_position
                #{class_name}
                  .where(position: (old_position + 1)..target_position)
                  .where.not(id: record.id)
                  .update_all("position = position - 1")
              end

              record.update_columns(
                position: target_position,
                updated_at: Time.current
              )
            end

            head :no_content
          end

        RUBY

        private_marker = "\n  private\n"

        if controller_content.include?(private_marker)
          insert_into_file(
            controller_path,
            action,
            before: private_marker
          )
        else
          controller_end = /\nend\s*\z/

          unless controller_content.match?(controller_end)
            raise Thor::Error,
                  "Could not find the end of app/controllers/#{plural_table_name}_controller.rb"
          end

          insert_into_file(
            controller_path,
            "\n#{action}",
            before: controller_end
          )
        end
      end

      def add_sort_page_support(controller_content)
        return unless options[:path].present?
        return if controller_content.include?("if request.get?")

        sort_action =
          /^(\s*)def sort\s*$/

        unless controller_content.match?(sort_action)
          raise Thor::Error,
                "Could not find sort action in app/controllers/#{plural_table_name}_controller.rb"
        end

        gsub_file(
          controller_path,
          sort_action
        ) do |match|
          indentation = match[/\A\s*/]

          <<~RUBY.chomp
            #{match}
            #{indentation}  if request.get?
            #{indentation}    @#{plural_table_name} = #{class_name}.order(:position, :id)
            #{indentation}    return
            #{indentation}  end
          RUBY
        end
      end

      def add_separate_sort_routes(routes)
        path = options[:path].to_s

        remove_default_sort_route(routes)

        routes = File.read(
          File.join(
            destination_root,
            "config/routes.rb"
          )
        )

        get_route =
          %(get "#{path}", to: "#{plural_table_name}#sort")

        patch_route =
          %(patch "#{path}", to: "#{plural_table_name}#sort", as: :sort_#{plural_table_name})

        routes_to_add = []

        routes_to_add << get_route unless routes.include?(get_route)

        routes_to_add << patch_route unless routes.include?(patch_route)

        return if routes_to_add.empty?

        routes_end = /^end\s*\z/

        unless routes.match?(routes_end)
          raise Thor::Error,
                "Could not find the end of config/routes.rb"
        end

        route_code = <<~RUBY

          #{routes_to_add.join("\n  ")}
        RUBY

        insert_into_file(
          "config/routes.rb",
          route_code,
          before: routes_end
        )
      end

      def remove_default_sort_route(routes)
        return unless sort_route_exists?(routes)

        gsub_file(
          "config/routes.rb",
          /^(\s*)patch :sort, on: :collection\s*\n/,
          ""
        )
      end

      def sort_route_exists?(routes)
        resource_block = sortable_resource_block(routes)

        resource_block&.match?(
          /^\s*patch\s+:sort,\s+on:\s+:collection\s*$/
        ) || false
      end

      def separate_sort_route_exists?(routes)
        routes.match?(
          /^\s*patch\s+["'][^"']+["'],\s+to:\s+["']#{Regexp.escape(plural_table_name)}#sort["']/
        )
      end

      def sortable_resource_block(routes)
        pattern = /
          ^(?<indent>\s*)
          resources\s+:#{Regexp.escape(plural_table_name)}\s+do\s*$
          (?<body>.*?)
          ^\k<indent>end\s*$
        /mx

        routes[pattern]
      end

      def add_sort_route_to_resources(routes)
        block_pattern =
          /^(\s*)resources :#{Regexp.escape(plural_table_name)} do\s*$/

        plain_pattern =
          /^(\s*)resources :#{Regexp.escape(plural_table_name)}\s*$/

        if routes.match?(block_pattern)
          gsub_file(
            "config/routes.rb",
            block_pattern
          ) do |match|
            indentation = match[/\A\s*/]

            [
              match,
              "#{indentation}  patch :sort, on: :collection"
            ].join("\n")
          end
        elsif routes.match?(plain_pattern)
          gsub_file(
            "config/routes.rb",
            plain_pattern
          ) do |match|
            indentation = match[/\A\s*/]

            [
              "#{indentation}resources :#{plural_table_name} do",
              "#{indentation}  patch :sort, on: :collection",
              "#{indentation}end"
            ].join("\n")
          end
        else
          raise Thor::Error,
                "Could not find resources :#{plural_table_name} in config/routes.rb"
        end
      end

      def position_column_exists?
        migration_contains_position? ||
          schema_contains_position?
      end

      def migration_contains_position?
        Dir.glob(
          File.join(
            destination_root,
            "db/migrate/*_add_position_to_#{plural_table_name}.rb"
          )
        ).any?
      end

      def schema_contains_position?
        schema_path = File.join(destination_root, "db/schema.rb")

        return false unless File.exist?(schema_path)

        schema = File.read(schema_path)

        table_pattern = /
          create_table\s+"#{Regexp.escape(plural_table_name)}".*?^  end
        /mx

        table = schema[table_pattern]

        table&.match?(/t\.integer\s+"position"/) || false
      end
    end
  end
end
