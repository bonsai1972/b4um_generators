# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"
require "generators/b4um/todo/todo_generator"

RSpec.describe B4um::Generators::TodoGenerator do
  before do
    @destination_root = Dir.mktmpdir

    FileUtils.mkdir_p(
      File.join(@destination_root, "app/models")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "db/migrate")
    )

    FileUtils.mkdir_p(
      File.join(@destination_root, "config")
    )

    File.write(
      File.join(@destination_root, "config/routes.rb"),
      <<~RUBY
        Rails.application.routes.draw do
        end
      RUBY
    )

    File.write(
      File.join(@destination_root, "app/models/user.rb"),
      <<~RUBY
        class User < ApplicationRecord
        end
      RUBY
    )

    File.write(
      File.join(@destination_root, "app/models/member.rb"),
      <<~RUBY
        class Member < ApplicationRecord
        end
      RUBY
    )
  end

  after do
    FileUtils.remove_entry(@destination_root)
  end

  def run_generator(owner: nil)
    options = {}
    options[:owner] = owner if owner

    generator = described_class.new(
      ["Task"],
      options,
      destination_root: @destination_root
    )

    generator.invoke_all
  end

  def task_model_path
    File.join(
      @destination_root,
      "app/models/task.rb"
    )
  end

  def migrations
    Dir.glob(
      File.join(
        @destination_root,
        "db/migrate/*_create_tasks.rb"
      )
    )
  end

  it "loads the B4UM todo generator" do
    expect(described_class).to be < Rails::Generators::NamedBase
  end

  context "without an owner" do
    before do
      run_generator
    end

    it "creates a task model without an owner association" do
      expect(File).to exist(task_model_path)

      content = File.read(task_model_path)

      expect(content).to include(
        "class Task < ApplicationRecord"
      )

      expect(content).to include(
        "validates :name, presence: true"
      )

      expect(content).not_to include("belongs_to")
    end

    it "creates a migration without an owner reference" do
      expect(migrations.size).to eq(1)

      content = File.read(migrations.first)

      expect(content).to include(
        "create_table :tasks"
      )

      expect(content).to include(
        "t.string :name, null: false"
      )

      expect(content).to include(
        "t.boolean :complete, default: false, null: false"
      )

      expect(content).not_to include("t.references")
    end
  end

  context "with User as owner" do
    before do
      run_generator(owner: "User")
    end

    it "creates the task association" do
      content = File.read(task_model_path)

      expect(content).to include(
        "belongs_to :user"
      )
    end

    it "creates the owner reference in the migration" do
      expect(migrations.size).to eq(1)

      content = File.read(migrations.first)

      expect(content).to include(
        "t.references :user, null: false, foreign_key: true"
      )
    end

    it "adds the tasks association to User" do
      user_path = File.join(
        @destination_root,
        "app/models/user.rb"
      )

      content = File.read(user_path)

      expect(content).to include(
        "has_many :tasks, dependent: :destroy"
      )
    end
  end

  context "with Member as owner" do
    before do
      run_generator(owner: "Member")
    end

    it "uses the specified owner model" do
      content = File.read(task_model_path)

      expect(content).to include(
        "belongs_to :member"
      )

      member_path = File.join(
        @destination_root,
        "app/models/member.rb"
      )

      expect(File.read(member_path)).to include(
        "has_many :tasks, dependent: :destroy"
      )
    end
  end

  context "when executed repeatedly" do
    it "does not create duplicate migrations" do
      run_generator
      run_generator

      expect(migrations.size).to eq(1)
    end

    it "does not duplicate the owner association" do
      run_generator(owner: "User")
      run_generator(owner: "User")

      user_path = File.join(
        @destination_root,
        "app/models/user.rb"
      )

      content = File.read(user_path)

      expect(
        content.scan("has_many :tasks").size
      ).to eq(1)
    end
  end

  context "with an invalid owner" do
    it "rejects invalid model names" do
      expect do
        run_generator(owner: "invalid-name")
      end.to raise_error(
        Thor::Error,
        /Invalid owner model/
      )
    end
  end

  context "controller generation" do
    def controller_content
      path = File.join(
        @destination_root,
        "app/controllers/tasks_controller.rb"
      )

      expect(File).to exist(path)

      File.read(path)
    end

    it "creates a controller for shared tasks" do
      run_generator

      content = controller_content

      expect(content).to include(
        "class TasksController < ApplicationController"
      )

      expect(content).to include("Task.all")
      expect(content).not_to include("current_user")
      expect(content).not_to include("require_todo_owner")
    end

    it "uses current_user for User-owned tasks" do
      run_generator(owner: "User")

      content = controller_content

      expect(content).to include("current_user.tasks")
      expect(content).to include("require_todo_owner")
    end

    it "uses current_member for Member-owned tasks" do
      run_generator(owner: "Member")

      content = controller_content

      expect(content).to include("current_member.tasks")
    end

    it "supports arbitrary owner models" do
      customer_path = File.join(
        @destination_root,
        "app/models/customer.rb"
      )

      File.write(
        customer_path,
        "class Customer < ApplicationRecord\nend\n"
      )

      run_generator(owner: "Customer")

      content = controller_content

      expect(content).to include("current_customer.tasks")
      expect(content).to include(
        "tasks_scope.find(params[:id])"
      )
    end

    it "does not overwrite an existing controller" do
      run_generator

      controller_path = File.join(
        @destination_root,
        "app/controllers/tasks_controller.rb"
      )

      File.write(controller_path, "# Custom controller\n")

      run_generator

      expect(File.read(controller_path)).to eq(
        "# Custom controller\n"
      )
    end

    it "generates Turbo Stream actions for creating tasks" do
      run_generator

      controller_path = File.join(
        @destination_root,
        "app/controllers/tasks_controller.rb"
      )

      expect(File).to exist(controller_path)

      content = File.read(controller_path)

      expect(content).to include("format.turbo_stream")
      expect(content).to include("turbo_stream.prepend")
      expect(content).to include('"incomplete_tasks"')
      expect(content).to include("turbo_stream.replace")
      expect(content).to include('"todo_progress"')
      expect(content).to include("turbo_stream.update")
      expect(content).to include('"incomplete_tasks_count"')
      expect(content).to include('"incomplete_tasks_empty"')
    end

    it "generates Turbo Stream actions for completing and reopening tasks" do
      run_generator

      controller_path = File.join(
        @destination_root,
        "app/controllers/tasks_controller.rb"
      )

      expect(File).to exist(controller_path)

      content = File.read(controller_path)

      expect(content).to include("def update")
      expect(content).to include("format.turbo_stream")

      expect(content).to include("turbo_stream.remove")
      expect(content).to include("helpers.dom_id(@task)")

      expect(content).to include(
        '@task.complete? ? "complete_tasks" : "incomplete_tasks"'
      )

      expect(content).to include('"todo_progress"')
      expect(content).to include('"incomplete_tasks_count"')
      expect(content).to include('"complete_tasks_count"')
      expect(content).to include('"incomplete_tasks_empty"')
      expect(content).to include('"complete_tasks_empty"')
    end

    it "generates Turbo Stream actions for deleting tasks" do
      run_generator

      controller_path = File.join(
        @destination_root,
        "app/controllers/tasks_controller.rb"
      )

      expect(File).to exist(controller_path)

      content = File.read(controller_path)

      destroy_action = content.split("def destroy", 2).last
                              .split("\n  private", 2).first

      expect(destroy_action).to include("@task.destroy!")
      expect(destroy_action).to include("format.turbo_stream")

      expect(destroy_action).to include("turbo_stream.remove")
      expect(destroy_action).to include("helpers.dom_id(@task)")

      expect(destroy_action).to include("turbo_stream.replace")
      expect(destroy_action).to include('"todo_progress"')

      expect(destroy_action).to include('"incomplete_tasks_count"')
      expect(destroy_action).to include('"complete_tasks_count"')

      expect(destroy_action).to include('"incomplete_tasks_empty"')
      expect(destroy_action).to include('"complete_tasks_empty"')

      expect(destroy_action).to include("format.html")
    end

    it "renders the HTML form when task creation fails" do
      run_generator

      controller_path = File.join(
        @destination_root,
        "app/controllers/tasks_controller.rb"
      )

      expect(File).to exist(controller_path)

      content = File.read(controller_path)

      create_action = content.split("def create", 2).last
                             .split("\n  def update", 2).first

      expect(create_action).to include("format.turbo_stream")

      expect(create_action).to match(
        /render :index,\s*formats: :html,\s*status: :unprocessable_entity/
      )
    end

    it "generates a syntactically valid controller" do
      run_generator

      controller_path = File.join(
        @destination_root,
        "app/controllers/tasks_controller.rb"
      )

      expect(File).to exist(controller_path)

      require "ripper"

      content = File.read(controller_path)

      expect(Ripper.sexp(content)).not_to be_nil
    end
  end

  context "route generation" do
    def routes_content
      File.read(
        File.join(@destination_root, "config/routes.rb")
      )
    end

    it "adds the task routes" do
      run_generator

      expect(routes_content).to include(
        "resources :tasks, only: %i[index create update destroy]"
      )
    end

    it "does not duplicate routes when executed repeatedly" do
      run_generator
      run_generator

      expect(
        routes_content.scan(/resources :tasks\b/).size
      ).to eq(1)
    end

    it "uses the same routes for owner-specific tasks" do
      run_generator(owner: "User")

      expect(routes_content).to include(
        "resources :tasks, only: %i[index create update destroy]"
      )
    end
  end

  context "view generation" do
    def view_content(filename)
      path = File.join(
        @destination_root,
        "app/views/tasks",
        filename
      )

      expect(File).to exist(path)

      File.read(path)
    end

    it "creates the index view" do
      run_generator

      content = view_content("index.html.erb")

      expect(content).to include("b4um-todo")
      expect(content).to include('<%= render "progress" %>')
    end

    it "creates the task partial" do
      run_generator

      content = view_content("_task.html.erb")

      expect(content).to include("<%= dom_id(task) %>")
      expect(content).to include("task_path(task)")
      expect(content).to include("method: :patch")
      expect(content).to include("method: :delete")
    end

    it "does not overwrite existing views" do
      run_generator

      view_path = File.join(
        @destination_root,
        "app/views/tasks/index.html.erb"
      )

      File.write(view_path, "<h1>Custom View</h1>")

      run_generator

      expect(File.read(view_path)).to eq(
        "<h1>Custom View</h1>"
      )
    end

    it "connects the todo form to Stimulus" do
      run_generator

      index_path = File.join(
        @destination_root,
        "app/views/tasks/index.html.erb"
      )

      content = File.read(index_path)

      expect(content).to include(
        'controller: "b4um-todo"'
      )

      expect(content).to include(
        'b4um_todo_target: "input"'
      )

      expect(content).to include(
        'b4um_todo_target: "submit"'
      )

      expect(content).to include(
        "input->b4um-todo#updateSubmitState"
      )
    end

    it "creates the progress partial" do
      run_generator

      progress_path = File.join(
        @destination_root,
        "app/views/tasks/_progress.html.erb"
      )

      expect(File).to exist(progress_path)

      content = File.read(progress_path)

      expect(content).to include('id="todo_progress"')
      expect(content).to include("<%= @completed_tasks %>")
      expect(content).to include("<%= @total_tasks %>")
      expect(content).to include("b4um-todo__progress-bar")
      expect(content).to include("b4um-todo__progress-fill")
    end

    it "uses the b4um floating label for the task input" do
      run_generator

      view_path = File.join(
        @destination_root,
        "app/views/tasks/index.html.erb"
      )

      expect(File).to exist(view_path)

      content = File.read(view_path)

      expect(content).to include("form-field")
      expect(content).to include("form-input")
      expect(content).to include("form-label")
      expect(content).to include("form.label :name")
      expect(content).to include("Was möchtest du erledigen?")
    end
  end

  context "stylesheet generation" do
    def stylesheet_path
      File.join(
        @destination_root,
        "app/assets/stylesheets/b4um_todo.css"
      )
    end

    it "creates the todo stylesheet" do
      run_generator

      expect(File).to exist(stylesheet_path)

      content = File.read(stylesheet_path)

      expect(content).to include(".b4um-todo")
      expect(content).to include(".b4um-todo__item")
      expect(content).to include("var(--todo-primary)")
    end

    it "does not overwrite an existing stylesheet" do
      run_generator

      File.write(
        stylesheet_path,
        "/* Custom Todo CSS */\n"
      )

      run_generator

      expect(File.read(stylesheet_path)).to eq(
        "/* Custom Todo CSS */\n"
      )
    end
  end

  context "Stimulus controller generation" do
    def stimulus_controller_path
      File.join(
        @destination_root,
        "app/javascript/controllers/b4um_todo_controller.js"
      )
    end

    it "creates the Stimulus controller" do
      run_generator

      expect(File).to exist(stimulus_controller_path)

      content = File.read(stimulus_controller_path)

      expect(content).to include(
        "import { Controller } from '@hotwired/stimulus'"
      )

      expect(content).to include(
        "static targets = ['input', 'submit']"
      )

      expect(content).to include("updateSubmitState()")
    end

    it "does not overwrite an existing Stimulus controller" do
      run_generator

      File.write(
        stimulus_controller_path,
        "// Custom Stimulus controller\n"
      )

      run_generator

      expect(File.read(stimulus_controller_path)).to eq(
        "// Custom Stimulus controller\n"
      )
    end

    it "creates the same Stimulus controller with an owner" do
      run_generator(owner: "User")

      expect(File).to exist(stimulus_controller_path)
    end

    it "resets the input after a successful Turbo Stream response" do
      run_generator

      controller_path = File.join(
        @destination_root,
        "app/javascript/controllers/b4um_todo_controller.js"
      )

      expect(File).to exist(controller_path)

      content = File.read(controller_path)

      expect(content).to include("resetAfterSuccess(event)")
      expect(content).to include("event.detail.success")
      expect(content).to include("contentType.includes('turbo-stream')")
      expect(content).to include("this.reset()")
    end
  end
end
