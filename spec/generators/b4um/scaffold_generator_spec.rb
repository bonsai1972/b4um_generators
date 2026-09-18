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
      FileUtils.mkdir_p(File.join(directory, "config"))
      File.write(File.join(directory, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")
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
      File.exist?(File.join(@destination_root, "app/views/posts/_form.html.erb"))
    ).to be(true)

    expect(
      File.exist?(File.join(@destination_root, "app/views/posts/_post.html.erb"))
    ).to be(true)

    expect(
      File.exist?(File.join(@destination_root, "app/views/posts/index.html.erb"))
    ).to be(true)

    form = File.read(
      File.join(@destination_root, "app/views/posts/_form.html.erb")
    )

    expect(form).to include('class: "form"')
    expect(form).to include('class: "form-input"')
    expect(form).to include('class: "form-textarea"')
    expect(form).to include('class: "form-checkbox"')
    expect(form).to include('class: "form-submit"')

    resource = File.read(
      File.join(@destination_root, "app/views/posts/_post.html.erb")
    )

    expect(resource).to include('post.published ? "Yes" : "No"')
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
      File.join(@destination_root, "app/models/member.rb"),
      "class Member < ApplicationRecord\nend\n"
    )

    File.write(
      File.join(@destination_root, "Gemfile"),
      "source \"https://rubygems.org\"\n"
    )

    generator.invoke_all

    form = File.read(
      File.join(@destination_root, "app/views/members/_form.html.erb")
    )

    expect(form).to include("form.password_field :password")
    expect(form).to include("form.password_field :password_confirmation")
    expect(form).not_to include("form.text_field :password_digest")
    resource = File.read(
      File.join(@destination_root, "app/views/members/_member.html.erb")
    )

    expect(resource).to include("member.email")
    expect(resource).not_to include("member.password_digest")
    model = File.read(
      File.join(@destination_root, "app/models/member.rb")
    )

    controller = File.read(
      File.join(@destination_root, "app/controllers/members_controller.rb")
    )

    gemfile = File.read(
      File.join(@destination_root, "Gemfile")
    )

    expect(model).to include("has_secure_password")

    expect(controller).to include(":password, :password_confirmation")
    expect(controller).not_to include(":password_digest")

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
      File.join(@destination_root, "app/views/contacts/_form.html.erb")
    )

    expect(form).to include("form.email_field :email")
    expect(form).to include("form.telephone_field :phone")
    expect(form).to include("form.url_field :website")
    expect(form).to include("form.date_field :birthday")
    expect(form).to include("form.datetime_local_field :appointment_at")
    expect(form).to include("form.time_field :alarm_at")
    expect(form).to include("form.number_field :age")
    expect(form).to include("form.number_field :price")
  end

  it "generates B4UM page actions" do
    generator = described_class.new(
      [
        "Article",
        ["title:string"]
      ],
      {},
      destination_root: @destination_root
    )

    generator.invoke_all

    index = File.read(
      File.join(@destination_root, "app/views/articles/index.html.erb")
    )

    show = File.read(
      File.join(@destination_root, "app/views/articles/show.html.erb")
    )

    new_view = File.read(
      File.join(@destination_root, "app/views/articles/new.html.erb")
    )

    edit = File.read(
      File.join(@destination_root, "app/views/articles/edit.html.erb")
    )

    expect(index).to include('class: "button button--primary"')
    expect(index).to include('class: "button button--secondary"')

    expect(show).to include('class: "button button--secondary"')
    expect(show).to include('class: "button button--danger"')
    expect(show).to include('turbo_confirm: "Are you sure?"')

    expect(new_view).to include('class: "button button--secondary"')

    expect(edit).to include('class: "button button--secondary"')
  end

  it "provides all B4UM scaffold templates" do
    template_directory = File.expand_path(
      "../../../lib/generators/b4um/scaffold/templates",
      __dir__
    )

    expected_templates = %w[
      _form.html.erb.tt
      _resource.html.erb.tt
      index.html.erb.tt
      show.html.erb.tt
      new.html.erb.tt
      edit.html.erb.tt
    ]

    expected_templates.each do |template|
      expect(File).to exist(File.join(template_directory, template))
    end
  end
end
