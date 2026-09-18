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
        layout_path = "app/views/layouts/application.html.erb"

        return if File.read(File.join(destination_root, layout_path)).include?('class="container"')

        gsub_file layout_path,
                  "<body>",
                  <<~ERB.chomp
                    <body>
                      <main class="container">
                        <% flash.each do |type, message| %>
                          <div class="flash <%= "flash--" + type.to_s %>">
                            <%= message %>
                          </div>
                        <% end %>
                  ERB

        gsub_file layout_path,
                  "</body>",
                  "</main>\n</body>"
      end
    end
  end
end
