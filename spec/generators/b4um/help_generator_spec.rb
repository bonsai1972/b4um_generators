# frozen_string_literal: true

require "spec_helper"
require "generators/b4um/help/help_generator"

RSpec.describe B4um::Generators::HelpGenerator do
  it "loads the B4UM help generator" do
    expect(described_class).to be < Rails::Generators::Base
  end

  it "documents the B4UM install generator" do
    generator = described_class.new

    expect(generator).to receive(:say) do |text|
      expect(text).to include(
        "bin/rails generate b4um:install"
      )

      expect(text).to include(
        "bcrypt for password support"
      )

      expect(text).to include(
        "Active Storage for image attachments"
      )

      expect(text).to include(
        "Hero section"
      )

      expect(text).to include(
        "Footer"
      )
    end

    generator.show_help
  end

  it "documents the B4UM Bento card system" do
    generator = described_class.new

    expect(generator).to receive(:say) do |text|
      expect(text).to include(
        "BENTO / CARDS"
      )

      expect(text).to include(
        "b4um-card--wide"
      )

      expect(text).to include(
        "b4um-card--large"
      )

      expect(text).to include(
        "b4um-card--full"
      )

      expect(text).to include(
        "b4um-card--soft"
      )

      expect(text).to include(
        "B4UM scaffolds automatically use the Bento card system"
      )

      expect(text).to include(
        "1 - wide"
      )

      expect(text).to include(
        "4 - large"
      )

      expect(text).to include(
        "Long text fields are shortened on index cards"
      )
    end

    generator.show_help
  end

  it "documents readable URL parameters" do
    generator = described_class.new

    expect(generator).to receive(:say) do |text|
      expect(text).to include(
        "READABLE URL PARAMETERS"
      )

      expect(text).to include(
        "--param=ATTRIBUTE"
      )

      expect(text).to include(
        "--param=title"
      )

      expect(text).to include(
        "\"\#{id} \#{title}\".parameterize"
      )

      expect(text).to include(
        "/articles/17-my-first-article"
      )
    end

    generator.show_help
  end

  it "documents password support" do
    generator = described_class.new

    expect(generator).to receive(:say) do |text|
      expect(text).to include(
        "password_digest:string"
      )

      expect(text).to include(
        "Password support requires bcrypt."
      )
    end

    generator.show_help
  end

  it "documents Active Storage image support" do
    generator = described_class.new

    expect(generator).to receive(:say) do |text|
      expect(text).to include(
        "image:attachment"
      )

      expect(text).to include(
        "images:attachments"
      )

      expect(text).to include(
        "Image preview before saving"
      )

      expect(text).to include(
        "Remove individual existing images"
      )

      expect(text).to include(
        "Image lightbox"
      )

      expect(text).to include(
        "Mouse and touch swipe"
      )

      expect(text).to include(
        "Keyboard navigation"
      )
    end

    generator.show_help
  end

  it "documents the B4UM Bento generator" do
    generator = described_class.new

    expect(generator).to receive(:say) do |text|
      expect(text).to include(
        "BENTO"
      )

      expect(text).to include(
        "bin/rails generate b4um:bento MODEL"
      )

      expect(text).to include(
        "bin/rails generate b4um:bento Product"
      )

      expect(text).to include(
        "app/views/products/_bento.html.erb"
      )

      expect(text).to include(
        "The model and its resource partial must already exist."
      )

      expect(text).to include(
        "app/views/products/_product.html.erb"
      )

      expect(text).to include(
        "text fields are shortened to 160 characters"
      )

      expect(text).to include(
        '<%= render "bento", products: @products %>'
      )

      expect(text).to include(
        '<%= render "products/bento", products: @featured_products %>'
      )

      expect(text).to include(
        "No migrations, routes or controllers are generated"
      )
    end

    generator.show_help
  end

  it "documents the B4UM controller generator" do
    generator = described_class.new

    expect(generator).to receive(:say) do |text|
      expect(text).to include(
        "bin/rails generate b4um:controller NAME ACTIONS"
      )

      expect(text).to include(
        "bin/rails generate b4um:controller Pages home about impressum agb"
      )

      expect(text).to include(
        "Adds action links to the B4UM navigation automatically"
      )
    end

    generator.show_help
  end
  it "documents the B4UM comments generator" do
    generator = described_class.new

    expect(generator).to receive(:say) do |text|
      expect(text).to include(
        "COMMENTS"
      )

      expect(text).to include(
        "bin/rails generate b4um:comments MODEL"
      )

      expect(text).to include(
        "bin/rails generate b4um:comments Article"
      )

      expect(text).to include(
        "Polymorphic Comment model"
      )

      expect(text).to include(
        "Support for multiple commentable models"
      )

      expect(text).to include(
        "bin/rails generate b4um:comments Product"
      )

      expect(text).to include(
        "Unknown custom comments controllers are left unchanged"
      )
    end

    generator.show_help
  end
end
