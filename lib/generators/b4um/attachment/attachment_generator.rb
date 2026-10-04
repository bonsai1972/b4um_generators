# frozen_string_literal: true

require "rails/generators"
require "rails/generators/named_base"

module B4um
  module Generators
    class AttachmentGenerator < Rails::Generators::NamedBase
      argument :attachment,
               type: :string,
               required: true,
               banner: "ATTACHMENT"

      class_option :multiple,
                   type: :boolean,
                   default: false,
                   desc: "Adds multiple attachments with has_many_attached."

      class << self
        def desc(_description = nil)
          "Adds an attachment to an existing model."
        end
      end

      def validate_model
        return if File.exist?(model_path)

        raise Thor::Error,
              "Model not found: app/models/#{file_name}.rb"
      end

      def add_attachment
        model_content = File.read(model_path)
        declaration = attachment_declaration

        return if model_content.include?(declaration)

        inject_into_class(
          model_path,
          class_name,
          "  #{declaration}\n"
        )

        say_status(
          :attachment,
          "#{class_name} now has #{attachment}",
          :green
        )
      end

      def update_form
        return unless File.exist?(form_path)

        content = File.read(form_path)

        return if content.include?("form.file_field :#{attachment}")

        marker = '  <div class="form-actions">'

        return unless content.include?(marker)

        insert_into_file(
          form_path,
          attachment_form,
          before: marker
        )
      end

      def update_controller_params
        return unless File.exist?(controller_path)

        if options[:multiple]
          update_multiple_attachment_params
        else
          update_single_attachment_params
        end
      end

      def update_resource
        return unless File.exist?(resource_path)

        content = File.read(resource_path)

        return if content.include?(
          %(<strong class="resource-label">#{attachment.humanize}:</strong>)
        )

        closing_tag = "\n</div>\n"

        return unless content.end_with?(closing_tag)

        resource = attachment_resource

        content = content.sub(
          %r{</div>\n\z},
          "#{resource}</div>\n"
        )

        File.write(resource_path, content)

        say_status(
          :insert,
          resource_path.sub("#{destination_root}/", ""),
          :green
        )
      end

      private

      def update_single_attachment_params
        content = File.read(controller_path)

        update_single_permitted_params(content)
        update_single_attachment_action
      end

      def update_single_permitted_params(content)
        return if single_attachment_permitted?(content)

        pattern = /
          params\.expect\(
          #{Regexp.escape(file_name)}:\s*
          \[
          (?<attributes>.*?)
          \]
          \)
        /mx

        return unless content.match?(pattern)

        gsub_file(controller_path, pattern) do |match|
          match_data = pattern.match(match)
          attributes = match_data[:attributes]

          insertion = ":#{attachment}, :remove_#{attachment}"

          updated_attributes =
            if attributes.match?(/\w+:\s*\[/)
              attributes.sub(
                /(?=\w+:\s*\[)/,
                "#{insertion}, "
              )
            else
              "#{attributes}, #{insertion}"
            end

          match.sub(
            attributes,
            updated_attributes
          )
        end
      end

      def single_attachment_permitted?(content)
        content.include?(
          ":#{attachment}, :remove_#{attachment}"
        )
      end

      def update_single_attachment_action
        content = File.read(controller_path)

        return if content.include?(
          "remove_#{attachment} = update_params.delete(\"remove_#{attachment}\")"
        )

        if content.include?("    update_params = #{file_name}_params\n")
          insert_into_file(
            controller_path,
            "    remove_#{attachment} = update_params.delete(\"remove_#{attachment}\")\n",
            after: "    update_params = #{file_name}_params\n"
          )
        else
          setup = [
            "  def update",
            "    update_params = #{file_name}_params",
            "    remove_#{attachment} = update_params.delete(\"remove_#{attachment}\")",
            "",
            "    respond_to do |format|",
            ""
          ].join("\n")

          gsub_file(
            controller_path,
            "  def update\n    respond_to do |format|\n",
            setup
          )
        end

        content = File.read(controller_path)

        if content.include?("      if @#{file_name}.update(update_params)\n")
          insert_into_file(
            controller_path,
            "        @#{file_name}.#{attachment}.purge if remove_#{attachment} == \"1\"\n",
            after: "      if @#{file_name}.update(update_params)\n"
          )
        else
          attachment_handling = [
            "      if @#{file_name}.update(update_params)",
            "        @#{file_name}.#{attachment}.purge if remove_#{attachment} == \"1\"",
            ""
          ].join("\n")

          gsub_file(
            controller_path,
            "      if @#{file_name}.update(#{file_name}_params)\n",
            attachment_handling
          )
        end
      end

      def update_multiple_attachment_params
        content = File.read(controller_path)

        update_multiple_permitted_params(content)
        update_multiple_attachment_action
      end

      def update_multiple_permitted_params(content)
        return if multiple_attachment_permitted?(content)

        pattern = /
          params\.expect\(
          #{Regexp.escape(file_name)}:\s*
          \[
          (?<attributes>[^\]]*)
          \]
          \)
        /mx

        return unless content.match?(pattern)

        gsub_file(controller_path, pattern) do |match|
          match.sub(
            /\]\)$/,
            ", #{attachment}: [], remove_#{attachment}_ids: []])"
          )
        end
      end

      def multiple_attachment_permitted?(content)
        content.include?(
          "#{attachment}: [], remove_#{attachment}_ids: []"
        )
      end

      def update_multiple_attachment_action
        content = File.read(controller_path)

        return if content.include?(
          "new_#{attachment} = update_params.delete(\"#{attachment}\")"
        )

        setup = [
          "  def update",
          "    update_params = #{file_name}_params",
          "    new_#{attachment} = update_params.delete(\"#{attachment}\")",
          "    remove_#{attachment}_ids = update_params.delete(\"remove_#{attachment}_ids\")",
          "",
          "    respond_to do |format|",
          ""
        ].join("\n")

        gsub_file(
          controller_path,
          "  def update\n    respond_to do |format|\n",
          setup
        )

        attachment_handling = [
          "      if @#{file_name}.update(update_params)",
          "        @#{file_name}.#{attachment}.attach(new_#{attachment}) if new_#{attachment}.present?",
          "",
          "        if remove_#{attachment}_ids.present?",
          "          @#{file_name}.#{attachment}.attachments",
          "            .where(id: remove_#{attachment}_ids)",
          "            .find_each(&:purge)",
          "        end",
          ""
        ].join("\n")

        gsub_file(
          controller_path,
          "      if @#{file_name}.update(#{file_name}_params)\n",
          attachment_handling
        )
      end

      def attachment_declaration
        if options[:multiple]
          "has_many_attached :#{attachment}"
        else
          "has_one_attached :#{attachment}"
        end
      end

      def model_path
        File.join(
          destination_root,
          "app/models",
          "#{file_name}.rb"
        )
      end

      def form_path
        File.join(
          destination_root,
          "app/views",
          plural_name,
          "_form.html.erb"
        )
      end

      def resource_path
        File.join(
          destination_root,
          "app/views",
          plural_name,
          "_#{file_name}.html.erb"
        )
      end

      def attachment_resource
        if options[:multiple]
          multiple_attachment_resource
        else
          single_attachment_resource
        end
      end

      def single_attachment_resource
        <<~ERB.indent(2)
          <div class="resource-field">
            <strong class="resource-label">#{attachment.humanize}:</strong>

            <div class="resource-image"
                 data-controller="image-lightbox"
                 data-action="keydown->image-lightbox#keydown">

              <% if #{file_name}.#{attachment}.attached? %>
                <button type="button"
                        class="resource-image__button"
                        data-image-lightbox-target="item"
                        data-image-lightbox-url="<%= url_for(#{file_name}.#{attachment}) %>"
                        data-image-lightbox-alt="<%= #{file_name}.#{attachment}.filename.to_s %>"
                        data-action="click->image-lightbox#open">

                  <%= image_tag #{file_name}.#{attachment},
                                class: "resource-image__image",
                                alt: #{file_name}.#{attachment}.filename.to_s %>
                </button>

                <div class="image-lightbox"
                     data-image-lightbox-target="overlay"
                     data-action="click->image-lightbox#closeOnBackground"
                     tabindex="-1"
                     role="dialog"
                     aria-modal="true"
                     aria-label="Image preview"
                     hidden>

                  <div class="image-lightbox__counter"
                       data-image-lightbox-target="counter"></div>

                  <button type="button"
                          class="image-lightbox__close"
                          aria-label="Close image"
                          data-action="click->image-lightbox#close">
                    &times;
                  </button>

                  <div class="image-lightbox__stage"
                       data-image-lightbox-target="stage"
                       data-action="pointerdown->image-lightbox#pointerDown pointermove->image-lightbox#pointerMove pointerup->image-lightbox#pointerUp pointercancel->image-lightbox#pointerCancel">
                    <img class="image-lightbox__image"
                         data-image-lightbox-target="image"
                         alt="">
                  </div>

                  <div class="image-lightbox__thumbnails"
                       data-image-lightbox-target="thumbnails"></div>

                  <div class="image-lightbox__caption"
                       data-image-lightbox-target="caption"></div>
                </div>
              <% else %>
                <span class="resource-value resource-value--empty">No image</span>
              <% end %>
            </div>
          </div>
        ERB
      end

      def multiple_attachment_resource
        <<~ERB.indent(2)
          <div class="resource-field">
            <strong class="resource-label">#{attachment.humanize}:</strong>

            <div class="resource-images"
                 data-controller="image-lightbox"
                 data-action="keydown->image-lightbox#keydown">

              <% if #{file_name}.#{attachment}.attached? %>
                <% #{file_name}.#{attachment}.each do |image| %>
                  <button type="button"
                          class="resource-images__button"
                          data-image-lightbox-target="item"
                          data-image-lightbox-url="<%= url_for(image) %>"
                          data-image-lightbox-alt="<%= image.filename.to_s %>"
                          data-action="click->image-lightbox#open">

                    <%= image_tag image,
                                  class: "resource-images__image",
                                  alt: image.filename.to_s %>
                  </button>
                <% end %>

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
                          aria-label="Close image"
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

                  <div class="image-lightbox__thumbnails"
                       data-image-lightbox-target="thumbnails"></div>

                  <div class="image-lightbox__caption"
                       data-image-lightbox-target="caption"></div>
                </div>
              <% else %>
                <span class="resource-value resource-value--empty">No images</span>
              <% end %>
            </div>
          </div>
        ERB
      end

      def controller_path
        File.join(
          destination_root,
          "app/controllers",
          "#{plural_name}_controller.rb"
        )
      end

      def attachment_permitted?(content)
        content.match?(
          /params\.expect\(#{Regexp.escape(file_name)}:.*:#{Regexp.escape(attachment)}.*\)/m
        )
      end

      def attachment_form
        if options[:multiple]
          multiple_attachment_form
        else
          single_attachment_form
        end
      end

      def single_attachment_form
        <<~ERB.indent(2)
          <div class="form-field form-field--file"
               data-controller="image-preview">

            <div class="form-file-control">
              <%= form.label :#{attachment},
                    class: "form-file-label" %>

              <%= form.file_field :#{attachment},
                    class: "form-file-input",
                    accept: "image/*",
                    data: {
                      image_preview_target: "input",
                      action: "change->image-preview#preview"
                    } %>
            </div>

            <div class="form-image-preview"
                 data-image-preview-target="container"
                 <%= "hidden" unless #{file_name}.#{attachment}.attached? %>>

              <% if #{file_name}.#{attachment}.attached? %>
                <div class="form-image-preview__item"
                     role="button"
                     tabindex="0"
                     aria-pressed="false"
                     data-image-preview-target="existingItem"
                     data-action="click->image-preview#toggleRemoval keydown->image-preview#toggleRemovalWithKeyboard">

                  <%= image_tag #{file_name}.#{attachment},
                                class: "form-image-preview__image",
                                alt: #{file_name}.#{attachment}.filename.to_s,
                                data: {
                                  image_preview_target: "image"
                                } %>

                  <%= check_box_tag(
                        "#{file_name}[remove_#{attachment}]",
                        "1",
                        false,
                        class: "form-image-preview__remove-checkbox",
                        data: {
                          image_preview_target: "removeCheckbox"
                        }
                      ) %>

                  <div class="form-image-preview__remove-status">
                    Will be removed
                  </div>
                </div>
              <% else %>
                <img class="form-image-preview__image"
                     data-image-preview-target="image"
                     alt="Image preview">
              <% end %>
            </div>
          </div>

        ERB
      end

      def multiple_attachment_form
        <<~ERB.indent(2)
          <div class="form-field form-field--file"
               data-controller="image-preview">

            <div class="form-file-control">
              <%= form.label :#{attachment},
                    class: "form-file-label" %>

              <% #{file_name}.#{attachment}.each do |image| %>
                <%= form.hidden_field :#{attachment},
                                      multiple: true,
                                      value: image.signed_id %>
              <% end %>

              <%= form.file_field :#{attachment},
                    class: "form-file-input",
                    accept: "image/*",
                    multiple: true,
                    data: {
                      image_preview_target: "input",
                      action: "change->image-preview#previewMultiple"
                    } %>
            </div>

            <div class="form-image-preview form-image-preview--multiple"
                 data-image-preview-target="container"
                 <%= "hidden" unless #{file_name}.#{attachment}.attached? %>>

              <% #{file_name}.#{attachment}.each do |image| %>
                <div class="form-image-preview__item"
                     role="button"
                     tabindex="0"
                     aria-pressed="false"
                     data-image-preview-target="existingItem"
                     data-action="click->image-preview#toggleRemoval keydown->image-preview#toggleRemovalWithKeyboard">

                  <%= image_tag image,
                                class: "form-image-preview__image",
                                alt: image.filename.to_s %>

                  <%= check_box_tag(
                        "#{file_name}[remove_#{attachment}_ids][]",
                        image.id,
                        false,
                        class: "form-image-preview__remove-checkbox",
                        data: {
                          image_preview_target: "removeCheckbox"
                        }
                      ) %>

                  <div class="form-image-preview__remove-status">
                    Will be removed
                  </div>
                </div>
              <% end %>
            </div>
          </div>

        ERB
      end
    end
  end
end
