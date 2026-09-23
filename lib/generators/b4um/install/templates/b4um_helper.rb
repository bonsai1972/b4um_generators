# frozen_string_literal: true

require "yaml"

module B4umHelper
  def b4um_sitemap_columns
    config_path = Rails.root.join("config/b4um.yml")

    return [] unless File.exist?(config_path)

    config = YAML.safe_load_file(config_path) || {}

    Array(config["sitemap"])
  end

  def b4um_sitemap_path(route)
    route_name = route.to_s

    return unless route_name.match?(/\A[a-z0-9_]+_path\z/)

    route_helpers = Rails.application.routes.url_helpers

    return unless route_helpers.respond_to?(route_name)

    route_helpers.public_send(route_name)
  end
end
