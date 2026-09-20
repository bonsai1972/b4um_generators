# frozen_string_literal: true

require "rails/generators"
require "rails/generators/rails/controller/controller_generator"

module B4um
  module Generators
    class ControllerGenerator < Rails::Generators::ControllerGenerator
      source_root Rails::Generators::ControllerGenerator.source_root

      class << self
        def desc(_description = nil)
          "Generates a B4UM controller with views and navigation links."
        end
      end

      def create_b4um_views
        actions.each do |action|
          view_path = File.join(
            "app/views",
            file_name,
            "#{action}.html.erb"
          )

          create_file(
            view_path,
            b4um_view_content(action),
            force: true
          )
        end
      end

      def add_navigation_links
        navigation_path = "app/views/shared/_navigation.html.erb"
        full_navigation_path = File.join(destination_root, navigation_path)

        return unless File.exist?(full_navigation_path)

        navigation = File.read(full_navigation_path)
        marker = "<%# B4UM_NAVIGATION_LINKS %>"

        return unless navigation.include?(marker)

        actions.each do |action|
          next if navigation.include?(
            "action: :#{action}"
          )

          navigation_link = <<~ERB
            <%= navigation_link_to "#{navigation_label(action)}",
                                   #{file_name}_#{action}_path,
                                   controller: :#{file_name},
                                   action: :#{action} %>

              #{marker}
          ERB

          gsub_file(
            navigation_path,
            marker,
            navigation_link.chomp
          )
        end
      end

      private

      def b4um_view_content(action)
        title = navigation_label(action)

        <<~ERB
          <% content_for :title, "#{title}" %>

          <div class="page-header">
            <h1>#{title}</h1>
          </div>

          <div class="b4um-grid">
            <section class="b4um-card b4um-card--full">
              <h2 class="b4um-card__title">
                #{title}
              </h2>

              <p class="b4um-card__text">
                Add your content here.
              </p>
            </section>
          </div>
        ERB
      end

      def navigation_label(action)
        abbreviations = {
          "agb" => "AGB",
          "faq" => "FAQ"
        }

        abbreviations.fetch(action.to_s, action.to_s.humanize)
      end
    end
  end
end
