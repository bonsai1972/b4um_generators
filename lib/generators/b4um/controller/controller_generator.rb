# frozen_string_literal: true

require "rails/generators"
require "rails/generators/rails/controller/controller_generator"

module B4um
  module Generators
    class ControllerGenerator < Rails::Generators::ControllerGenerator
      source_root Rails::Generators::ControllerGenerator.source_root

      class_option :sitemap,
                   type: :string,
                   aliases: "-s",
                   desc: "Add generated actions to a B4UM sitemap section: contact, content, service, or more"

      class << self
        def desc(_description = nil)
          "Generates a B4UM controller with views, navigation links, and legal footer links."
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
          next if footer_action?(action)

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

      def add_sitemap_links
        section = sitemap_section

        return unless section

        footer_path = "app/views/shared/_footer.html.erb"
        full_footer_path = File.join(destination_root, footer_path)

        return unless File.exist?(full_footer_path)

        footer = File.read(full_footer_path)
        marker = "<%# B4UM_SITEMAP_#{section.upcase}_LINKS %>"

        return unless footer.include?(marker)

        actions.each do |action|
          path_name = "#{file_name}_#{action}_path"

          next if footer.include?(path_name)

          sitemap_link = <<~ERB.chomp
            <li>
              <%= link_to "#{navigation_label(action)}",
                          #{path_name},
                          class: "b4um-sitemap__link" %>
            </li>

            #{marker}
          ERB

          indented_marker = /^([ \t]*)#{Regexp.escape(marker)}$/

          gsub_file(
            footer_path,
            indented_marker
          ) do |match|
            indentation = match[/^[ \t]*/]

            indent_sitemap_link(
              sitemap_link,
              indentation
            )
          end

          footer = File.read(full_footer_path)
        end
      end

      def remove_legal_navigation_links
        navigation_path = "app/views/shared/_navigation.html.erb"
        full_navigation_path = File.join(destination_root, navigation_path)

        return unless File.exist?(full_navigation_path)

        actions.each do |action|
          next unless footer_action?(action)

          navigation = File.read(full_navigation_path)
          path_name = "#{file_name}_#{action}_path"

          next unless navigation.include?(path_name)

          navigation_link_pattern = /
            \n*
            \s*<%=\s*navigation_link_to
            \s+"[^"]*",
            \s*#{Regexp.escape(path_name)},
            \s*controller:\s*:#{Regexp.escape(file_name)},
            \s*action:\s*:#{Regexp.escape(action.to_s)}
            \s*%>
            \n*
          /x

          gsub_file(
            navigation_path,
            navigation_link_pattern,
            "\n"
          )
        end
      end

      def add_footer_links
        footer_path = "app/views/shared/_footer.html.erb"
        full_footer_path = File.join(destination_root, footer_path)

        return unless File.exist?(full_footer_path)

        footer = File.read(full_footer_path)
        marker = "<%# B4UM_FOOTER_LINKS %>"

        return unless footer.include?(marker)

        actions.each do |action|
          next unless footer_action?(action)

          path_name = "#{file_name}_#{action}_path"

          if footer.include?(path_name)
            upgrade_footer_link(
              footer_path,
              footer,
              path_name
            )

            footer = File.read(full_footer_path)
            next
          end

          footer_link = <<~ERB
            <%= link_to "#{navigation_label(action)}",
                        #{path_name},
                        class: [
                          "b4um-footer__link",
                          ("is-active" if current_page?(#{path_name}))
                        ].compact.join(" "),
                        aria: (current_page?(#{path_name}) ? { current: "page" } : {}) %>

              #{marker}
          ERB

          gsub_file(
            footer_path,
            marker,
            footer_link.chomp
          )

          footer = File.read(full_footer_path)
        end
      end

      def install_footer_active_styles
        stylesheet_path = "app/assets/stylesheets/b4um/footer.css"
        full_stylesheet_path = File.join(
          destination_root,
          stylesheet_path
        )

        return unless File.exist?(full_stylesheet_path)

        stylesheet = File.read(full_stylesheet_path)

        return if stylesheet.include?(
          ".b4um-footer__link.is-active"
        )

        append_to_file(
          stylesheet_path,
          <<~CSS

            .b4um-footer__link.is-active {
              color: var(--b4um-primary);

              font-weight: 700;
            }
          CSS
        )
      end

      private

      def indent_sitemap_link(sitemap_link, indentation)
        sitemap_link
          .lines
          .map do |line|
            line.strip.empty? ? line : "#{indentation}#{line}"
          end
          .join
          .chomp
      end

      def sitemap_section
        section = options[:sitemap].to_s.downcase

        return if section.empty?

        valid_sections = %w[
          contact
          content
          service
          more
        ]

        return section if valid_sections.include?(section)

        say(
          "  Unknown sitemap section '#{section}'. " \
          "Use contact, content, service, or more.",
          :yellow
        )

        nil
      end

      def upgrade_footer_link(footer_path, footer, path_name)
        return if footer.include?(
          "current_page?(#{path_name})"
        )

        old_link_pattern = /
          <%=\s*link_to\s+"([^"]+)",
          \s*#{Regexp.escape(path_name)},
          \s*class:\s*"b4um-footer__link"\s*%>
        /x

        return unless footer.match?(old_link_pattern)

        upgraded_link = <<~ERB.chomp
          <%= link_to "\\1",
                      #{path_name},
                      class: [
                        "b4um-footer__link",
                        ("is-active" if current_page?(#{path_name}))
                      ].compact.join(" "),
                      aria: (current_page?(#{path_name}) ? { current: "page" } : {}) %>
        ERB

        gsub_file(
          footer_path,
          old_link_pattern,
          upgraded_link
        )
      end

      def footer_action?(action)
        footer_actions = %w[
          impressum
          datenschutz
          agb
          imprint
          privacy
          privacy_policy
          terms
          terms_and_conditions
        ]

        footer_actions.include?(action.to_s)
      end

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
