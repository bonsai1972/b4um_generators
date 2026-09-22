# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "spec_helper"
require "generators/b4um/trix/trix_generator"

RSpec.describe B4um::Generators::TrixGenerator do
  before do
    @destination_root = Dir.mktmpdir
  end

  after do
    FileUtils.remove_entry(@destination_root)
  end

  def build_generator
    generator = described_class.new(
      %w[Article content],
      {},
      destination_root: @destination_root
    )

    allow(generator).to receive(:rails_command)

    generator
  end

  it "loads the B4UM Trix generator" do
    expect(described_class).to be < Rails::Generators::Base
  end

  it "describes the B4UM Trix generator" do
    expect(described_class.desc).to eq(
      "Adds Action Text with Trix to an existing B4UM resource."
    )
  end

  it "accepts a model name and attribute name" do
    generator = described_class.new(
      %w[Article content]
    )

    expect(generator.name).to eq("Article")
    expect(generator.attribute).to eq("content")
  end

  it "raises an error when the model does not exist" do
    generator = described_class.new(
      %w[Article content]
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      "Model Article does not exist."
    )
  end

  it "adds has_rich_text to the model" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/views/articles")
    )

    File.write(
      File.join(@destination_root, "app/models/article.rb"),
      <<~RUBY
        class Article < ApplicationRecord
        end
      RUBY
    )

    File.write(
      File.join(@destination_root, "app/views/articles/_form.html.erb"),
      <<~ERB
        <%= form_with(model: article) do |form| %>
          <%= form.text_area :content %>
        <% end %>
      ERB
    )

    generator = build_generator

    generator.invoke_all

    model = File.read(
      File.join(@destination_root, "app/models/article.rb")
    )

    expect(model).to include(
      "has_rich_text :content"
    )
  end

  it "does not duplicate has_rich_text when invoked twice" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/views/articles")
    )

    File.write(
      File.join(@destination_root, "app/models/article.rb"),
      <<~RUBY
        class Article < ApplicationRecord
        end
      RUBY
    )

    File.write(
      File.join(@destination_root, "app/views/articles/_form.html.erb"),
      <<~ERB
        <%= form_with(model: article) do |form| %>
          <%= form.text_area :content %>
        <% end %>
      ERB
    )

    2.times do
      generator = build_generator
      generator.invoke_all
    end

    model = File.read(
      File.join(@destination_root, "app/models/article.rb")
    )

    expect(
      model.scan("has_rich_text :content").length
    ).to eq(1)
  end

  it "replaces the selected form field with a rich text area" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/views/articles")
    )

    File.write(
      File.join(@destination_root, "app/models/article.rb"),
      <<~RUBY
        class Article < ApplicationRecord
        end
      RUBY
    )

    File.write(
      File.join(@destination_root, "app/views/articles/_form.html.erb"),
      <<~ERB
        <%= form_with(model: article, class: "form") do |form| %>
          <div class="form-field form-field--textarea">
            <%= form.text_area :content,
                  class: "form-textarea",
                  placeholder: " " %>
            <%= form.label :content, class: "form-label" %>
          </div>
        <% end %>
      ERB
    )

    generator = build_generator

    generator.invoke_all

    form = File.read(
      File.join(
        @destination_root,
        "app/views/articles/_form.html.erb"
      )
    )

    expect(form).to include(
      "form.rich_text_area :content"
    )

    expect(form).to include(
      'class="form-field form-field--rich-text"'
    )

    expect(form).not_to include(
      'class="form-field form-field--textarea"'
    )

    expect(form).not_to include(
      "form.text_area :content"
    )
  end

  it "raises an error when the form does not exist" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    File.write(
      File.join(@destination_root, "app/models/article.rb"),
      <<~RUBY
        class Article < ApplicationRecord
        end
      RUBY
    )

    generator = build_generator

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      "Form for Article does not exist."
    )
  end

  it "does not duplicate the rich text form field when invoked twice" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/views/articles")
    )

    File.write(
      File.join(@destination_root, "app/models/article.rb"),
      <<~RUBY
        class Article < ApplicationRecord
        end
      RUBY
    )

    File.write(
      File.join(@destination_root, "app/views/articles/_form.html.erb"),
      <<~ERB
        <%= form_with(model: article) do |form| %>
          <%= form.text_area :content %>
        <% end %>
      ERB
    )

    2.times do
      generator = build_generator
      generator.invoke_all
    end

    form = File.read(
      File.join(
        @destination_root,
        "app/views/articles/_form.html.erb"
      )
    )

    expect(
      form.scan("form.rich_text_area :content").length
    ).to eq(1)

    expect(form).not_to include(
      "form.text_area :content"
    )
  end

  it "installs Action Text when it is not installed" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/views/articles")
    )

    File.write(
      File.join(@destination_root, "app/models/article.rb"),
      <<~RUBY
        class Article < ApplicationRecord
        end
      RUBY
    )

    File.write(
      File.join(@destination_root, "app/views/articles/_form.html.erb"),
      <<~ERB
        <%= form_with(model: article) do |form| %>
          <%= form.text_area :content %>
        <% end %>
      ERB
    )

    generator = described_class.new(
      %w[Article content],
      {},
      destination_root: @destination_root
    )

    expect(generator).to receive(:rails_command)
      .with("action_text:install")

    generator.invoke_all
  end

  it "does not install Action Text when it is already installed" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/views/articles")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "db/migrate")
    )

    File.write(
      File.join(@destination_root, "app/models/article.rb"),
      <<~RUBY
        class Article < ApplicationRecord
        end
      RUBY
    )

    File.write(
      File.join(@destination_root, "app/views/articles/_form.html.erb"),
      <<~ERB
        <%= form_with(model: article) do |form| %>
          <%= form.text_area :content %>
        <% end %>
      ERB
    )

    File.write(
      File.join(
        @destination_root,
        "db/migrate/20260922000000_create_action_text_tables.action_text.rb"
      ),
      "# Action Text migration\n"
    )

    generator = described_class.new(
      %w[Article content],
      {},
      destination_root: @destination_root
    )

    expect(generator).not_to receive(:rails_command)

    generator.invoke_all
  end

  it "converts rich text to plain text before truncating it" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/views/articles")
    )

    File.write(
      File.join(@destination_root, "app/models/article.rb"),
      <<~RUBY
        class Article < ApplicationRecord
        end
      RUBY
    )

    File.write(
      File.join(@destination_root, "app/views/articles/_form.html.erb"),
      <<~ERB
        <%= form_with(model: article) do |form| %>
          <%= form.text_area :content %>
        <% end %>
      ERB
    )

    File.write(
      File.join(@destination_root, "app/views/articles/_article.html.erb"),
      <<~ERB
        <span class="resource-value">
          <% if local_assigns[:compact] %>
            <%= truncate(article.content, length: 160) %>
          <% else %>
            <%= article.content %>
          <% end %>
        </span>
      ERB
    )

    generator = build_generator

    generator.invoke_all

    partial = File.read(
      File.join(
        @destination_root,
        "app/views/articles/_article.html.erb"
      )
    )

    expect(partial).to include(
      "truncate(article.content.to_plain_text, length: 160)"
    )

    expect(partial).not_to include(
      "truncate(article.content, length: 160)"
    )
  end

  it "adds image lightbox support to the rich text field" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/views/articles")
    )

    File.write(
      File.join(@destination_root, "app/models/article.rb"),
      <<~RUBY
        class Article < ApplicationRecord
        end
      RUBY
    )

    File.write(
      File.join(@destination_root, "app/views/articles/_form.html.erb"),
      <<~ERB
        <%= form_with(model: article) do |form| %>
          <%= form.text_area :content %>
        <% end %>
      ERB
    )

    File.write(
      File.join(@destination_root, "app/views/articles/_article.html.erb"),
      <<~ERB
        <span class="resource-value">
          <% if local_assigns[:compact] %>
            <%= truncate(article.content, length: 160) %>
          <% else %>
            <%= article.content %>
          <% end %>
        </span>
      ERB
    )

    2.times do
      generator = build_generator
      generator.invoke_all
    end

    partial = File.read(
      File.join(
        @destination_root,
        "app/views/articles/_article.html.erb"
      )
    )

    expect(partial).to include(
      'data-controller="image-lightbox"'
    )

    expect(partial).to include(
      'data-image-lightbox-target="overlay"'
    )

    expect(partial).to include(
      'data-image-lightbox-target="image"'
    )

    expect(partial).to include(
      'data-image-lightbox-target="previousButton"'
    )

    expect(partial).to include(
      'data-image-lightbox-target="nextButton"'
    )

    expect(
      partial.scan('data-controller="image-lightbox"').count
    ).to eq(1)

    expect(
      partial.scan('data-image-lightbox-target="overlay"').count
    ).to eq(1)
  end

  it "adds image lightbox attributes to Action Text image blobs" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/views/articles")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/views/active_storage/blobs")
    )

    File.write(
      File.join(@destination_root, "app/models/article.rb"),
      <<~RUBY
        class Article < ApplicationRecord
        end
      RUBY
    )

    File.write(
      File.join(@destination_root, "app/views/articles/_form.html.erb"),
      <<~ERB
        <%= form_with(model: article) do |form| %>
          <%= form.text_area :content %>
        <% end %>
      ERB
    )

    File.write(
      File.join(
        @destination_root,
        "app/views/active_storage/blobs/_blob.html.erb"
      ),
      <<~ERB
        <figure class="attachment attachment--<%= blob.representable? ? "preview" : "file" %>">
          <% if blob.representable? %>
            <%= image_tag blob.representation(resize_to_limit: [ 1024, 768 ]) %>
          <% end %>
        </figure>
      ERB
    )

    generator = build_generator

    generator.invoke_all

    blob_partial = File.read(
      File.join(
        @destination_root,
        "app/views/active_storage/blobs/_blob.html.erb"
      )
    )

    expect(blob_partial).to include(
      'image_lightbox_target: "item"'
    )

    expect(blob_partial).to include(
      'action: "click->image-lightbox#open"'
    )

    expect(blob_partial).to include(
      "image_lightbox_url:"
    )

    expect(blob_partial).to include(
      "rails_blob_path(blob"
    )
  end

  it "does not duplicate image lightbox attributes when invoked twice" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/views/articles")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/views/active_storage/blobs")
    )

    File.write(
      File.join(@destination_root, "app/models/article.rb"),
      <<~RUBY
        class Article < ApplicationRecord
        end
      RUBY
    )

    File.write(
      File.join(@destination_root, "app/views/articles/_form.html.erb"),
      <<~ERB
        <%= form_with(model: article) do |form| %>
          <%= form.text_area :content %>
        <% end %>
      ERB
    )

    File.write(
      File.join(
        @destination_root,
        "app/views/active_storage/blobs/_blob.html.erb"
      ),
      <<~ERB
        <figure class="attachment attachment--<%= blob.representable? ? "preview" : "file" %>">
          <% if blob.representable? %>
            <%= image_tag blob.representation(resize_to_limit: [ 1024, 768 ]) %>
          <% end %>
        </figure>
      ERB
    )

    2.times do
      generator = build_generator
      generator.invoke_all
    end

    blob_partial = File.read(
      File.join(
        @destination_root,
        "app/views/active_storage/blobs/_blob.html.erb"
      )
    )

    expect(
      blob_partial.scan('image_lightbox_target: "item"').length
    ).to eq(1)

    expect(
      blob_partial.scan('action: "click->image-lightbox#open"').length
    ).to eq(1)

    expect(
      blob_partial.scan("rails_blob_path(blob").length
    ).to eq(1)
  end

  it "creates an Action Text initializer for image lightbox attributes" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/views/articles")
    )

    File.write(
      File.join(@destination_root, "app/models/article.rb"),
      <<~RUBY
        class Article < ApplicationRecord
        end
      RUBY
    )

    File.write(
      File.join(@destination_root, "app/views/articles/_form.html.erb"),
      <<~ERB
        <%= form_with(model: article) do |form| %>
          <%= form.text_area :content %>
        <% end %>
      ERB
    )

    generator = build_generator
    generator.invoke_all

    initializer_path = File.join(
      @destination_root,
      "config/initializers/action_text.rb"
    )

    expect(File).to exist(initializer_path)

    initializer = File.read(initializer_path)

    expect(initializer).to include(
      "ActionText::ContentHelper.allowed_attributes"
    )

    expect(initializer).to include(
      "data-image-lightbox-target"
    )

    expect(initializer).to include(
      "data-image-lightbox-url"
    )

    expect(initializer).to include(
      "data-image-lightbox-alt"
    )

    expect(initializer).to include(
      "data-action"
    )
  end

  it "adds image lightbox attributes to an existing Action Text initializer" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/views/articles")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "config/initializers")
    )

    File.write(
      File.join(@destination_root, "app/models/article.rb"),
      <<~RUBY
        class Article < ApplicationRecord
        end
      RUBY
    )

    File.write(
      File.join(@destination_root, "app/views/articles/_form.html.erb"),
      <<~ERB
        <%= form_with(model: article) do |form| %>
          <%= form.text_area :content %>
        <% end %>
      ERB
    )

    initializer_path = File.join(
      @destination_root,
      "config/initializers/action_text.rb"
    )

    File.write(
      initializer_path,
      <<~RUBY
        # Existing Action Text configuration

        Rails.application.config.to_prepare do
          # Keep this configuration.
        end
      RUBY
    )

    generator = build_generator
    generator.invoke_all

    initializer = File.read(initializer_path)

    expect(initializer).to include(
      "# Existing Action Text configuration"
    )

    expect(initializer).to include(
      "# Keep this configuration."
    )

    expect(initializer).to include(
      "data-image-lightbox-target"
    )
  end

  it "does not duplicate image lightbox configuration in the Action Text initializer" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/views/articles")
    )

    File.write(
      File.join(@destination_root, "app/models/article.rb"),
      <<~RUBY
        class Article < ApplicationRecord
        end
      RUBY
    )

    File.write(
      File.join(@destination_root, "app/views/articles/_form.html.erb"),
      <<~ERB
        <%= form_with(model: article) do |form| %>
          <%= form.text_area :content %>
        <% end %>
      ERB
    )

    2.times do
      generator = build_generator
      generator.invoke_all
    end

    initializer = File.read(
      File.join(
        @destination_root,
        "config/initializers/action_text.rb"
      )
    )

    expect(
      initializer.scan("data-image-lightbox-target").length
    ).to eq(1)

    expect(
      initializer.scan("data-image-lightbox-url").length
    ).to eq(1)

    expect(
      initializer.scan("data-image-lightbox-alt").length
    ).to eq(1)

    expect(
      initializer.scan("data-action").length
    ).to eq(1)
  end
end
