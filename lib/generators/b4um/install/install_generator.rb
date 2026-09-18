# frozen_string_literal: true

require "rails/generators"

module B4um
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs the B4UM base setup."

      def create_stylesheet
        copy_file "b4um.css", "app/assets/stylesheets/b4um.css"
      end

      def update_application_layout
        gsub_file "app/views/layouts/application.html.erb",
                  "<body>",
                  <<~ERB.chomp
                    <body>
                      <main class="container">
                        <% flash.each do |type, message| %>
                          <div class="flash flash--<%= type %>">
                            <%= message %>
                          </div>
                        <% end %>
                  ERB

        gsub_file "app/views/layouts/application.html.erb",
                  "</body>",
                  "    </main>\n  </body>"
      end
    end
  end
end
