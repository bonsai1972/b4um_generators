# frozen_string_literal: true

require "rails/generators"

module B4um
  module Generators
    class TrixGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      argument :name,
               type: :string,
               required: true,
               banner: "MODEL"

      argument :attribute,
               type: :string,
               required: true,
               banner: "ATTRIBUTE"

      desc "Adds Action Text with Trix to an existing B4UM resource."

      def validate_model
        return if File.exist?(model_path)

        raise Thor::Error, "Model #{class_name} does not exist."
      end

      def validate_form
        return if File.exist?(form_path)

        raise Thor::Error, "Form for #{class_name} does not exist."
      end

      def install_action_text
        return if action_text_installed?

        rails_command "action_text:install"
      end

      def install_b4um_trix_javascript
        copy_file(
          "b4um_trix.js",
          "app/javascript/b4um/trix.js"
        )
      end

      def import_b4um_trix_javascript
        application_javascript_path = File.join(
          destination_root,
          "app/javascript/application.js"
        )

        return unless File.exist?(application_javascript_path)

        application_javascript = File.read(application_javascript_path)

        return if application_javascript.include?("import 'b4um/trix'")

        append_to_file(
          "app/javascript/application.js",
          "\nimport 'b4um/trix'\n"
        )
      end

      def pin_b4um_trix_javascript
        importmap_path = File.join(
          destination_root,
          "config/importmap.rb"
        )

        return unless File.exist?(importmap_path)

        importmap = File.read(importmap_path)

        return if importmap.include?('pin "b4um/trix"')

        append_to_file(
          "config/importmap.rb",
          "\npin \"b4um/trix\", to: \"b4um/trix.js\"\n"
        )
      end

      def add_rich_text_association
        inject_into_class(
          model_path,
          class_name,
          "  has_rich_text :#{attribute}\n"
        )
      end

      def update_form
        gsub_file(
          form_path,
          "form.text_area :#{attribute}",
          "form.rich_text_area :#{attribute}"
        )

        gsub_file(
          form_path,
          /<div class="form-field form-field--textarea">(?=\s*<%= form\.rich_text_area :#{Regexp.escape(attribute)})/,
          '<div class="form-field form-field--rich-text">'
        )
      end

      def update_resource_partial
        return unless File.exist?(resource_partial_path)

        resource_name = name.underscore

        gsub_file(
          resource_partial_path,
          "truncate(#{resource_name}.#{attribute}, length: 160)",
          "truncate(#{resource_name}.#{attribute}.to_plain_text, length: 160)"
        )

        partial = File.read(resource_partial_path)

        rich_text_expression =
          "<%= #{resource_name}.#{attribute} %>"

        rich_text_already_wrapped =
          partial.match?(
            /<div class="rich-text-lightbox"[^>]*>\s*.*?#{Regexp.escape(rich_text_expression)}/m
          )

        return if rich_text_already_wrapped

        gsub_file(
          resource_partial_path,
          rich_text_expression,
          <<~ERB.chomp
            <div class="rich-text-lightbox"
                 data-controller="image-lightbox"
                 data-action="keydown->image-lightbox#keydown">
              <%= #{resource_name}.#{attribute} %>

              <div class="image-lightbox"
                   data-image-lightbox-target="overlay"
                   data-action="click->image-lightbox#closeOnBackground"
                   tabindex="-1"
                   role="dialog"
                   aria-modal="true"
                   aria-label="Image gallery"
                   hidden>

                <div class="image-lightbox__counter"
                     data-image-lightbox-target="counter"></div>

                <button type="button"
                        class="image-lightbox__close"
                        aria-label="Close gallery"
                        data-action="click->image-lightbox#close">
                  &times;
                </button>

                <button type="button"
                        class="image-lightbox__navigation image-lightbox__navigation--previous"
                        aria-label="Previous image"
                        data-image-lightbox-target="previousButton"
                        data-action="click->image-lightbox#previous">
                  &#8249;
                </button>

                <div class="image-lightbox__stage"
                     data-image-lightbox-target="stage"
                     data-action="pointerdown->image-lightbox#pointerDown pointermove->image-lightbox#pointerMove pointerup->image-lightbox#pointerUp pointercancel->image-lightbox#pointerCancel">
                  <img class="image-lightbox__image"
                       data-image-lightbox-target="image"
                       alt="">
                </div>

                <button type="button"
                        class="image-lightbox__navigation image-lightbox__navigation--next"
                        aria-label="Next image"
                        data-image-lightbox-target="nextButton"
                        data-action="click->image-lightbox#next">
                  &#8250;
                </button>

                <div class="image-lightbox__caption"
                     data-image-lightbox-target="caption"></div>
              </div>
            </div>
          ERB
        )
      end

      def update_action_text_blob_partial
        return unless File.exist?(action_text_blob_partial_path)

        gsub_file(
          action_text_blob_partial_path,
          /<%= image_tag (.+?) %>/,
          <<~ERB.chomp
            <%= image_tag \\1,
                  data: {
                    image_lightbox_target: "item",
                    image_lightbox_url: rails_blob_path(blob, only_path: true),
                    image_lightbox_alt: blob.filename.to_s,
                    action: "click->image-lightbox#open"
                  } %>
          ERB
        )
      end

      def create_action_text_initializer
        initializer_path = File.join(
          destination_root,
          "config/initializers/action_text.rb"
        )

        configuration = <<~RUBY
          Rails.application.config.after_initialize do
            ActionText::ContentHelper.allowed_tags =
              ActionText::ContentHelper.sanitizer.class.allowed_tags +
              [
                ActionText::Attachment.tag_name,
                "figure",
                "figcaption"
              ] +
              %w[
                align-left
                align-center
                align-right
              ]

            ActionText::ContentHelper.allowed_attributes =
              ActionText::ContentHelper.sanitizer.class.allowed_attributes +
              ActionText::Attachment::ATTRIBUTES +
              %w[
                style
                data-image-lightbox-target
                data-image-lightbox-url
                data-image-lightbox-alt
                data-action
              ]
          end
        RUBY

        if File.exist?(initializer_path)
          append_to_file(
            initializer_path,
            "\n#{configuration}"
          )
        else
          create_file(
            initializer_path,
            <<~RUBY
              # frozen_string_literal: true

              #{configuration}
            RUBY
          )
        end
      end

      private

      def action_text_installed?
        Dir.glob(
          File.join(
            destination_root,
            "db/migrate/*_create_action_text_tables.action_text.rb"
          )
        ).any?
      end

      def class_name
        name.camelize
      end

      def model_path
        File.join(
          destination_root,
          "app/models/#{name.underscore}.rb"
        )
      end

      def form_path
        File.join(
          destination_root,
          "app/views/#{name.underscore.pluralize}/_form.html.erb"
        )
      end

      def resource_partial_path
        File.join(
          destination_root,
          "app/views/#{name.underscore.pluralize}/_#{name.underscore}.html.erb"
        )
      end

      def action_text_blob_partial_path
        File.join(
          destination_root,
          "app/views/active_storage/blobs/_blob.html.erb"
        )
      end
    end
  end
end
