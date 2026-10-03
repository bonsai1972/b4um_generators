# frozen_string_literal: true

module B4umRichTextHelper
  B4UM_RICH_TEXT_CONTAINERS = %w[div section article].freeze

  def b4um_rich_text_preview(rich_text, length: 160)
    return if rich_text.blank?

    document = rich_text.body.fragment.source
    first_element = document.element_children.first
    heading = b4um_preview_heading(first_element)

    document.css("action-text-attachment").remove
    plain_text = document.text.strip

    if heading
      heading_text = heading.text.strip
      body_text = plain_text.delete_prefix(heading_text).strip

      preview_parts = [
        content_tag(
          :strong,
          heading_text,
          class: "b4um-rich-text-preview__heading"
        )
      ]

      if body_text.present?
        preview_parts << content_tag(
          :span,
          truncate(body_text, length: length),
          class: "b4um-rich-text-preview__text"
        )
      end

      content_tag(
        :span,
        safe_join(preview_parts),
        class: "b4um-rich-text-preview"
      )
    else
      truncate(plain_text, length: length)
    end
  end

  private

  def b4um_preview_heading(element)
    return unless element

    return element if element.name.match?(/\Ah[1-6]\z/)

    return unless B4UM_RICH_TEXT_CONTAINERS.include?(element.name)

    first_child = element.element_children.first

    b4um_preview_heading(first_child)
  end
end
