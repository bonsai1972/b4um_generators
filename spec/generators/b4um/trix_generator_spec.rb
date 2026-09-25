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

  it "uses the B4UM rich text preview for compact resources" do
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
      "b4um_rich_text_preview(article.content, length: 160)"
    )

    expect(partial).not_to include(
      "truncate(article.content, length: 160)"
    )
  end

  it "upgrades an existing plain text rich text preview" do
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
          has_rich_text :content
        end
      RUBY
    )

    File.write(
      File.join(@destination_root, "app/views/articles/_form.html.erb"),
      <<~ERB
        <%= form_with(model: article) do |form| %>
          <%= form.rich_text_area :content %>
        <% end %>
      ERB
    )

    File.write(
      File.join(@destination_root, "app/views/articles/_article.html.erb"),
      <<~ERB
        <span class="resource-value">
          <% if local_assigns[:compact] %>
            <%= truncate(article.content.to_plain_text, length: 160) %>
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
      "b4um_rich_text_preview(article.content, length: 160)"
    )

    expect(partial).not_to include(
      "truncate(article.content.to_plain_text, length: 160)"
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

  it "adds video support to the Action Text blob partial" do
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
      "<% if blob.video? %>"
    )

    expect(blob_partial).to include(
      'video_tag rails_blob_path(blob, disposition: "inline")'
    )

    expect(blob_partial).to include(
      "controls: true"
    )

    expect(blob_partial).to include(
      "playsinline: true"
    )

    expect(blob_partial).to include(
      'preload: "metadata"'
    )

    expect(blob_partial).to include(
      'class: "b4um-rich-text-video"'
    )

    expect(blob_partial).to include(
      "<% elsif blob.representable? %>"
    )
  end

  it "does not duplicate image lightbox or video attributes when invoked twice" do
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
      blob_partial.scan("blob.video?").length
    ).to eq(1)

    expect(
      blob_partial.scan("video_tag rails_blob_path").length
    ).to eq(1)

    expect(
      blob_partial.scan('class: "b4um-rich-text-video"').length
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

  it "installs and imports the B4UM Trix JavaScript only once" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/views/articles")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/javascript")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "config")
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
      File.join(@destination_root, "app/javascript/application.js"),
      <<~JAVASCRIPT
        import 'trix'
        import '@rails/actiontext'
      JAVASCRIPT
    )

    File.write(
      File.join(@destination_root, "config/importmap.rb"),
      <<~RUBY
        pin "application"
        pin "trix"
        pin "@rails/actiontext", to: "actiontext.esm.js"
      RUBY
    )

    2.times do
      generator = build_generator
      generator.invoke_all
    end

    trix_javascript_path = File.join(
      @destination_root,
      "app/javascript/b4um/trix.js"
    )

    expect(File).to exist(trix_javascript_path)

    application_javascript = File.read(
      File.join(
        @destination_root,
        "app/javascript/application.js"
      )
    )

    expect(
      application_javascript.scan("import 'b4um/trix'").length
    ).to eq(1)

    importmap = File.read(
      File.join(
        @destination_root,
        "config/importmap.rb"
      )
    )

    expect(
      importmap.scan('pin "b4um/trix", to: "b4um/trix.js"').length
    ).to eq(1)
  end

  it "installs the B4UM rich text preview helper" do
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

    helper_path = File.join(
      @destination_root,
      "app/helpers/b4um_rich_text_helper.rb"
    )

    expect(File).to exist(helper_path)

    helper = File.read(helper_path)

    expect(helper).to include(
      "def b4um_rich_text_preview(rich_text, length: 160)"
    )

    expect(helper).to include(
      "rich_text.body.fragment.source"
    )

    expect(helper).to include(
      "first_element = document.element_children.first"
    )

    expect(helper).to include(
      "heading = b4um_preview_heading(first_element)"
    )

    expect(helper).to include(
      "B4UM_RICH_TEXT_CONTAINERS = %w[div section article].freeze"
    )

    expect(helper).to include(
      "def b4um_preview_heading(element)"
    )

    expect(helper).to include(
      'return element if element.name.match?(/\Ah[1-6]\z/)'
    )

    expect(helper).to include(
      "B4UM_RICH_TEXT_CONTAINERS.include?(element.name)"
    )

    expect(helper).to include(
      'class: "b4um-rich-text-preview__heading"'
    )

    expect(helper).to include(
      'class: "b4um-rich-text-preview"'
    )

    expect(helper).to include(
      'class: "b4um-rich-text-preview__text"'
    )
  end

  it "supports headings inside B4UM rich text containers" do
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

    helper = File.read(
      File.join(
        @destination_root,
        "app/helpers/b4um_rich_text_helper.rb"
      )
    )

    expect(helper).to include(
      "B4UM_RICH_TEXT_CONTAINERS = %w[div section article].freeze"
    )

    expect(helper).to include(
      "heading = b4um_preview_heading(first_element)"
    )

    expect(helper).to include(
      "def b4um_preview_heading(element)"
    )

    expect(helper).to include(
      'return element if element.name.match?(/\Ah[1-6]\z/)'
    )

    expect(helper).to include(
      "return unless B4UM_RICH_TEXT_CONTAINERS.include?(element.name)"
    )

    expect(helper).to include(
      "first_child = element.element_children.first"
    )

    expect(helper).to include(
      "b4um_preview_heading(first_child)"
    )
  end

  it "adds B4UM rich text preview styles without duplicating them" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/views/articles")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/assets/stylesheets/b4um")
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

    resources_stylesheet_path = File.join(
      @destination_root,
      "app/assets/stylesheets/b4um/resources.css"
    )

    File.write(
      resources_stylesheet_path,
      <<~CSS
        .resource-value {
          min-width: 0;
        }
      CSS
    )

    2.times do
      generator = build_generator
      generator.invoke_all
    end

    stylesheet = File.read(resources_stylesheet_path)

    expect(
      stylesheet.scan(".b4um-rich-text-preview {").length
    ).to eq(1)

    expect(
      stylesheet.scan(".b4um-rich-text-preview__heading {").length
    ).to eq(1)

    expect(
      stylesheet.scan(".b4um-rich-text-preview__text {").length
    ).to eq(1)
  end

  it "installs B4UM Trix container tools" do
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

    trix_javascript = File.read(
      File.join(
        @destination_root,
        "app/javascript/b4um/trix.js"
      )
    )

    expect(trix_javascript).to include(
      "Trix.config.blockAttributes.b4umDiv"
    )

    expect(trix_javascript).to include(
      "Trix.config.blockAttributes.section"
    )

    expect(trix_javascript).to include(
      "Trix.config.blockAttributes.article"
    )

    expect(trix_javascript).to include(
      'data-trix-attribute="b4umDiv"'
    )

    expect(trix_javascript).to include(
      'data-trix-attribute="section"'
    )

    expect(trix_javascript).to include(
      'data-trix-attribute="article"'
    )
  end

  it "allows style attributes for B4UM Trix colors" do
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

    initializer = File.read(
      File.join(
        @destination_root,
        "config/initializers/action_text.rb"
      )
    )

    expect(initializer).to include("style")
  end

  it "allows id attributes for B4UM Trix containers" do
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

    initializer = File.read(
      File.join(
        @destination_root,
        "config/initializers/action_text.rb"
      )
    )

    expect(initializer).to include("id")
  end

  it "allows section and article tags for B4UM Trix containers" do
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

    initializer = File.read(
      File.join(
        @destination_root,
        "config/initializers/action_text.rb"
      )
    )

    expect(initializer).to include("section")
    expect(initializer).to include("article")
  end
end
