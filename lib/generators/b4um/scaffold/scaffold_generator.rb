# frozen_string_literal: true

require "rails/generators"
require "action_dispatch"
require "rails/generators/rails/scaffold/scaffold_generator"

module B4um
  module Generators
    class ScaffoldGenerator < Rails::Generators::ScaffoldGenerator
      source_root File.expand_path("templates", __dir__)

      class << self
        def desc(_description = nil)
          "Generates a B4UM scaffold."
        end
      end

      class_option :param,
                   type: :string,
                   desc: "Attribute used for a readable URL parameter"

      class_option :layout,
                   type: :string,
                   default: "bento",
                   enum: %w[bento table],
                   desc: "Index layout: bento or table"

      def create_b4um_form
        form_path = File.join(
          "app/views",
          plural_table_name,
          "_form.html.erb"
        )

        remove_file form_path

        template(
          "_form.html.erb.tt",
          form_path
        )
      end

      def create_b4um_resource
        resource_path = File.join(
          "app/views",
          plural_table_name,
          "_#{singular_table_name}.html.erb"
        )

        remove_file resource_path

        template(
          "_resource.html.erb.tt",
          resource_path
        )
      end

      def create_b4um_index
        index_path = File.join(
          "app/views",
          plural_table_name,
          "index.html.erb"
        )

        partial_path = File.join(
          "app/views",
          plural_table_name,
          "_#{options[:layout]}.html.erb"
        )

        remove_file index_path

        template(
          "index.html.erb.tt",
          index_path
        )

        template(
          "_#{options[:layout]}.html.erb.tt",
          partial_path
        )
      end

      def create_b4um_show
        show_path = File.join(
          "app/views",
          plural_table_name,
          "show.html.erb"
        )

        remove_file show_path

        template(
          "show.html.erb.tt",
          show_path
        )
      end

      def create_b4um_new
        new_path = File.join(
          "app/views",
          plural_table_name,
          "new.html.erb"
        )

        remove_file new_path

        template(
          "new.html.erb.tt",
          new_path
        )
      end

      def create_b4um_edit
        edit_path = File.join(
          "app/views",
          plural_table_name,
          "edit.html.erb"
        )

        remove_file edit_path

        template(
          "edit.html.erb.tt",
          edit_path
        )
      end

      def add_secure_password
        return unless attributes.any? { |attribute| attribute.name == "password_digest" }

        inject_into_class(
          File.join("app/models", "#{singular_table_name}.rb"),
          class_name,
          "  has_secure_password\n"
        )
      end

      def add_bcrypt
        return unless attributes.any? { |attribute| attribute.name == "password_digest" }

        gemfile_path = "Gemfile"
        gemfile = File.read(gemfile_path)

        if gemfile.match?(/^#\s*gem ["']bcrypt["']/)
          uncomment_lines gemfile_path, /gem ["']bcrypt["']/
        elsif !gemfile.match?(/^gem ["']bcrypt["']/)
          gem "bcrypt", "~> 3.1"
        end
      end

      def update_password_params
        return unless attributes.any? { |attribute| attribute.name == "password_digest" }

        controller_path = File.join(
          "app/controllers",
          "#{plural_table_name}_controller.rb"
        )

        gsub_file(
          controller_path,
          ":password_digest",
          ":password, :password_confirmation"
        )
      end

      def update_multiple_attachments
        attachment_attributes = attributes.select do |attribute|
          attribute.type == :attachments
        end

        return if attachment_attributes.empty?

        controller_path = File.join(
          "app/controllers",
          "#{plural_table_name}_controller.rb"
        )

        attachment_names = attachment_attributes.map(&:name)

        setup_lines = attachment_names.map do |name|
          [
            "    new_#{name} = update_params.delete(\"#{name}\")",
            "    remove_#{name}_ids = update_params.delete(\"remove_#{name}_ids\")"
          ]
        end.flatten.join("\n")

        attachment_lines = attachment_names.map do |name|
          [
            "        @#{singular_table_name}.#{name}.attach(new_#{name}) if new_#{name}.present?",
            "",
            "        if remove_#{name}_ids.present?",
            "          @#{singular_table_name}.#{name}.attachments",
            "            .where(id: remove_#{name}_ids)",
            "            .find_each(&:purge)",
            "        end"
          ]
        end.flatten.join("\n")

        gsub_file(
          controller_path,
          "  def update\n    respond_to do |format|\n",
          [
            "  def update",
            "    update_params = #{singular_table_name}_params",
            setup_lines,
            "",
            "    respond_to do |format|",
            ""
          ].join("\n")
        )

        gsub_file(
          controller_path,
          "      if @#{singular_table_name}.update(#{singular_table_name}_params)\n",
          [
            "      if @#{singular_table_name}.update(update_params)",
            attachment_lines,
            ""
          ].join("\n")
        )

        attachment_names.each do |name|
          gsub_file(
            controller_path,
            "#{name}: []",
            "#{name}: [], remove_#{name}_ids: []"
          )
        end
      end

      def add_readable_param
        param_name = options[:param]

        return if param_name.blank?

        unless attributes.any? { |attribute| attribute.name == param_name }
          say_status(
            :warning,
            "--param=#{param_name} ignored: attribute does not exist",
            :yellow
          )

          return
        end

        inject_into_class(
          File.join("app/models", "#{singular_table_name}.rb"),
          class_name,
          <<~RUBY
            def to_param
              "\#{id} \#{#{param_name}}".parameterize
            end
          RUBY
        )
      end

      def update_destroy_flash
        controller_path = File.join(
          "app/controllers",
          "#{plural_table_name}_controller.rb"
        )

        controller = File.read(
          File.join(destination_root, controller_path)
        )

        # Rails-Scaffold mit respond_to / format.html
        if controller.match?(
          /format\.html \{ redirect_to ([^,]+), notice: ("[^"]* was successfully destroyed\."), status: :see_other \}/
        )
          gsub_file(
            controller_path,
            /
              format\.html\ \{\ redirect_to\ ([^,]+),
              \ notice:\ ("[^"]*\ was\ successfully\ destroyed\."),
              \ status:\ :see_other\ \}
            /x,
            <<~RUBY.chomp
              format.html do
                flash[:deleted] = \\2
                redirect_to \\1, status: :see_other
              end
            RUBY
          )

          return
        end

        # Rails-Scaffold ohne respond_to
        gsub_file(
          controller_path,
          /redirect_to ([^,]+), notice: ("[^"]* was successfully destroyed\."), status: :see_other/,
          <<~RUBY.chomp
            flash[:deleted] = \\2
            redirect_to \\1, status: :see_other
          RUBY
        )
      end

      def add_navigation_link
        navigation_path = "app/views/shared/_navigation.html.erb"
        full_navigation_path = File.join(destination_root, navigation_path)

        return unless File.exist?(full_navigation_path)

        navigation = File.read(full_navigation_path)

        return if navigation.include?(
          "controller: :#{plural_table_name}"
        )

        marker = "<%# B4UM_NAVIGATION_LINKS %>"

        return unless navigation.include?(marker)

        navigation_link = <<~ERB
          <%= navigation_link_to "#{plural_table_name.humanize}",
                                 #{plural_route_name}_path,
                                 controller: :#{plural_table_name} %>

            #{marker}
        ERB

        gsub_file(
          navigation_path,
          marker,
          navigation_link.chomp
        )
      end
    end
  end
end
