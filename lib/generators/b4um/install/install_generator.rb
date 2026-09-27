# frozen_string_literal: true

require "rails/generators"
require "yaml"

module B4um
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs the B4UM base setup."

      def install_bcrypt
        unless yes?("Install bcrypt for password support? (y/n)")
          say "  bcrypt skipped."
          return
        end

        gemfile_path = File.join(destination_root, "Gemfile")
        gemfile = File.read(gemfile_path)

        if gemfile.match?(/^\s*gem ["']bcrypt["']/)
          say "  bcrypt is already present in the Gemfile."
          return
        end

        if gemfile.match?(/^\s*#\s*gem ["']bcrypt["']/)
          gsub_file(
            "Gemfile",
            /^(\s*)#\s*(gem ["']bcrypt["'].*)$/,
            '\1\2'
          )

          @gems_added = true

          say "  bcrypt activated in the Gemfile."
          return
        end

        gem "bcrypt"
        @gems_added = true

        say "  bcrypt added to the Gemfile."
      end

      def install_active_storage
        unless yes?("Install Active Storage for image attachments? (y/n)")
          say "  Active Storage skipped."
          return
        end

        migration_files = Dir.glob(
          File.join(
            destination_root,
            "db/migrate/*_create_active_storage_tables.active_storage.rb"
          )
        )

        if migration_files.any?
          say "  Active Storage is already installed."
          return
        end

        rails_command "active_storage:install"

        say "  Active Storage installed."
        say "  Running database migrations..."

        rails_command "db:migrate"

        say "  Active Storage database tables created."
      end

      def create_stylesheet
        copy_file "b4um.css", "app/assets/stylesheets/b4um.css"

        directory(
          "b4um",
          "app/assets/stylesheets/b4um"
        )
      end

      def install_hero
        unless yes?("Add a hero section? (y/n)")
          say "  Hero section skipped."
          return
        end

        copy_file(
          "_hero.html.erb",
          "app/views/shared/_hero.html.erb"
        )

        @hero_installed = true

        say "  Hero section installed."
      end

      def install_footer
        unless yes?("Add a footer? (y/n)")
          @footer_installed = false

          say "  Footer skipped."
          return
        end

        footer_path = "app/views/shared/_footer.html.erb"
        full_footer_path = File.join(destination_root, footer_path)

        if File.exist?(full_footer_path)
          @footer_installed = true

          say "  Footer already exists; keeping existing footer."
          return
        end

        copy_file(
          "_footer.html.erb",
          footer_path
        )

        @footer_installed = true

        say "  Footer installed."
      end

      def install_sitemap
        unless @footer_installed
          say "  Sitemap skipped because footer is not installed."
          return
        end

        unless yes?("Add a sitemap to the footer? (y/n)")
          say "  Sitemap skipped."
          return
        end

        @sitemap_column_count = ask_sitemap_column_count

        default_titles = %w[
          Kontakt
          Inhalte
          Service
          Mehr
          Weitere
        ]

        @sitemap_titles = Array.new(@sitemap_column_count) do |index|
          default_title = default_titles[index]

          ask(
            "Sitemap column #{index + 1} title [#{default_title}]:"
          ).presence || default_title
        end

        copy_file(
          "_sitemap.html.erb",
          "app/views/shared/_sitemap.html.erb"
        )

        copy_file(
          "sitemap_controller.js",
          "app/javascript/controllers/sitemap_controller.js"
        )

        @sitemap_installed = true

        say "  Sitemap installed."
      end

      def install_cookie_consent
        unless yes?("Add cookie consent? (y/n)")
          say "  Cookie consent skipped."
          return
        end

        copy_file(
          "_cookie_consent.html.erb",
          "app/views/shared/_cookie_consent.html.erb"
        )

        copy_file(
          "cookie_consent_controller.js",
          "app/javascript/controllers/cookie_consent_controller.js"
        )

        @cookie_consent_installed = true

        say "  Cookie consent installed."
      end

      def copy_navigation
        copy_file "_navigation.html.erb",
                  "app/views/shared/_navigation.html.erb"
      end

      def copy_navigation_controller
        copy_file "navigation_controller.js",
                  "app/javascript/controllers/navigation_controller.js"
      end

      def copy_theme_controller
        copy_file "theme_controller.js",
                  "app/javascript/controllers/theme_controller.js"
      end

      def copy_theme_switcher
        copy_file(
          "_theme_switcher.html.erb",
          "app/views/shared/_theme_switcher.html.erb"
        )
      end

      def copy_b4um_config
        copy_file "b4um.yml",
                  "config/b4um.yml"

        return unless @sitemap_installed
        return unless @sitemap_titles

        config_path = "config/b4um.yml"
        full_config_path = File.join(destination_root, config_path)

        config = YAML.safe_load_file(full_config_path) || {}

        config["sitemap"] = @sitemap_titles.each_with_index.map do |title, index|
          {
            "key" => "column_#{index + 1}",
            "title" => title
          }
        end

        File.write(
          full_config_path,
          config.to_yaml
        )
      end

      def copy_image_preview_controller
        copy_file "image_preview_controller.js",
                  "app/javascript/controllers/image_preview_controller.js"
      end

      def copy_image_lightbox_controller
        copy_file "image_lightbox_controller.js",
                  "app/javascript/controllers/image_lightbox_controller.js"
      end

      def copy_dismissible_controller
        copy_file "dismissible_controller.js",
                  "app/javascript/controllers/dismissible_controller.js"
      end

      def copy_navigation_helper
        copy_file "navigation_helper.rb",
                  "app/helpers/navigation_helper.rb"
      end

      def copy_b4um_helper
        copy_file "b4um_helper.rb",
                  "app/helpers/b4um_helper.rb"
      end

      def update_application_layout
        layout_path = "app/views/layouts/application.html.erb"
        full_layout_path = File.join(destination_root, layout_path)

        ensure_page_top_anchor(layout_path, full_layout_path)
        ensure_navigation(layout_path, full_layout_path)
        ensure_main_container(layout_path, full_layout_path)
        ensure_hero(layout_path, full_layout_path)
        ensure_theme_switcher(layout_path, full_layout_path)
        ensure_footer(layout_path, full_layout_path)
        ensure_sitemap_footer_render
        ensure_cookie_consent(layout_path, full_layout_path)
        ensure_cookie_consent_footer_link
      end

      def install_selected_gems
        return unless @gems_added

        say "Installing selected gems..."

        run "bundle install"

        say "Selected gems installed."
      end

      private

      def ask_sitemap_column_count
        loop do
          answer = ask(
            "Number of sitemap columns [4]:"
          ).to_s.strip

          return 4 if answer.empty?

          column_count = Integer(answer, exception: false)

          return column_count if column_count&.between?(2, 5)

          say "  Please choose between 2 and 5 sitemap columns."
        end
      end

      def ensure_navigation(layout_path, full_layout_path)
        layout = File.read(full_layout_path)

        return if layout.include?('render "shared/navigation"')

        gsub_file(
          layout_path,
          '<div id="b4um-page-top"></div>',
          <<~ERB.chomp
            <div id="b4um-page-top"></div>
            <%= render "shared/navigation" %>
          ERB
        )
      end

      def ensure_main_container(layout_path, full_layout_path)
        layout = File.read(full_layout_path)

        return if layout.include?('class="container"')

        gsub_file(
          layout_path,
          '<%= render "shared/navigation" %>',
          <<~ERB.chomp
            <%= render "shared/navigation" %>

            <main class="container">
              <% flash.each do |type, message| %>
                <div class="flash <%= "flash--" + type.to_s %>"
                    data-controller="dismissible">
                  <%= message %>

                  <button type="button"
                          class="flash__close"
                          data-action="dismissible#dismiss"
                          aria-label="Close">
                    &times;
                  </button>
                </div>
              <% end %>
          ERB
        )

        gsub_file(
          layout_path,
          "</body>",
          "  </main>\n</body>"
        )
      end

      def ensure_hero(layout_path, full_layout_path)
        return unless @hero_installed

        layout = File.read(full_layout_path)

        return if layout.include?('render "shared/hero"')

        gsub_file(
          layout_path,
          '<main class="container">',
          <<~ERB.chomp
            <main class="container">
                  <%= render "shared/hero" if respond_to?(:root_path) && request.path == root_path %>
          ERB
        )
      end

      def ensure_theme_switcher(layout_path, full_layout_path)
        layout = File.read(full_layout_path)

        return if layout.include?('render "shared/theme_switcher"')

        gsub_file(
          layout_path,
          "</body>",
          <<~ERB.chomp
            <%= render "shared/theme_switcher" %>
            </body>
          ERB
        )
      end

      def ensure_footer(layout_path, full_layout_path)
        return unless @footer_installed

        layout = File.read(full_layout_path)

        return if layout.include?('render "shared/footer"')

        gsub_file(
          layout_path,
          "</body>",
          <<~ERB.chomp
            <%= render "shared/footer" %>
            </body>
          ERB
        )
      end

      def ensure_cookie_consent(layout_path, full_layout_path)
        return unless @cookie_consent_installed

        layout = File.read(full_layout_path)

        return if layout.include?('render "shared/cookie_consent"')

        gsub_file(
          layout_path,
          "</body>",
          <<~ERB.chomp
            <%= render "shared/cookie_consent" %>
            </body>
          ERB
        )
      end

      def ensure_sitemap_footer_render
        return unless @sitemap_installed

        footer_path = "app/views/shared/_footer.html.erb"
        full_footer_path = File.join(destination_root, footer_path)

        return unless File.exist?(full_footer_path)

        footer = File.read(full_footer_path)

        return if footer.include?('render "shared/sitemap"')

        gsub_file(
          footer_path,
          '<div class="b4um-footer__inner">',
          <<~ERB.chomp
            <%= render "shared/sitemap" %>

            <div class="b4um-footer__inner">
          ERB
        )
      end

      def ensure_cookie_consent_footer_link
        return unless @cookie_consent_installed

        footer_path = "app/views/shared/_footer.html.erb"
        full_footer_path = File.join(destination_root, footer_path)

        return unless File.exist?(full_footer_path)

        footer = File.read(full_footer_path)

        return if footer.include?("data-b4um-cookie-consent-open")
        return unless footer.include?("<%# B4UM_FOOTER_LINKS %>")

        gsub_file(
          footer_path,
          "<%# B4UM_FOOTER_LINKS %>",
          <<~ERB.chomp
            <button
              type="button"
              class="b4um-footer__link b4um-footer__link--button"
              data-b4um-cookie-consent-open
            >
              Cookie-Einstellungen
            </button>

            <%# B4UM_FOOTER_LINKS %>
          ERB
        )
      end

      def ensure_page_top_anchor(layout_path, full_layout_path)
        layout = File.read(full_layout_path)

        return if layout.include?('id="b4um-page-top"')

        gsub_file(
          layout_path,
          "<body>",
          <<~ERB.chomp
            <body>
              <div id="b4um-page-top"></div>
          ERB
        )
      end
    end
  end
end
