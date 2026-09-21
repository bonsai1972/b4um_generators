# frozen_string_literal: true

require "rails/generators"

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

        if File.read(File.join(destination_root, "Gemfile")).match?(/gem ["']bcrypt["']/)
          say "  bcrypt is already present in the Gemfile."
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

        generate "active_storage:install"

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
          say "  Footer skipped."
          return
        end

        copy_file(
          "_footer.html.erb",
          "app/views/shared/_footer.html.erb"
        )

        @footer_installed = true

        say "  Footer installed."
      end

      def copy_navigation
        copy_file "_navigation.html.erb",
                  "app/views/shared/_navigation.html.erb"
      end

      def copy_navigation_controller
        copy_file "navigation_controller.js",
                  "app/javascript/controllers/navigation_controller.js"
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

      def update_application_layout
        layout_path = "app/views/layouts/application.html.erb"
        full_layout_path = File.join(destination_root, layout_path)

        layout = File.read(full_layout_path)

        unless layout.include?('render "shared/navigation"')
          gsub_file(
            layout_path,
            "<body>",
            <<~ERB.chomp
              <body>
                <%= render "shared/navigation" %>
            ERB
          )
        end

        layout = File.read(full_layout_path)

        unless layout.include?('class="container"')
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

        if @hero_installed
          layout = File.read(full_layout_path)

          unless layout.include?('render "shared/hero"')
            gsub_file(
              layout_path,
              '<main class="container">',
              <<~ERB.chomp
                <main class="container">
                      <%= render "shared/hero" if request.path == root_path %>
              ERB
            )
          end
        end

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

      def install_selected_gems
        return unless @gems_added

        say "Installing selected gems..."

        run "bundle install"

        say "Selected gems installed."
      end
    end
  end
end
