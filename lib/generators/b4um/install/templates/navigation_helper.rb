# frozen_string_literal: true

module NavigationHelper
  def navigation_link_to(name, path, controller: nil, action: nil)
    classes = ["navigation__link"]

    active =
      if controller && action
        controller_name == controller.to_s &&
          action_name == action.to_s
      elsif controller
        controller_name == controller.to_s
      else
        current_page?(path)
      end

    classes << "navigation__link--active" if active

    link_to(
      name,
      path,
      class: classes,
      data: { action: "click->navigation#close" }
    )
  end

  def navigation_button_to(name, path, method:)
    button_to(
      name,
      path,
      method: method,
      class: "navigation__link",
      form: {
        class: "navigation__form",
        data: { action: "click->navigation#close" }
      }
    )
  end
end
