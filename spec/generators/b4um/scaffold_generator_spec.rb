# frozen_string_literal: true

require "spec_helper"
require "active_support/core_ext/string/filters"
require "tmpdir"
require "fileutils"
require "generators/b4um/scaffold/scaffold_generator"

RSpec.describe B4um::Generators::ScaffoldGenerator do
  around do |example|
    Dir.mktmpdir("b4um_generator_test") do |directory|
      @destination_root = directory

      FileUtils.mkdir_p(
        File.join(directory, "config")
      )

      File.write(
        File.join(directory, "config/routes.rb"),
        "Rails.application.routes.draw do\nend\n"
      )

      example.run
    end
  end

  it "loads the B4UM scaffold generator" do
    expect(described_class).to be < Rails::Generators::ScaffoldGenerator
  end

  it "generates the B4UM scaffold views" do
    generator = described_class.new(
      [
        "Post",
        ["title:string", "body:text", "published:boolean"]
      ],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    expect(
      File.exist?(
        File.join(
          @destination_root,
          "app/views/posts/_form.html.erb"
        )
      )
    ).to be(true)

    expect(
      File.exist?(
        File.join(
          @destination_root,
          "app/views/posts/_post.html.erb"
        )
      )
    ).to be(true)

    expect(
      File.exist?(
        File.join(
          @destination_root,
          "app/views/posts/index.html.erb"
        )
      )
    ).to be(true)

    form = File.read(
      File.join(
        @destination_root,
        "app/views/posts/_form.html.erb"
      )
    )

    expect(form).to include('class: "form"')
    expect(form).to include('class: "form-input"')
    expect(form).to include('class: "form-textarea"')
    expect(form).to include('class: "form-checkbox"')
    expect(form).to include('class: "form-submit"')

    resource = File.read(
      File.join(
        @destination_root,
        "app/views/posts/_post.html.erb"
      )
    )

    expect(resource).to include(
      'post.published ? "Yes" : "No"'
    )

    expect(resource).to include(
      "local_assigns[:compact]"
    )

    expect(resource).to include(
      "length: local_assigns.fetch(:preview_length, 160)"
    )
  end

  it "generates password fields for password_digest" do
    generator = described_class.new(
      [
        "Member",
        ["email:string", "password_digest:string"]
      ],
      {},
      destination_root: @destination_root
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    File.write(
      File.join(
        @destination_root,
        "app/models/member.rb"
      ),
      "class Member < ApplicationRecord\nend\n"
    )

    File.write(
      File.join(@destination_root, "Gemfile"),
      "source \"https://rubygems.org\"\n"
    )

    generator.invoke_all

    form = File.read(
      File.join(
        @destination_root,
        "app/views/members/_form.html.erb"
      )
    )

    expect(form).to include(
      "form.password_field :password"
    )

    expect(form).to include(
      "form.password_field :password_confirmation"
    )

    expect(form).not_to include(
      "form.text_field :password_digest"
    )

    resource = File.read(
      File.join(
        @destination_root,
        "app/views/members/_member.html.erb"
      )
    )

    expect(resource).to include("member.email")
    expect(resource).not_to include("member.password_digest")

    model = File.read(
      File.join(
        @destination_root,
        "app/models/member.rb"
      )
    )

    controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/members_controller.rb"
      )
    )

    gemfile = File.read(
      File.join(@destination_root, "Gemfile")
    )

    expect(model).to include("has_secure_password")

    expect(controller).to include(
      ":password, :password_confirmation"
    )

    expect(controller).not_to include(
      ":password_digest"
    )

    expect(gemfile).to include('gem "bcrypt"')
  end

  it "generates specialized form fields" do
    generator = described_class.new(
      [
        "Contact",
        [
          "email:string",
          "phone:string",
          "website:string",
          "birthday:date",
          "appointment_at:datetime",
          "alarm_at:time",
          "age:integer",
          "price:decimal"
        ]
      ],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    form = File.read(
      File.join(
        @destination_root,
        "app/views/contacts/_form.html.erb"
      )
    )

    resource = File.read(
      File.join(
        @destination_root,
        "app/views/contacts/_contact.html.erb"
      )
    )

    expect(form).to include("form.email_field :email")
    expect(form).to include("form.telephone_field :phone")
    expect(form).to include("form.url_field :website")
    expect(form).to include("form.date_field :birthday")

    expect(form).to include(
      "form.datetime_local_field :appointment_at"
    )

    expect(form).to include("form.time_field :alarm_at")

    expect(form).to match(
      /form\.number_field :age,.*?step: 1/m
    )

    expect(form).to match(
      /form\.number_field :price,.*?step: "any"/m
    )

    expect(resource).to include(
      "number_with_precision("
    )

    expect(resource).to include(
      "contact.price"
    )

    expect(resource).to include(
      "precision: 2"
    )

    expect(resource).to include(
      'delimiter: "."'
    )

    expect(resource).to include(
      'separator: ","'
    )
  end

  it "generates B4UM page actions and card layouts" do
    generator = described_class.new(
      [
        "Article",
        ["title:string", "body:text"]
      ],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    index = File.read(
      File.join(
        @destination_root,
        "app/views/articles/index.html.erb"
      )
    )
    bento = File.read(
      File.join(
        @destination_root,
        "app/views/articles/_bento.html.erb"
      )
    )

    show = File.read(
      File.join(
        @destination_root,
        "app/views/articles/show.html.erb"
      )
    )

    new_view = File.read(
      File.join(
        @destination_root,
        "app/views/articles/new.html.erb"
      )
    )

    edit = File.read(
      File.join(
        @destination_root,
        "app/views/articles/edit.html.erb"
      )
    )

    expect(index).to include(
      'render "bento",'
    )

    expect(index).to include(
      "articles: @articles"
    )

    expect(bento).to include(
      'class="b4um-grid"'
    )

    expect(index).to include(
      "@articles.any?"
    )

    expect(index).to include(
      'class="b4um-empty-state"'
    )

    expect(index).to include(
      'class="b4um-empty-state__title"'
    )

    expect(index).to include(
      'class="b4um-empty-state__text"'
    )

    expect(index).to include(
      "No articles yet."
    )

    expect(index).to include(
      "Create your first article to get started."
    )

    expect(bento).to include(
      "articles.each_with_index"
    )

    expect(bento).to include(
      '"b4um-card b4um-card--wide"'
    )

    expect(bento).to include(
      '"b4um-card b4um-card--soft"'
    )

    expect(bento).to include(
      '"b4um-card b4um-card--large"'
    )

    expect(bento).to include(
      "card_class, preview_length"
    )

    expect(bento).to include(
      '["b4um-card b4um-card--wide", 240]'
    )

    expect(bento).to include(
      '["b4um-card b4um-card--soft", 160]'
    )

    expect(bento).to include(
      '["b4um-card b4um-card--large", 480]'
    )

    expect(bento).to include(
      '["b4um-card", 160]'
    )

    expect(bento).to include(
      "preview_length: preview_length"
    )

    expect(bento).to include(
      'class: "button button--secondary"'
    )

    expect(index).to include(
      'class: "button button--primary"'
    )

    expect(show).to include(
      'class="b4um-card b4um-card--full"'
    )

    expect(show).to include(
      'class: "button button--secondary"'
    )

    expect(show).to include(
      'class: "button button--danger"'
    )

    expect(show).to include(
      'turbo_confirm: "Are you sure?"'
    )

    expect(new_view).to include(
      'class="b4um-card b4um-card--full"'
    )

    expect(new_view).to include(
      'class: "button button--secondary"'
    )

    expect(edit).to include(
      'class="b4um-card b4um-card--full"'
    )

    expect(edit).to include(
      'class: "button button--secondary"'
    )
  end

  it "generates a table index layout" do
    generator = described_class.new(
      [
        "Product",
        ["name:string", "description:text", "price:decimal", "status:string"]
      ],
      {
        layout: "table"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    index = File.read(
      File.join(
        @destination_root,
        "app/views/products/index.html.erb"
      )
    )

    table = File.read(
      File.join(
        @destination_root,
        "app/views/products/_table.html.erb"
      )
    )

    expect(index).to include(
      'render "table",'
    )

    expect(index).to include(
      "products: @products"
    )

    expect(index).to include(
      'class="b4um-empty-state"'
    )

    expect(table).to include(
      'class="b4um-table-wrapper"'
    )

    expect(table).to include(
      'class="b4um-table"'
    )

    expect(table).to include("<th>Name</th>")
    expect(table).to include("<th>Description</th>")
    expect(table).to include("<th>Price</th>")
    expect(table).to include("<th>Status</th>")
    expect(table).to include("<th>Actions</th>")

    expect(table).to include(
      "products.each do |product|"
    )

    expect(table).to include("product.name")

    expect(table).to include(
      "truncate(product.description, length: 100)"
    )

    expect(table).to include(
      "number_with_precision("
    )

    expect(table).to include(
      "product.price"
    )

    expect(table).to include(
      "precision: 2"
    )

    expect(table).to include(
      'delimiter: "."'
    )

    expect(table).to include(
      'separator: ","'
    )

    expect(table).to include(
      'class="b4um-badge"'
    )

    expect(table).to include("product.status")

    expect(table).to include(
      'class="b4um-table__actions"'
    )

    expect(table).to include(
      'class: "button button--secondary"'
    )

    expect(index).not_to include(
      'class="b4um-table"'
    )

    expect(table).not_to include(
      'class="b4um-grid"'
    )
  end

  it "generates a badge for a status attribute" do
    generator = described_class.new(
      [
        "Article",
        ["title:string", "status:string"]
      ],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    resource = File.read(
      File.join(
        @destination_root,
        "app/views/articles/_article.html.erb"
      )
    )

    expect(resource).to include(
      'class="b4um-badge"'
    )

    expect(resource).to include(
      "article.status"
    )
  end

  it "uses a separate flash type after destroying a resource" do
    generator = described_class.new(
      [
        "Article",
        ["title:string"]
      ],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    controller = File.read(
      File.join(
        @destination_root,
        "app/controllers/articles_controller.rb"
      )
    )

    expect(controller).to include(
      'flash[:deleted] = "Article was successfully destroyed."'
    )

    expect(controller).to include(
      "redirect_to articles_path, status: :see_other"
    )

    expect(controller).not_to include(
      'notice: "Article was successfully destroyed."'
    )

    expect(controller).to include(
      'notice: "Article was successfully created."'
    )

    expect(controller).to include(
      'notice: "Article was successfully updated."'
    )
  end

  it "generates a readable URL parameter" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    File.write(
      File.join(
        @destination_root,
        "app/models/article.rb"
      ),
      <<~RUBY
        class Article < ApplicationRecord
        end
      RUBY
    )

    generator = described_class.new(
      [
        "Article",
        ["title:string", "body:text"]
      ],
      {
        param: "title"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    model = File.read(
      File.join(
        @destination_root,
        "app/models/article.rb"
      )
    )

    expect(model).to include(
      "def to_param"
    )

    expect(model).to include(
      "\"\#{id} \#{title}\".parameterize"
    )
  end

  it "ignores a readable URL parameter that does not exist" do
    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    File.write(
      File.join(
        @destination_root,
        "app/models/article.rb"
      ),
      <<~RUBY
        class Article < ApplicationRecord
        end
      RUBY
    )

    generator = described_class.new(
      [
        "Article",
        ["title:string"]
      ],
      {
        param: "slug"
      },
      destination_root: @destination_root
    )

    generator.invoke_all

    model = File.read(
      File.join(
        @destination_root,
        "app/models/article.rb"
      )
    )

    expect(model).not_to include(
      "def to_param"
    )
  end

  it "adds the generated resource to the B4UM navigation" do
    navigation_directory = File.join(
      @destination_root,
      "app/views/shared"
    )

    FileUtils.mkdir_p(navigation_directory)

    navigation_path = File.join(
      navigation_directory,
      "_navigation.html.erb"
    )

    File.write(
      navigation_path,
      <<~ERB
        <div
          class="navigation__menu"
          id="navigation-menu"
          data-navigation-target="menu"
        >
          <%# B4UM_NAVIGATION_LINKS %>
        </div>
      ERB
    )

    generator = described_class.new(
      ["Product", "name:string"],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    # Ein zweiter Aufruf darf den Menüpunkt nicht duplizieren.
    generator.add_navigation_link

    navigation = File.read(navigation_path)

    expect(navigation).to include(
      'navigation_link_to "Products"'
    )

    expect(navigation).to include(
      "products_path"
    )

    expect(navigation).to include(
      "controller: :products"
    )

    expect(
      navigation.scan("controller: :products").count
    ).to eq(1)
  end

  it "provides all B4UM scaffold templates" do
    template_directory = File.expand_path(
      "../../../lib/generators/b4um/scaffold/templates",
      __dir__
    )

    expected_templates = %w[
      _form.html.erb.tt
      _resource.html.erb.tt
      _bento.html.erb.tt
      _table.html.erb.tt
      index.html.erb.tt
      show.html.erb.tt
      new.html.erb.tt
      edit.html.erb.tt
    ]

    expected_templates.each do |template|
      expect(File).to exist(
        File.join(template_directory, template)
      )
    end
  end
end
