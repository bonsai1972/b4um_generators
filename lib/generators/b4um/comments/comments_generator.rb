# frozen_string_literal: true

require "rails/generators"
require "rails/generators/migration"

module B4um
  module Generators
    class CommentsGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Installs polymorphic comments for B4UM resources."

      argument :commentable,
               type: :string,
               required: true,
               banner: "MODEL"

      def self.next_migration_number(_dirname)
        if @previous_migration_number
          @previous_migration_number += 1
        else
          @previous_migration_number =
            Time.now.utc.strftime("%Y%m%d%H%M%S").to_i
        end

        @previous_migration_number.to_s
      end

      def validate_commentable_model
        model_path = File.join(
          destination_root,
          "app/models",
          "#{commentable.to_s.underscore}.rb"
        )

        return if File.exist?(model_path)

        raise Thor::Error,
              "Commentable model not found: app/models/#{commentable.to_s.underscore}.rb"
      end

      def create_comment_model
        model_path = File.join(
          destination_root,
          "app/models/comment.rb"
        )

        return if File.exist?(model_path)

        template(
          "comment.rb.tt",
          "app/models/comment.rb"
        )
      end

      def add_comments_association
        model_name = commentable.to_s.underscore
        model_path = File.join(
          "app/models",
          "#{model_name}.rb"
        )

        full_model_path = File.join(
          destination_root,
          model_path
        )

        model = File.read(full_model_path)

        return if model.include?(
          "has_many :comments,"
        )

        association = [
          "  has_many :comments,",
          "           as: :commentable,",
          "           dependent: :destroy",
          ""
        ].join("\n")

        inject_into_class(
          model_path,
          commentable.to_s.classify,
          association
        )
      end

      def create_comments_migration
        existing_migration = Dir.glob(
          File.join(
            destination_root,
            "db/migrate/*_create_comments.rb"
          )
        )

        return if existing_migration.any?

        migration_template(
          "create_comments.rb.tt",
          "db/migrate/create_comments.rb"
        )
      end

      def create_comments_controller
        controller_path = "app/controllers/comments_controller.rb"
        full_controller_path = File.join(destination_root, controller_path)

        unless File.exist?(full_controller_path)
          template(
            "comments_controller.rb.tt",
            controller_path
          )

          return
        end

        controller = File.read(full_controller_path)

        unless controller.include?("COMMENTABLES = {")
          upgraded = upgrade_legacy_comments_controller?(
            controller_path,
            controller
          )

          unless upgraded
            raise Thor::Error,
                  "Cannot modify existing CommentsController: " \
                  "its structure is not recognized by the B4UM generator."
          end
        end

        controller = File.read(full_controller_path)

        param_name = "#{commentable.to_s.underscore}_id"
        class_name = commentable.to_s.classify

        return if controller.include?(
          %("#{param_name}" => #{class_name})
        )

        inject_into_file(
          controller_path,
          after: "  COMMENTABLES = {\n"
        ) do
          %(    "#{param_name}" => #{class_name},\n)
        end
      end

      def create_comments_partial
        partial_path = File.join(
          destination_root,
          "app/views/comments/_comments.html.erb"
        )

        return if File.exist?(partial_path)

        template(
          "_comments.html.erb.tt",
          "app/views/comments/_comments.html.erb"
        )
      end

      def add_comments_routes
        routes_path = "config/routes.rb"
        full_routes_path = File.join(destination_root, routes_path)

        routes = File.read(full_routes_path)
        resource_name = commentable.to_s.underscore.pluralize

        return if routes.include?(
          "resources :#{resource_name} do\n    resources :comments"
        )

        gsub_file(
          routes_path,
          "  resources :#{resource_name}\n",
          [
            "  resources :#{resource_name} do",
            "    resources :comments, only: %i[create destroy]",
            "  end",
            ""
          ].join("\n")
        )
      end

      def add_comments_to_show_view
        model_name = commentable.to_s.underscore
        show_path = File.join(
          "app/views",
          model_name.pluralize,
          "show.html.erb"
        )
        full_show_path = File.join(destination_root, show_path)

        return unless File.exist?(full_show_path)

        show_view = File.read(full_show_path)
        render_line =
          %(<%= render "comments/comments", commentable: @#{model_name} %>)

        return if show_view.include?(render_line)

        append_to_file(
          show_path,
          "\n#{render_line}\n"
        )
      end

      private

      def upgrade_legacy_comments_controller?(controller_path, controller)
        match = controller.match(
          /@commentable = ([A-Z]\w*(?:::\w+)*)\.find\(\s*params\[:(\w+_id)\]\s*\)/
        )

        return false unless match

        legacy_class = match[1]
        legacy_param = match[2]

        commentables = [
          "",
          "  COMMENTABLES = {",
          %(    "#{legacy_param}" => #{legacy_class}),
          "  }.freeze",
          ""
        ].join("\n")

        inject_into_file(
          controller_path,
          commentables,
          after: "class CommentsController < ApplicationController\n"
        )

        set_commentable = [
          "  def set_commentable",
          "    param_name, commentable_class = COMMENTABLES.find do |key, _klass|",
          "      params[key].present?",
          "    end",
          "",
          "    raise ActiveRecord::RecordNotFound unless param_name",
          "",
          "    @commentable = commentable_class.find(params[param_name])",
          "  end"
        ].join("\n")

        gsub_file(
          controller_path,
          /  def set_commentable\n.*?^  end$/m,
          set_commentable
        )

        true
      end
    end
  end
end
