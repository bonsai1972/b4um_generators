# frozen_string_literal: true

require "spec_helper"
require "rails/generators"
require_relative "../../../lib/generators/b4um/comments/comments_generator"

RSpec.describe B4um::Generators::CommentsGenerator do
  it "loads the B4UM comments generator" do
    expect(described_class).to be < Rails::Generators::Base
  end

  it "generates the polymorphic comment model and migration" do
    destination = File.expand_path("../../tmp/comments_generator", __dir__)

    FileUtils.rm_rf(destination)
    FileUtils.mkdir_p(destination)

    FileUtils.mkdir_p(
      File.join(destination, "app/models")
    )

    File.write(
      File.join(destination, "app/models/article.rb"),
      <<~RUBY
        class Article < ApplicationRecord
        end
      RUBY
    )

    FileUtils.mkdir_p(
      File.join(destination, "config")
    )

    File.write(
      File.join(destination, "config/routes.rb"),
      <<~RUBY
        Rails.application.routes.draw do
          resources :articles
        end
      RUBY
    )

    FileUtils.mkdir_p(
      File.join(destination, "app/views/articles")
    )

    File.write(
      File.join(destination, "app/views/articles/show.html.erb"),
      <<~ERB
        <h1>Article</h1>

        <%= render @article %>
      ERB
    )

    generator = described_class.new(
      ["Article"],
      {},
      destination_root: destination
    )

    generator.invoke_all

    controller = File.read(
      File.join(destination, "app/controllers/comments_controller.rb")
    )

    expect(controller).to include(
      "class CommentsController < ApplicationController"
    )
    expect(controller).to include(
      "before_action :set_commentable"
    )
    expect(controller).to include(
      "@commentable.comments.build(comment_params)"
    )

    expect(controller).to include(
      '"article_id" => Article'
    )

    expect(controller).to include(
      "COMMENTABLES.find"
    )

    expect(controller).to include(
      "commentable_class.find(params[param_name])"
    )

    expect(controller).to include(
      "params.expect(comment: [:body])"
    )

    comments_partial = File.read(
      File.join(destination, "app/views/comments/_comments.html.erb")
    )

    expect(comments_partial).to include(
      "commentable.comments.order(created_at: :desc)"
    )

    expect(comments_partial).to include(
      "form_with model: [commentable, Comment.new]"
    )

    expect(comments_partial).to include(
      'button_to "Delete"'
    )

    expect(comments_partial).to include(
      "[commentable, comment]"
    )

    routes = File.read(
      File.join(destination, "config/routes.rb")
    )

    expect(routes).to include(
      [
        "  resources :articles do",
        "    resources :comments, only: %i[create destroy]",
        "  end",
        ""
      ].join("\n")
    )

    generator.add_comments_routes

    routes = File.read(
      File.join(destination, "config/routes.rb")
    )

    expect(
      routes.scan(
        "resources :comments, only: %i[create destroy]"
      ).count
    ).to eq(1)

    show_view = File.read(
      File.join(destination, "app/views/articles/show.html.erb")
    )

    expect(show_view).to include(
      '<%= render "comments/comments", commentable: @article %>'
    )

    generator.add_comments_to_show_view

    show_view = File.read(
      File.join(destination, "app/views/articles/show.html.erb")
    )

    expect(
      show_view.scan(
        '<%= render "comments/comments", commentable: @article %>'
      ).count
    ).to eq(1)

    commentable_model = File.read(
      File.join(destination, "app/models/article.rb")
    )

    expect(commentable_model).to include(
      <<~RUBY
        class Article < ApplicationRecord
          has_many :comments,
                   as: :commentable,
                   dependent: :destroy
        end
      RUBY
    )

    model = File.read(
      File.join(destination, "app/models/comment.rb")
    )

    expect(model).to include(
      "belongs_to :commentable, polymorphic: true"
    )
    expect(model).to include(
      "validates :body, presence: true"
    )

    migration = Dir.glob(
      File.join(
        destination,
        "db/migrate/*_create_comments.rb"
      )
    ).first

    expect(migration).not_to be_nil

    migration_content = File.read(migration)

    expect(migration_content).to include(
      "t.text :body, null: false"
    )
    expect(migration_content).to include(
      "t.references :commentable"
    )
    expect(migration_content).to include(
      "polymorphic: true"
    )
    expect(migration_content).to include(
      "null: false"
    )
  end

  it "does not duplicate the comments association" do
    destination = File.expand_path(
      "../../tmp/comments_generator_existing_association",
      __dir__
    )

    FileUtils.rm_rf(destination)

    FileUtils.mkdir_p(
      File.join(destination, "app/models")
    )

    model_path = File.join(
      destination,
      "app/models/article.rb"
    )

    File.write(
      model_path,
      <<~RUBY
        class Article < ApplicationRecord
        end
      RUBY
    )

    generator = described_class.new(
      ["Article"],
      {},
      destination_root: destination
    )

    generator.add_comments_association
    generator.add_comments_association

    model = File.read(model_path)

    expect(
      model.scan("has_many :comments,").count
    ).to eq(1)
  end

  it "does not create a second comments migration" do
    destination = File.expand_path(
      "../../tmp/comments_generator_existing_migration",
      __dir__
    )

    FileUtils.rm_rf(destination)

    migration_directory = File.join(
      destination,
      "db/migrate"
    )

    FileUtils.mkdir_p(migration_directory)

    existing_migration = File.join(
      migration_directory,
      "20260920000000_create_comments.rb"
    )

    File.write(
      existing_migration,
      "# Existing comments migration\n"
    )

    generator = described_class.new(
      ["Article"],
      {},
      destination_root: destination
    )

    generator.create_comments_migration

    migrations = Dir.glob(
      File.join(
        migration_directory,
        "*_create_comments.rb"
      )
    )

    expect(migrations).to eq(
      [existing_migration]
    )
  end

  it "does not overwrite an existing comments partial" do
    destination = File.expand_path(
      "../../tmp/comments_generator_existing_partial",
      __dir__
    )

    FileUtils.rm_rf(destination)

    partial_directory = File.join(
      destination,
      "app/views/comments"
    )

    FileUtils.mkdir_p(partial_directory)

    partial_path = File.join(
      partial_directory,
      "_comments.html.erb"
    )

    File.write(
      partial_path,
      "<%# Custom comments partial %>\n"
    )

    generator = described_class.new(
      ["Article"],
      {},
      destination_root: destination
    )

    generator.create_comments_partial

    partial = File.read(partial_path)

    expect(partial).to eq(
      "<%# Custom comments partial %>\n"
    )
  end

  it "does not overwrite an existing comment model" do
    destination = File.expand_path(
      "../../tmp/comments_generator_existing_model",
      __dir__
    )

    FileUtils.rm_rf(destination)

    FileUtils.mkdir_p(
      File.join(destination, "app/models")
    )

    comment_model_path = File.join(
      destination,
      "app/models/comment.rb"
    )

    File.write(
      comment_model_path,
      <<~RUBY
        class Comment < ApplicationRecord
          # Custom application code
        end
      RUBY
    )

    generator = described_class.new(
      ["Article"],
      {},
      destination_root: destination
    )

    generator.create_comment_model

    model = File.read(comment_model_path)

    expect(model).to include(
      "# Custom application code"
    )

    expect(model).not_to include(
      "belongs_to :commentable, polymorphic: true"
    )
  end

  it "upgrades a legacy comments controller" do
    destination = File.expand_path(
      "../../tmp/comments_generator_legacy_controller",
      __dir__
    )

    FileUtils.rm_rf(destination)

    controller_directory = File.join(
      destination,
      "app/controllers"
    )

    FileUtils.mkdir_p(controller_directory)

    controller_path = File.join(
      controller_directory,
      "comments_controller.rb"
    )

    File.write(
      controller_path,
      <<~RUBY
        class CommentsController < ApplicationController
          before_action :set_commentable

          def create
            @comment = @commentable.comments.build
          end

          private

          def set_commentable
            @commentable = Article.find(
              params[:article_id]
            )
          end
        end
      RUBY
    )

    generator = described_class.new(
      ["Product"],
      {},
      destination_root: destination
    )

    generator.create_comments_controller

    controller = File.read(controller_path)

    expect(controller).to include(
      '"article_id" => Article'
    )

    expect(controller).to include(
      '"product_id" => Product'
    )

    expect(controller).to include(
      [
        "  }.freeze",
        "  before_action :set_commentable"
      ].join("\n")
    )

    expect(controller).to include(
      "COMMENTABLES.find"
    )

    expect(controller).to include(
      "commentable_class.find(params[param_name])"
    )

    expect(controller).not_to include(
      "@commentable = Article.find("
    )
  end

  it "adds additional commentable models to the existing controller" do
    destination = File.expand_path(
      "../../tmp/comments_generator_multiple",
      __dir__
    )

    FileUtils.rm_rf(destination)

    FileUtils.mkdir_p(
      File.join(destination, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(destination, "app/controllers")
    )

    File.write(
      File.join(destination, "app/models/article.rb"),
      <<~RUBY
        class Article < ApplicationRecord
        end
      RUBY
    )

    File.write(
      File.join(destination, "app/models/product.rb"),
      <<~RUBY
        class Product < ApplicationRecord
        end
      RUBY
    )

    article_generator = described_class.new(
      ["Article"],
      {},
      destination_root: destination
    )

    article_generator.create_comments_controller

    product_generator = described_class.new(
      ["Product"],
      {},
      destination_root: destination
    )

    product_generator.create_comments_controller

    controller_path = File.join(
      destination,
      "app/controllers/comments_controller.rb"
    )

    controller = File.read(controller_path)

    expect(controller).to include(
      '"article_id" => Article'
    )

    expect(controller).to include(
      '"product_id" => Product'
    )

    product_generator.create_comments_controller

    controller = File.read(controller_path)

    expect(
      controller.scan('"product_id" => Product').count
    ).to eq(1)
  end

  it "stops when an unknown comments controller already exists" do
    destination = File.expand_path(
      "../../tmp/comments_generator_custom_controller",
      __dir__
    )

    FileUtils.rm_rf(destination)

    controller_directory = File.join(
      destination,
      "app/controllers"
    )

    FileUtils.mkdir_p(controller_directory)

    controller_path = File.join(
      controller_directory,
      "comments_controller.rb"
    )

    File.write(
      controller_path,
      <<~RUBY
        class CommentsController < ApplicationController
          def create
            # Custom implementation
          end
        end
      RUBY
    )

    original_controller = File.read(controller_path)

    generator = described_class.new(
      ["Product"],
      {},
      destination_root: destination
    )

    expect do
      generator.create_comments_controller
    end.to raise_error(
      Thor::Error,
      /existing CommentsController/
    )

    expect(
      File.read(controller_path)
    ).to eq(original_controller)
  end

  it "stops when the commentable model does not exist" do
    destination = File.expand_path(
      "../../tmp/comments_generator_missing_model",
      __dir__
    )

    FileUtils.rm_rf(destination)
    FileUtils.mkdir_p(destination)

    generator = described_class.new(
      ["DoesNotExist"],
      {},
      destination_root: destination
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      "Commentable model not found: app/models/does_not_exist.rb"
    )

    expect(
      File.exist?(
        File.join(destination, "app/models/comment.rb")
      )
    ).to be(false)

    expect(
      Dir.glob(
        File.join(destination, "db/migrate/*_create_comments.rb")
      )
    ).to be_empty
  end
end
