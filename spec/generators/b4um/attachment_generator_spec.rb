# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "generators/b4um/attachment/attachment_generator"

RSpec.describe B4um::Generators::AttachmentGenerator do
  around do |example|
    Dir.mktmpdir("b4um_attachment_test") do |directory|
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

  it "loads the B4UM attachment generator" do
    expect(described_class).to be < Rails::Generators::NamedBase
  end

  it "adds a single attachment to an existing model" do
    create_model(
      "admin",
      <<~RUBY
        class Admin < ApplicationRecord
          has_secure_password
        end
      RUBY
    )

    generator = described_class.new(
      %w[Admin avatar],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    model = File.read(
      File.join(
        @destination_root,
        "app/models/admin.rb"
      )
    )

    expect(model).to include(
      "has_one_attached :avatar"
    )
  end

  it "does not duplicate an existing attachment" do
    create_model(
      "admin",
      <<~RUBY
        class Admin < ApplicationRecord
          has_secure_password
          has_one_attached :avatar
        end
      RUBY
    )

    generator = described_class.new(
      %w[Admin avatar],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    model = File.read(
      File.join(
        @destination_root,
        "app/models/admin.rb"
      )
    )

    expect(
      model.scan("has_one_attached :avatar").count
    ).to eq(1)
  end

  it "raises an error when the model does not exist" do
    generator = described_class.new(
      %w[Admin avatar],
      {},
      destination_root: @destination_root
    )

    expect do
      generator.invoke_all
    end.to raise_error(
      Thor::Error,
      "Model not found: app/models/admin.rb"
    )
  end

  it "adds the attachment to an existing b4um form" do
    create_model(
      "admin",
      <<~RUBY
        class Admin < ApplicationRecord
        end
      RUBY
    )

    form_path = File.join(
      @destination_root,
      "app/views/admins/_form.html.erb"
    )

    FileUtils.mkdir_p(File.dirname(form_path))

    File.write(
      form_path,
      <<~ERB
        <%= form_with(model: admin, class: "form") do |form| %>
          <div class="form-field">
            <%= form.text_field :name,
                  class: "form-input",
                  placeholder: " " %>
            <%= form.label :name, class: "form-label" %>
          </div>

          <div class="form-actions">
            <%= form.submit class: "form-submit" %>
          </div>
        <% end %>
      ERB
    )

    generator = described_class.new(
      %w[Admin avatar],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    form = File.read(form_path)

    expect(form).to include(
      "form.file_field :avatar"
    )

    expect(form).to include(
      'data-controller="image-preview"'
    )

    expect(form).to include(
      "admin.avatar.attached?"
    )

    expect(form).to include(
      "image_tag admin.avatar"
    )
  end

  it "adds the attachment to controller parameters" do
    create_model(
      "admin",
      <<~RUBY
        class Admin < ApplicationRecord
        end
      RUBY
    )

    controller_path = File.join(
      @destination_root,
      "app/controllers/admins_controller.rb"
    )

    FileUtils.mkdir_p(File.dirname(controller_path))

    File.write(
      controller_path,
      <<~RUBY
        class AdminsController < ApplicationController
          private

          def admin_params
            params.expect(admin: [:name, :email])
          end
        end
      RUBY
    )

    generator = described_class.new(
      %w[Admin avatar],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(controller_path)

    expect(controller).to include(
      "params.expect(admin: [ :name, :email, :avatar, :remove_avatar ])"
    )
  end

  it "adds single attachment removal to the form and controller" do
    create_model(
      "admin",
      <<~RUBY
        class Admin < ApplicationRecord
        end
      RUBY
    )

    form_path = File.join(
      @destination_root,
      "app/views/admins/_form.html.erb"
    )

    controller_path = File.join(
      @destination_root,
      "app/controllers/admins_controller.rb"
    )

    FileUtils.mkdir_p(File.dirname(form_path))
    FileUtils.mkdir_p(File.dirname(controller_path))

    File.write(
      form_path,
      <<~ERB
        <%= form_with(model: admin, class: "form") do |form| %>
          <div class="form-actions">
            <%= form.submit class: "form-submit" %>
          </div>
        <% end %>
      ERB
    )

    File.write(
      controller_path,
      <<~RUBY
        class AdminsController < ApplicationController
          def update
            respond_to do |format|
              if @admin.update(admin_params)
                format.html { redirect_to @admin }
              end
            end
          end

          private

          def admin_params
            params.expect(admin: [:name, :email])
          end
        end
      RUBY
    )

    generator = described_class.new(
      %w[Admin avatar],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    form = File.read(form_path)
    controller = File.read(controller_path)

    expect(form).to include(
      '"admin[remove_avatar]"'
    )

    expect(form).to include(
      'data-image-preview-target="existingItem"'
    )

    expect(form).to include(
      'image_preview_target: "removeCheckbox"'
    )

    expect(form).to include(
      "Will be removed"
    )

    expect(controller).to include(
      ":avatar, :remove_avatar"
    )

    expect(controller).to include(
      'remove_avatar = update_params.delete("remove_avatar")'
    )

    expect(controller).to include(
      "@admin.update(update_params)"
    )

    expect(controller).to include(
      '@admin.avatar.purge if remove_avatar == "1"'
    )
  end

  it "adds a single attachment after multiple attachment setup" do
    create_model(
      "product",
      <<~RUBY
        class Product < ApplicationRecord
          has_many_attached :gallery
        end
      RUBY
    )

    controller_path = File.join(
      @destination_root,
      "app/controllers/products_controller.rb"
    )

    FileUtils.mkdir_p(File.dirname(controller_path))

    File.write(
      controller_path,
      <<~RUBY
        class ProductsController < ApplicationController
          def update
            update_params = product_params
            new_gallery = update_params.delete("gallery")
            remove_gallery_ids = update_params.delete("remove_gallery_ids")

            respond_to do |format|
              if @product.update(update_params)
                @product.gallery.attach(new_gallery) if new_gallery.present?

                if remove_gallery_ids.present?
                  @product.gallery.attachments
                    .where(id: remove_gallery_ids)
                    .find_each(&:purge)
                end

                format.html { redirect_to @product }
              end
            end
          end

          private

          def product_params
            params.expect(product: [:name, gallery: [], remove_gallery_ids: []])
          end
        end
      RUBY
    )

    generator = described_class.new(
      %w[Product cover],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(controller_path)

    expect(controller).to include(
      ":cover, :remove_cover"
    )

    expect(controller).to include(
      'remove_cover = update_params.delete("remove_cover")'
    )

    expect(controller).to include(
      '@product.cover.purge if remove_cover == "1"'
    )

    expect(controller).to include(
      'new_gallery = update_params.delete("gallery")'
    )

    expect(controller).to include(
      "@product.gallery.attach(new_gallery)"
    )
    expect do
      RubyVM::InstructionSequence.compile(controller)
    end.not_to raise_error
  end

  it "normalizes existing parameter spacing when adding a single attachment" do
    create_model(
      "product",
      <<~RUBY
        class Product < ApplicationRecord
        end
      RUBY
    )

    controller_path = File.join(
      @destination_root,
      "app/controllers/products_controller.rb"
    )

    FileUtils.mkdir_p(File.dirname(controller_path))

    File.write(
      controller_path,
      <<~RUBY
        class ProductsController < ApplicationController
          def update
            respond_to do |format|
              if @product.update(product_params)
                format.html { redirect_to @product }
              end
            end
          end

          private

          def product_params
            params.expect(product: [ :name, :description , :image, :remove_image])
          end
        end
      RUBY
    )

    generator = described_class.new(
      %w[Product avatar],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(controller_path)

    expect(controller).to include(
      "params.expect(product: [ :name, :description, :image, :remove_image, :avatar, :remove_avatar ])"
    )

    expect(controller).not_to include(
      ":description ,"
    )

    expect(controller).not_to include(
      ":remove_avatar])"
    )
  end

  it "does not duplicate attachment setup when run twice" do
    create_model(
      "admin",
      <<~RUBY
        class Admin < ApplicationRecord
        end
      RUBY
    )

    form_path = File.join(
      @destination_root,
      "app/views/admins/_form.html.erb"
    )

    controller_path = File.join(
      @destination_root,
      "app/controllers/admins_controller.rb"
    )

    resource_path = File.join(
      @destination_root,
      "app/views/admins/_admin.html.erb"
    )

    FileUtils.mkdir_p(File.dirname(form_path))
    FileUtils.mkdir_p(File.dirname(controller_path))
    FileUtils.mkdir_p(File.dirname(resource_path))

    File.write(
      form_path,
      <<~ERB
        <%= form_with(model: admin, class: "form") do |form| %>
          <div class="form-actions">
            <%= form.submit class: "form-submit" %>
          </div>
        <% end %>
      ERB
    )

    File.write(
      controller_path,
      <<~RUBY
        class AdminsController < ApplicationController
          def update
            respond_to do |format|
              if @admin.update(admin_params)
                format.html { redirect_to @admin }
              end
            end
          end

          private

          def admin_params
            params.expect(admin: [:name, :email])
          end
        end
      RUBY
    )

    File.write(
      resource_path,
      <<~ERB
        <div id="<%= dom_id admin %>" class="resource">
          <div class="resource-field">
            <strong class="resource-label">Name:</strong>
            <span class="resource-value"><%= admin.name %></span>
          </div>
        </div>
      ERB
    )

    first_generator = described_class.new(
      %w[Admin avatar],
      {},
      destination_root: @destination_root
    )

    first_generator.invoke_all

    second_generator = described_class.new(
      %w[Admin avatar],
      {},
      destination_root: @destination_root
    )

    second_generator.invoke_all

    model = File.read(
      File.join(
        @destination_root,
        "app/models/admin.rb"
      )
    )

    form = File.read(form_path)
    controller = File.read(controller_path)
    resource = File.read(resource_path)

    expect(
      model.scan("has_one_attached :avatar").count
    ).to eq(1)

    expect(
      form.scan("form.file_field :avatar").count
    ).to eq(1)

    expect(
      controller.scan(":avatar, :remove_avatar").count
    ).to eq(1)

    expect(
      controller.scan(
        'remove_avatar = update_params.delete("remove_avatar")'
      ).count
    ).to eq(1)

    expect(
      controller.scan(
        '@admin.avatar.purge if remove_avatar == "1"'
      ).count
    ).to eq(1)

    expect(
      form.scan('"admin[remove_avatar]"').count
    ).to eq(1)

    expect(
      resource.scan("image_tag admin.avatar").count
    ).to eq(1)
  end

  it "adds the attachment to an existing b4um resource partial" do
    create_model(
      "admin",
      <<~RUBY
        class Admin < ApplicationRecord
        end
      RUBY
    )

    resource_path = File.join(
      @destination_root,
      "app/views/admins/_admin.html.erb"
    )

    FileUtils.mkdir_p(File.dirname(resource_path))

    File.write(
      resource_path,
      <<~ERB
        <div id="<%= dom_id admin %>" class="resource">
          <div class="resource-field">
            <strong class="resource-label">Name:</strong>
            <span class="resource-value"><%= admin.name %></span>
          </div>
        </div>
      ERB
    )

    generator = described_class.new(
      %w[Admin avatar],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    resource = File.read(resource_path)

    expect(resource).to include(
      "<strong class=\"resource-label\">Avatar:</strong>"
    )

    expect(resource).to include(
      'data-controller="image-lightbox"'
    )

    expect(resource).to include(
      'data-image-lightbox-target="thumbnails"'
    )

    expect(resource).to include(
      "admin.avatar.attached?"
    )

    expect(resource).to include(
      "url_for(admin.avatar)"
    )

    expect(resource).to include(
      "image_tag admin.avatar"
    )

    expect(resource).to include(
      "admin.avatar.filename.to_s"
    )

    expect(resource).to include(
      "No image"
    )
  end

  it "adds multiple attachments to an existing model" do
    create_model(
      "gallery",
      <<~RUBY
        class Gallery < ApplicationRecord
        end
      RUBY
    )

    generator = described_class.new(
      %w[Gallery images],
      { multiple: true },
      destination_root: @destination_root
    )

    generator.invoke_all

    model = File.read(
      File.join(
        @destination_root,
        "app/models/gallery.rb"
      )
    )

    expect(model).to include(
      "has_many_attached :images"
    )

    expect(model).not_to include(
      "has_one_attached :images"
    )
  end

  it "adds multiple attachments to controller parameters and update handling" do
    create_model(
      "gallery",
      <<~RUBY
        class Gallery < ApplicationRecord
        end
      RUBY
    )

    controller_path = File.join(
      @destination_root,
      "app/controllers/galleries_controller.rb"
    )

    FileUtils.mkdir_p(File.dirname(controller_path))

    File.write(
      controller_path,
      <<~RUBY
        class GalleriesController < ApplicationController
          def update
            respond_to do |format|
              if @gallery.update(gallery_params)
                format.html { redirect_to @gallery }
              end
            end
          end

          private

          def gallery_params
            params.expect(gallery: [:title])
          end
        end
      RUBY
    )

    generator = described_class.new(
      %w[Gallery images],
      { multiple: true },
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(controller_path)

    expect(controller).to include(
      "params.expect(gallery: [ :title, images: [], remove_images_ids: [] ])"
    )

    expect(controller).to include(
      'new_images = update_params.delete("images")'
    )

    expect(controller).to include(
      'remove_images_ids = update_params.delete("remove_images_ids")'
    )

    expect(controller).to include(
      "@gallery.update(update_params)"
    )

    expect(controller).to include(
      "@gallery.images.attach(new_images) if new_images.present?"
    )

    expect(controller).to include(
      "@gallery.images.attachments"
    )

    expect(controller).to include(
      ".where(id: remove_images_ids)"
    )

    expect(controller).to include(
      ".find_each(&:purge)"
    )
  end

  it "normalizes existing parameter spacing when adding multiple attachments" do
    create_model(
      "product",
      <<~RUBY
        class Product < ApplicationRecord
        end
      RUBY
    )

    controller_path = File.join(
      @destination_root,
      "app/controllers/products_controller.rb"
    )

    FileUtils.mkdir_p(File.dirname(controller_path))

    File.write(
      controller_path,
      <<~RUBY
        class ProductsController < ApplicationController
          def update
            respond_to do |format|
              if @product.update(product_params)
                format.html { redirect_to @product }
              end
            end
          end

          private

          def product_params
            params.expect(product: [ :name, :description, :thumbnail, :remove_thumbnail ])
          end
        end
      RUBY
    )

    generator = described_class.new(
      %w[Product gallery],
      { multiple: true },
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(controller_path)

    expect(controller).to include(
      "params.expect(product: [ :name, :description, :thumbnail, " \
      ":remove_thumbnail, gallery: [], remove_gallery_ids: [] ])"
    )

    expect(controller).not_to include(
      ":remove_thumbnail ,"
    )

    expect(controller).not_to include(
      "remove_gallery_ids: []])"
    )
  end

  it "adds multiple attachments to an existing b4um resource partial" do
    create_model(
      "gallery",
      <<~RUBY
        class Gallery < ApplicationRecord
        end
      RUBY
    )

    resource_path = File.join(
      @destination_root,
      "app/views/galleries/_gallery.html.erb"
    )

    FileUtils.mkdir_p(File.dirname(resource_path))

    File.write(
      resource_path,
      <<~ERB
        <div id="<%= dom_id gallery %>" class="resource">
          <div class="resource-field">
            <strong class="resource-label">Title:</strong>
            <span class="resource-value"><%= gallery.title %></span>
          </div>
        </div>
      ERB
    )

    generator = described_class.new(
      %w[Gallery images],
      { multiple: true },
      destination_root: @destination_root
    )

    generator.invoke_all

    resource = File.read(resource_path)

    expect(resource).to include(
      '<strong class="resource-label">Images:</strong>'
    )

    expect(resource).to include(
      'class="resource-images"'
    )

    expect(resource).to include(
      "gallery.images.each do |image|"
    )

    expect(resource).to include(
      'data-image-lightbox-target="item"'
    )

    expect(resource).to include(
      'data-image-lightbox-target="previousButton"'
    )

    expect(resource).to include(
      'data-image-lightbox-target="nextButton"'
    )

    expect(resource).to include(
      'data-image-lightbox-target="thumbnails"'
    )

    expect(resource).to include(
      "url_for(image)"
    )

    expect(resource).to include(
      "image_tag image"
    )

    expect(resource).to include(
      "image.filename.to_s"
    )

    expect(resource).to include(
      'aria-label="Image gallery"'
    )

    expect(resource).to include(
      "No images"
    )
  end

  it "adds multiple attachments to an existing b4um form" do
    create_model(
      "gallery",
      <<~RUBY
        class Gallery < ApplicationRecord
        end
      RUBY
    )

    form_path = File.join(
      @destination_root,
      "app/views/galleries/_form.html.erb"
    )

    FileUtils.mkdir_p(File.dirname(form_path))

    File.write(
      form_path,
      <<~ERB
        <%= form_with(model: gallery, class: "form") do |form| %>
          <div class="form-field">
            <%= form.text_field :title,
                  class: "form-input",
                  placeholder: " " %>
            <%= form.label :title, class: "form-label" %>
          </div>

          <div class="form-actions">
            <%= form.submit class: "form-submit" %>
          </div>
        <% end %>
      ERB
    )

    generator = described_class.new(
      %w[Gallery images],
      { multiple: true },
      destination_root: @destination_root
    )

    generator.invoke_all

    form = File.read(form_path)

    expect(form).to include(
      "form.file_field :images"
    )

    expect(form).to include(
      "multiple: true"
    )

    expect(form).to include(
      'action: "change->image-preview#previewMultiple"'
    )

    expect(form).to include(
      "gallery.images.each do |image|"
    )

    expect(form).to include(
      "form.hidden_field :images"
    )

    expect(form).to include(
      '"gallery[remove_images_ids][]"'
    )

    expect(form).to include(
      'data-image-preview-target="existingItem"'
    )

    expect(form).to include(
      'image_preview_target: "removeCheckbox"'
    )

    expect(form).to include(
      "Will be removed"
    )
  end

  it "adds a second multiple attachment after an existing multiple attachment" do
    create_model(
      "product",
      <<~RUBY
        class Product < ApplicationRecord
        end
      RUBY
    )

    controller_path = File.join(
      @destination_root,
      "app/controllers/products_controller.rb"
    )

    FileUtils.mkdir_p(File.dirname(controller_path))

    File.write(
      controller_path,
      <<~RUBY
        class ProductsController < ApplicationController
          def update
            respond_to do |format|
              if @product.update(product_params)
                format.html { redirect_to @product }
              end
            end
          end

          private

          def product_params
            params.expect(product: [ :name ])
          end
        end
      RUBY
    )

    gallery_generator = described_class.new(
      %w[Product gallery],
      { multiple: true },
      destination_root: @destination_root
    )

    gallery_generator.invoke_all

    photos_generator = described_class.new(
      %w[Product photos],
      { multiple: true },
      destination_root: @destination_root
    )

    photos_generator.invoke_all

    controller = File.read(controller_path)

    expect(controller).to include(
      "params.expect(product: [ :name, gallery: [], remove_gallery_ids: [], photos: [], remove_photos_ids: [] ])"
    )

    expect(controller).to include(
      'new_gallery = update_params.delete("gallery")'
    )

    expect(controller).to include(
      'new_photos = update_params.delete("photos")'
    )

    expect(controller).to include(
      "@product.gallery.attach(new_gallery) if new_gallery.present?"
    )

    expect(controller).to include(
      "@product.photos.attach(new_photos) if new_photos.present?"
    )

    expect(controller.scan("gallery: []").length).to eq(1)
    expect(controller.scan("remove_gallery_ids: []").length).to eq(1)
    expect(controller.scan("photos: []").length).to eq(1)
    expect(controller.scan("remove_photos_ids: []").length).to eq(1)
  end

  it "does not duplicate multiple attachment setup when run twice" do
    create_model(
      "gallery",
      <<~RUBY
        class Gallery < ApplicationRecord
        end
      RUBY
    )

    controller_path = File.join(
      @destination_root,
      "app/controllers/galleries_controller.rb"
    )

    form_path = File.join(
      @destination_root,
      "app/views/galleries/_form.html.erb"
    )

    resource_path = File.join(
      @destination_root,
      "app/views/galleries/_gallery.html.erb"
    )

    FileUtils.mkdir_p(File.dirname(controller_path))
    FileUtils.mkdir_p(File.dirname(form_path))

    File.write(
      controller_path,
      <<~RUBY
        class GalleriesController < ApplicationController
          def update
            respond_to do |format|
              if @gallery.update(gallery_params)
                format.html { redirect_to @gallery }
              end
            end
          end

          private

          def gallery_params
            params.expect(gallery: [:title])
          end
        end
      RUBY
    )

    File.write(
      form_path,
      <<~ERB
        <%= form_with(model: gallery, class: "form") do |form| %>
          <div class="form-actions">
            <%= form.submit class: "form-submit" %>
          </div>
        <% end %>
      ERB
    )

    File.write(
      resource_path,
      <<~ERB
        <div id="<%= dom_id gallery %>" class="resource">
        </div>
      ERB
    )

    2.times do
      generator = described_class.new(
        %w[Gallery images],
        { multiple: true },
        destination_root: @destination_root
      )

      generator.invoke_all
    end

    model = File.read(
      File.join(
        @destination_root,
        "app/models/gallery.rb"
      )
    )

    controller = File.read(controller_path)
    form = File.read(form_path)
    resource = File.read(resource_path)

    expect(
      model.scan("has_many_attached :images").length
    ).to eq(1)

    expect(
      form.scan("form.file_field :images").length
    ).to eq(1)

    expect(
      controller.scan("images: [], remove_images_ids: []").length
    ).to eq(1)

    expect(
      controller.scan(
        'new_images = update_params.delete("images")'
      ).length
    ).to eq(1)

    expect(
      controller.scan(
        "@gallery.images.attach(new_images)"
      ).length
    ).to eq(1)

    expect(
      resource.scan(
        '<strong class="resource-label">Images:</strong>'
      ).length
    ).to eq(1)
  end
end
