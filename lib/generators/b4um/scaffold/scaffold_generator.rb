# frozen_string_literal: true

require "rails/generators"
require "rails/generators/rails/scaffold/scaffold_generator"

module B4um
  module Generators
    class ScaffoldGenerator < Rails::Generators::ScaffoldGenerator
      class << self
        def desc(_description = nil)
          "Generates a B4UM scaffold."
        end
      end
    end
  end
end
