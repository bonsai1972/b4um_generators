# frozen_string_literal: true

require_relative "lib/b4um_generators/version"

Gem::Specification.new do |spec|
  spec.name = "b4um_generators"
  spec.version = B4umGenerators::VERSION
  spec.authors = ["Alexander Baum"]
  spec.email = ["info@b4um.com"]

  spec.summary = "Rails generators for b4um applications"
  spec.description = "Reusable Rails generators, templates and application defaults for b4um projects."
  spec.homepage = "https://www.b4um.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |file|
      file.start_with?("test/", "spec/", "features/", ".git", "Gemfile")
    end
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |file| File.basename(file) }
  spec.require_paths = ["lib"]
  spec.add_dependency "railties", ">= 8.0", "< 9.0"
end
