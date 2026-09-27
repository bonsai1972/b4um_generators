# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "generators/b4um/readable/readable_generator"

RSpec.describe B4um::Generators::ReadableGenerator do
  around do |example|
    Dir.mktmpdir("b4um_readable_test") do |directory|
      @destination_root = directory
      example.run
    end
  end

  def create_model(name, content)
    model_directory = File.join(
      @destination_root,
      "app/models"
    )

    FileUtils.mkdir_p(model_directory)

    File.write(
      File.join(model_directory, "#{name}.rb"),
      content
    )
  end

  it "loads the B4UM readable generator" do
    expect(described_class).to be < Rails::Generators::NamedBase
  end

  it "adds to_param to an existing model" do
    create_model(
      "product",
      <<~RUBY
        class Product < ApplicationRecord
        end
      RUBY
    )

    stub_const(
      "Product",
      Class.new do
        def self.column_names
          %w[id name description price]
        end
      end
    )

    generator = described_class.new(
      %w[Product name],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    model = File.read(
      File.join(
        @destination_root,
        "app/models/product.rb"
      )
    )

    expect(model).to include(
      "def to_param"
    )

    expect(model).to include(
      "\"\#{id} \#{name}\".parameterize"
    )
  end

  it "raises an error when the model does not exist" do
    generator = described_class.new(
      %w[Product name],
      {},
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      "Model not found: app/models/product.rb"
    )
  end

  it "raises an error when the attribute does not exist" do
    create_model(
      "product",
      <<~RUBY
        class Product < ApplicationRecord
        end
      RUBY
    )

    stub_const(
      "Product",
      Class.new do
        def self.column_names
          %w[id name]
        end
      end
    )

    generator = described_class.new(
      %w[Product title],
      {},
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      "Attribute not found: Product#title"
    )
  end

  it "does not overwrite an existing to_param method" do
    create_model(
      "product",
      <<~RUBY
        class Product < ApplicationRecord
          def to_param
            "existing"
          end
        end
      RUBY
    )

    stub_const(
      "Product",
      Class.new do
        def self.column_names
          %w[id name]
        end
      end
    )

    generator = described_class.new(
      %w[Product name],
      {},
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      "Product already defines to_param."
    )

    model = File.read(
      File.join(
        @destination_root,
        "app/models/product.rb"
      )
    )

    expect(
      model.scan("def to_param").count
    ).to eq(1)

    expect(model).to include(
      '"existing"'
    )
  end
end
