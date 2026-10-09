# frozen_string_literal: true

require "rails/generators"
require "rails/generators/named_base"

module B4um
  module Generators
    class InPlaceGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      argument :fields,
               type: :array,
               required: true,
               banner: "FIELD [FIELD ...]"

      class_option :select,
                   type: :string,
                   desc: "Renders a field as a select list. Example: status:Active=Aktiv,Inactive=Inaktiv"

      class_option :radio,
                   type: :string,
                   desc: "Renders a field as radio buttons. Example: condition:new=Neu,used=Gebraucht"

      class << self
        def desc(_description = nil)
          "Adds B4UM in-place editing to an existing resource."
        end
      end

      def validate_model
        return if File.exist?(model_path)

        raise Thor::Error,
              "Model not found: app/models/#{file_name}.rb"
      end

      def validate_fields
        fields.each do |field|
          next if available_field_names.include?(field)

          raise Thor::Error,
                "Field #{field} was not found on #{class_name}."
        end
      end

      def validate_editor_options
        configurations = {
          select: select_configuration,
          radio: radio_configuration
        }

        configurations.each do |option_name, configuration|
          validate_editor_configuration(option_name, configuration)
        end

        validate_editor_configuration_conflict(configurations)
      end

      def ensure_flash_support
        flash_path = "app/views/shared/_flash.html.erb"
        full_flash_path = File.join(destination_root, flash_path)

        unless File.exist?(full_flash_path)
          copy_file(
            "_flash.html.erb",
            flash_path
          )
        end

        ensure_flash_render_in_layout
      end

      def create_in_place_helper
        helper_path = "app/helpers/b4um_in_place_helper.rb"
        full_helper_path = File.join(destination_root, helper_path)

        unless File.exist?(full_helper_path)
          template(
            "b4um_in_place_helper.rb",
            helper_path
          )
        end

        return unless authentication_installed?

        helper = File.read(full_helper_path)

        return if helper.include?(
          "def b4um_in_place_editing_allowed?\n    logged_in?"
        )

        gsub_file(
          helper_path,
          "def b4um_in_place_editing_allowed?\n    true",
          "def b4um_in_place_editing_allowed?\n    logged_in?"
        )
      end

      def create_in_place_controller
        copy_file(
          "in_place_controller.js",
          "app/javascript/controllers/in_place_controller.js"
        )
      end

      def create_in_place_styles
        copy_file(
          "in_place.css",
          "app/assets/stylesheets/b4um/in_place.css"
        )
      end

      def add_in_place_routes
        fields.each do |field|
          add_in_place_route(field)
        end
      end

      def add_in_place_fields_constant
        controller_path = File.join(
          "app/controllers",
          "#{plural_table_name}_controller.rb"
        )

        full_controller_path = File.join(
          destination_root,
          controller_path
        )

        controller = File.read(full_controller_path)

        if controller.include?("IN_PLACE_FIELDS = %w[")
          add_fields_to_existing_constant(controller_path, controller)
        else
          create_in_place_fields_constant(controller_path)
        end
      end

      def add_edit_actions
        fields.each do |field|
          add_edit_action(field)
        end
      end

      def add_edit_actions_to_set_product
        fields.each do |field|
          add_edit_action_to_set_product(field)
        end
      end

      def create_edit_views
        fields.each do |field|
          create_edit_view(field)
        end
      end

      def create_display_partials
        fields.each do |field|
          create_display_partial(field)
        end
      end

      def integrate_display_partials
        fields.each do |field|
          integrate_display_partial(field)
        end
      end

      def add_in_place_params
        fields.each do |field|
          add_in_place_params_for(field)
        end
      end

      def add_update_integration
        add_in_place_update_integration
      end

      def report_fields
        fields.each do |field|
          say_status(
            :in_place,
            "#{class_name}##{field} (#{field_type(field)})",
            :green
          )
        end
      end

      def protect_in_place_actions
        return unless authentication_installed?

        controller_path = File.join(
          "app/controllers",
          "#{plural_table_name}_controller.rb"
        )

        full_controller_path = File.join(
          destination_root,
          controller_path
        )

        controller = File.read(full_controller_path)

        callback =
          "before_action :require_login, except: [:index, :show]"

        return if controller.include?(callback)

        inject_into_file(
          controller_path,
          after: /^class .*Controller < ApplicationController\s*$/
        ) do
          "\n  #{callback}"
        end
      end

      private

      def ensure_flash_render_in_layout
        layout_path = "app/views/layouts/application.html.erb"
        full_layout_path = File.join(destination_root, layout_path)

        return unless File.exist?(full_layout_path)

        layout = File.read(full_layout_path)

        return if layout.include?('render "shared/flash"')

        flash_pattern = /
          \s*<%\s+flash\.each\s+do\s+\|type,\s*message\|\s*%>
          .*?
          <%\s+end\s+%>
        /mx

        return unless layout.match?(flash_pattern)

        gsub_file(
          layout_path,
          flash_pattern,
          "\n  <%= render \"shared/flash\" %>"
        )
      end

      def validate_editor_configuration(option_name, configuration)
        return unless options[option_name].present?

        unless configuration
          raise Thor::Error,
                "Invalid --#{option_name} configuration. " \
                "Expected FIELD:VALUE[,VALUE...]"
        end

        return if fields.include?(configuration[:field])

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

      def model_path
        File.join(
          destination_root,
          "app/models",
          "#{file_name}.rb"
        )
      end

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
          database_columns.keys +
          rich_text_fields +
          single_attachment_fields +
          multiple_attachment_fields
        ).uniq
      end

      def field_type(field)
        return :rich_text if rich_text_fields.include?(field)
        return :attachment if single_attachment_fields.include?(field)
        return :attachments if multiple_attachment_fields.include?(field)

        database_columns.fetch(field).type
      end

      def select_configuration
        editor_configuration(:select)
      end

      def radio_configuration
        editor_configuration(:radio)
      end

      def editor_configuration(option_name)
        value = options[option_name]
        return unless value.present?

        field, values = value.split(":", 2)

        return unless field.present? && values.present?

        choices = editor_choices(values)
        return if choices.empty?

        {
          field: field,
          values: choices
        }
      end

      def editor_choices(values)
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

      def editor_type(field)
        configured_editor_type(field) || default_editor_type(field)
      end

      def configured_editor_type(field)
        return :radio if radio_field?(field)
        return :select if select_field?(field)

        nil
      end

      def default_editor_type(field)
        {
          rich_text: :rich_text,
          attachment: :attachment,
          attachments: :attachments,
          boolean: :boolean,
          integer: :number,
          float: :number,
          decimal: :number
        }.fetch(field_type(field), :text)
      end

      def authentication_installed?
        application_controller = File.join(
          destination_root,
          "app/controllers/application_controller.rb"
        )

        return false unless File.exist?(application_controller)

        File.read(application_controller).include?(
          "helper_method :current_"
        ) &&
          File.read(application_controller).include?(
            ":logged_in?"
          )
      end

      def add_in_place_route(field)
        routes_path = "config/routes.rb"
        full_routes_path = File.join(destination_root, routes_path)
        routes = File.read(full_routes_path)
        route = "get :edit_#{field}"

        return if route_exists_for_resource?(routes, route)

        add_route_to_resources(routes_path, routes, route)
      end

      def route_exists_for_resource?(routes, route)
        member_match = routes.match(resources_with_member_pattern)

        if member_match
          start_index = member_match.begin(0)
          indentation = member_match[1]

          resource_block = routes[
            start_index..
          ][
            /\A.*?^#{Regexp.escape(indentation)}end\s*$/m,
            0
          ]

          return resource_block&.include?(route)
        end

        false
      end

      def add_route_to_resources(routes_path, routes, route)
        if routes.match?(resources_with_member_pattern)
          add_route_to_member_block(routes_path, route)
        elsif routes.match?(resources_block_pattern)
          add_member_block(routes_path, route)
        elsif routes.match?(plain_resources_pattern)
          convert_plain_resources(routes_path, route)
        else
          raise Thor::Error,
                "Could not find resources :#{plural_table_name} in config/routes.rb"
        end
      end

      def resources_with_member_pattern
        /
          ^(\s*)resources\ :#{Regexp.escape(plural_table_name)}\ do\n
          \1\ \ member\ do\n
        /x
      end

      def resources_block_pattern
        /^(\s*)resources :#{Regexp.escape(plural_table_name)} do\n/
      end

      def plain_resources_pattern
        /^(\s*)resources :#{Regexp.escape(plural_table_name)}\s*$/
      end

      def add_route_to_member_block(routes_path, route)
        gsub_file(
          routes_path,
          resources_with_member_pattern
        ) do |match|
          indentation = match[/\A\s*/]

          "#{match}#{indentation}    #{route}\n"
        end
      end

      def add_member_block(routes_path, route)
        gsub_file(
          routes_path,
          resources_block_pattern
        ) do |match|
          indentation = match[/\A\s*/]

          [
            match.chomp,
            "#{indentation}  member do",
            "#{indentation}    #{route}",
            "#{indentation}  end",
            ""
          ].join("\n")
        end
      end

      def convert_plain_resources(routes_path, route)
        gsub_file(
          routes_path,
          plain_resources_pattern
        ) do |match|
          indentation = match[/\A\s*/]

          [
            "#{indentation}resources :#{plural_table_name} do",
            "#{indentation}  member do",
            "#{indentation}    #{route}",
            "#{indentation}  end",
            "#{indentation}end"
          ].join("\n")
        end
      end

      def create_in_place_fields_constant(controller_path)
        lines = fields.map do |field|
          "    #{field}"
        end.join("\n")

        inject_into_file(
          controller_path,
          after: /^class .*Controller < ApplicationController\s*$/
        ) do
          <<~RUBY

              IN_PLACE_FIELDS = %w[
            #{lines}
              ].freeze
          RUBY
        end
      end

      def add_fields_to_existing_constant(controller_path, controller)
        fields.each do |field|
          next if in_place_field_defined?(controller, field)

          inject_into_file(
            controller_path,
            before: /^\s*\]\.freeze\s*$/
          ) do
            "    #{field}\n"
          end

          controller = File.read(
            File.join(destination_root, controller_path)
          )
        end
      end

      def in_place_field_defined?(controller, field)
        constant = controller[
          /IN_PLACE_FIELDS = %w\[(.*?)\]\.freeze/m,
          1
        ]

        return false unless constant

        constant.split.include?(field)
      end

      def add_edit_action(field)
        controller_path = File.join(
          "app/controllers",
          "#{plural_table_name}_controller.rb"
        )

        full_controller_path = File.join(
          destination_root,
          controller_path
        )

        controller = File.read(full_controller_path)

        return if controller.match?(
          /^\s*def edit_#{Regexp.escape(field)}\s*$/
        )

        inject_into_file(
          controller_path,
          before: /^\s*def create\s*$/
        ) do
          "  def edit_#{field}\n  end\n\n"
        end
      end

      def add_edit_action_to_set_product(field)
        controller_path = File.join(
          "app/controllers",
          "#{plural_table_name}_controller.rb"
        )

        full_controller_path = File.join(
          destination_root,
          controller_path
        )

        controller = File.read(full_controller_path)
        action = "edit_#{field}"

        callback = controller[
          /before_action :set_\w+, only: %i\[(.*?)\]/m,
          0
        ]

        unless callback
          raise Thor::Error,
                "Could not find the set_#{singular_table_name} before_action in #{controller_path}"
        end

        return if callback.match?(/\b#{Regexp.escape(action)}\b/)

        unless callback.match?(/\bupdate\b/)
          raise Thor::Error,
                "Could not find update in the set_#{singular_table_name} before_action"
        end

        updated_callback = callback.sub(
          /\bupdate\b/,
          "#{action} update"
        )

        gsub_file(
          controller_path,
          callback,
          updated_callback
        )
      end

      def add_in_place_update_integration
        controller_path = File.join(
          "app/controllers",
          "#{plural_table_name}_controller.rb"
        )

        full_controller_path = File.join(
          destination_root,
          controller_path
        )

        controller = File.read(full_controller_path)

        original_update_method = controller[
          /^\s*def update\s*$.*?(?=^\s*def \w+)/m,
          0
        ]

        unless original_update_method
          raise Thor::Error,
                "Could not find update action in #{controller_path}"
        end

        update_method = original_update_method
        attachment_blocks = attachment_update_blocks_for_fields

        update_method = integrate_attachment_updates(
          update_method,
          attachment_blocks
        )

        update_method = integrate_attachment_reloads(update_method)
        update_method = integrate_turbo_streams(update_method, controller_path)

        return if update_method == original_update_method

        gsub_file(
          controller_path,
          original_update_method,
          update_method
        )
      end

      def integrate_attachment_updates(update_method, attachment_blocks)
        update_method = integrate_before_attachment_updates(
          update_method,
          attachment_blocks[:before_update]
        )

        integrate_after_attachment_updates(
          update_method,
          attachment_blocks[:after_update]
        )
      end

      def integrate_before_attachment_updates(update_method, lines)
        lines = lines.reject { |line| update_method.include?(line) }

        return update_method if lines.empty?

        original_update_call =
          "if @#{singular_table_name}.update(#{singular_table_name}_params)"

        in_place_update_call =
          "if @#{singular_table_name}.update(update_params)"

        update_call =
          if update_method.include?(in_place_update_call)
            in_place_update_call
          elsif update_method.include?(original_update_call)
            original_update_call
          end

        unless update_call
          raise Thor::Error,
                "Could not find update call in update action"
        end

        before_update_block = lines.join("\n").indent(4)

        replacement = <<~RUBY.chomp
          #{before_update_block}
              if @#{singular_table_name}.update(update_params)
        RUBY

        update_method.sub(update_call, replacement)
      end

      def integrate_after_attachment_updates(update_method, blocks)
        blocks = blocks.reject { |block| update_method.include?(block) }

        return update_method if blocks.empty?

        success_line = update_method[
          /^\s*if @#{Regexp.escape(singular_table_name)}\.update\(update_params\)\s*$/,
          0
        ]

        unless success_line
          raise Thor::Error,
                "Could not find attachment update success line"
        end

        after_update_block = blocks.join("\n\n").indent(8)

        update_method.sub(
          success_line,
          "#{success_line}\n#{after_update_block}"
        )
      end

      def integrate_attachment_reloads(update_method)
        attachment_reload_block_for_fields.lines.each do |reload_line|
          reload_line = reload_line.strip

          next if reload_line.empty?
          next if update_method.include?(reload_line)

          turbo_success_anchor =
            update_method[
              /^\s*format\.turbo_stream do\s*$.*?flash\.now\[:notice\]/m,
              0
            ]

          next unless turbo_success_anchor

          first_line = turbo_success_anchor.lines.first

          update_method = update_method.sub(
            first_line,
            "#{first_line}        #{reload_line}\n\n"
          )
        end

        update_method
      end

      def upgrade_flash_turbo_stream(update_method)
        update_method.sub(
          /turbo_stream\.update\(\s*"flash-messages",/,
          'turbo_stream.replace("flash-messages",'
        )
      end

      def integrate_turbo_streams(update_method, controller_path)
        update_method = upgrade_flash_turbo_stream(update_method)

        return update_method if update_method.include?(
          "IN_PLACE_FIELDS.include?(params[:in_place_field])"
        )

        success_anchor = update_method[
                /^\s*format\.html \{ redirect_to .*successfully updated.*$/,
                0
              ]

        unless success_anchor
          raise Thor::Error,
                "Could not find update success response in #{controller_path}"
        end

        error_anchor = update_method[
          /^\s*format\.html \{ render :edit, status: :unprocessable_content \}$/,
          0
        ]

        unless error_anchor
          raise Thor::Error,
                "Could not find update error response in #{controller_path}"
        end

        attachment_reload_block = attachment_reload_block_for_fields

        turbo_stream_block = <<~RUBY.indent(8)
          #{attachment_reload_block}format.turbo_stream do
            flash.now[:notice] = "#{class_name} was successfully updated."

            streams = [
              turbo_stream.replace(
                "flash-messages",
                partial: "shared/flash"
              )
            ]

            if IN_PLACE_FIELDS.include?(params[:in_place_field])
              streams << turbo_stream.replace(
                helpers.dom_id(
                  @#{singular_table_name},
                  params[:in_place_field]
                ),
                partial: "#{plural_table_name}/\#{params[:in_place_field]}",
                locals: { #{singular_table_name}: @#{singular_table_name} }
              )
            end

            render turbo_stream: streams
          end

        RUBY

        error_turbo_stream_block = <<~RUBY.indent(8)
          format.turbo_stream do
            if IN_PLACE_FIELDS.include?(params[:in_place_field])
              render turbo_stream: turbo_stream.replace(
                helpers.dom_id(
                  @#{singular_table_name},
                  params[:in_place_field]
                ),
                template: "#{plural_table_name}/edit_\#{params[:in_place_field]}"
              ),
              status: :unprocessable_content
            else
              head :unprocessable_content
            end
          end

        RUBY

        update_method = update_method.sub(
          success_anchor,
          "#{turbo_stream_block}#{success_anchor}"
        )

        update_method.sub(
          error_anchor,
          "#{error_turbo_stream_block}#{error_anchor}"
        )
      end

      def add_in_place_params_for(field)
        case field_type(field)
        when :attachment
          add_single_attachment_params(field)
        when :attachments
          add_multiple_attachment_params(field)
        else
          add_regular_field_param(field)
        end
      end

      def add_regular_field_param(field)
        controller_path = File.join(
          "app/controllers",
          "#{plural_table_name}_controller.rb"
        )

        full_controller_path = File.join(
          destination_root,
          controller_path
        )

        controller = File.read(full_controller_path)

        params_method = controller[
          /def #{Regexp.escape(singular_table_name)}_params.*?^\s*end/m,
          0
        ]

        unless params_method
          raise Thor::Error,
                "Could not find #{singular_table_name}_params in #{controller_path}"
        end

        parameter = ":#{field}"

        return if params_method.include?(parameter)

        updated_method =
          if params_method.match?(/\w+:\s*\[\]/)
            params_method.sub(
              /(?=\w+:\s*\[\])/,
              "#{parameter}, "
            )
          else
            params_method.sub(
              /\]\s*\)\s*$/,
              ", #{parameter}])"
            )
          end

        gsub_file(
          controller_path,
          params_method,
          updated_method
        )
      end

      def add_single_attachment_params(field)
        controller_path = File.join(
          "app/controllers",
          "#{plural_table_name}_controller.rb"
        )

        full_controller_path = File.join(
          destination_root,
          controller_path
        )

        controller = File.read(full_controller_path)

        params_method = controller[
          /def #{Regexp.escape(singular_table_name)}_params.*?^\s*end/m,
          0
        ]

        unless params_method
          raise Thor::Error,
                "Could not find #{singular_table_name}_params in #{controller_path}"
        end

        parameters = [
          ":#{field}",
          ":remove_#{field}"
        ]

        parameters.each do |parameter|
          next if params_method.include?(parameter)

          updated_method =
            if params_method.match?(/\w+:\s*\[\]/)
              params_method.sub(
                /(?=\w+:\s*\[\])/,
                "#{parameter}, "
              )
            else
              params_method.sub(
                /\]\s*\)\s*$/,
                ", #{parameter}])"
              )
            end

          gsub_file(
            controller_path,
            params_method,
            updated_method
          )

          params_method = updated_method
        end
      end

      def add_multiple_attachment_params(field)
        controller_path = File.join(
          "app/controllers",
          "#{plural_table_name}_controller.rb"
        )

        full_controller_path = File.join(
          destination_root,
          controller_path
        )

        controller = File.read(full_controller_path)

        params_method = controller[
          /def #{Regexp.escape(singular_table_name)}_params.*?^\s*end/m,
          0
        ]

        unless params_method
          raise Thor::Error,
                "Could not find #{singular_table_name}_params in #{controller_path}"
        end

        parameters = [
          "#{field}: []",
          "remove_#{field}_ids: []"
        ]

        parameters.each do |parameter|
          next if params_method.include?(parameter)

          updated_method = params_method.sub(
            /\s*\]\s*\)\s*$/,
            ", #{parameter} ])"
          )

          gsub_file(
            controller_path,
            params_method,
            updated_method
          )

          params_method = updated_method
        end
      end

      def create_edit_view(field)
        template_name = edit_template_for(field)

        return unless template_name

        destination = File.join(
          "app/views",
          plural_table_name,
          "edit_#{field}.html.erb"
        )

        return if File.exist?(
          File.join(destination_root, destination)
        )

        @field = field

        template(
          template_name,
          destination
        )
      ensure
        @field = nil
      end

      def edit_template_for(field)
        {
          text: "edit_text.html.erb.tt",
          rich_text: "edit_rich_text.html.erb.tt",
          boolean: "edit_boolean.html.erb.tt",
          number: "edit_number.html.erb.tt",
          select: "edit_select.html.erb.tt",
          radio: "edit_radio.html.erb.tt",
          attachment: "edit_attachment.html.erb.tt",
          attachments: "edit_attachments.html.erb.tt"
        }[editor_type(field)]
      end

      def resource_field_range(resource, field)
        label = "#{field.humanize}:"

        label_position = resource.index(
          %(<strong class="resource-label">#{label}</strong>)
        )

        return unless label_position

        field_start = resource.rindex(
          '<div class="resource-field">',
          label_position
        )

        return unless field_start

        position = field_start
        depth = 0

        while (match = resource.match(%r{<div\b[^>]*>|</div>}, position))
          if match[0].start_with?("<div")
            depth += 1
          else
            depth -= 1

            return field_start...match.end(0) if depth.zero?
          end

          position = match.end(0)
        end

        nil
      end

      def integrate_display_partial(field)
        resource_path = File.join(
          "app/views",
          plural_table_name,
          "_#{singular_table_name}.html.erb"
        )

        full_resource_path = File.join(
          destination_root,
          resource_path
        )

        return unless File.exist?(full_resource_path)

        resource = File.read(full_resource_path)

        render_statement =
          "<%= render \"#{plural_table_name}/#{field}\", " \
          "#{singular_table_name}: #{singular_table_name}, " \
          "compact: local_assigns[:compact] %>"

        return if resource.include?(render_statement)

        field_range = resource_field_range(resource, field)

        unless field_range
          say_status(
            :warning,
            "Could not integrate in-place field #{field} into #{resource_path}",
            :yellow
          )
          return
        end

        resource[field_range] = render_statement

        File.write(
          full_resource_path,
          resource
        )
      end

      def create_display_partial(field)
        template_name = display_template_for(field)

        return unless template_name

        destination = File.join(
          "app/views",
          plural_table_name,
          "_#{field}.html.erb"
        )

        return if File.exist?(
          File.join(destination_root, destination)
        )

        @field = field
        @field_type = field_type(field)

        template(
          template_name,
          destination
        )
      ensure
        @field = nil
        @field_type = nil
      end

      def display_template_for(field)
        {
          text: "display_text.html.erb.tt",
          rich_text: "display_rich_text.html.erb.tt",
          boolean: "display_boolean.html.erb.tt",
          number: "display_number.html.erb.tt",
          select: "display_select.html.erb.tt",
          radio: "display_radio.html.erb.tt",
          attachment: "display_attachment.html.erb.tt",
          attachments: "display_attachments.html.erb.tt"
        }[editor_type(field)]
      end

      def attachment_update_blocks_for_fields
        before_update_lines = []
        after_update_lines = []

        fields.each do |field|
          case field_type(field)
          when :attachment
            remove_variable = "remove_#{field}"

            before_update_lines <<
              "#{remove_variable} = update_params.delete(\"remove_#{field}\")"

            after_update_lines <<
              "@#{singular_table_name}.#{field}.purge if #{remove_variable} == \"1\""

          when :attachments
            new_variable = "new_#{field}"
            remove_variable = "remove_#{field}_ids"

            before_update_lines <<
              "#{new_variable} = update_params.delete(\"#{field}\")"

            before_update_lines <<
              "#{remove_variable} = update_params.delete(\"remove_#{field}_ids\")"

            after_update_lines <<
              "@#{singular_table_name}.#{field}.attach(#{new_variable}) if #{new_variable}.present?"

            after_update_lines << <<~RUBY.strip
              if #{remove_variable}.present?
                @#{singular_table_name}.#{field}.attachments
                  .where(id: #{remove_variable})
                  .find_each(&:purge)
              end
            RUBY
          end
        end

        {
          before_update: before_update_lines,
          after_update: after_update_lines
        }
      end

      def attachment_reload_block_for_fields
        reload_lines = fields.filter_map do |field|
          next unless field_type(field) == :attachments

          "@#{singular_table_name}.#{field}.reload"
        end

        return "" if reload_lines.empty?

        "#{reload_lines.join("\n")}\n\n"
      end
    end
  end
end
