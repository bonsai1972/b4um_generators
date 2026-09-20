# frozen_string_literal: true

require "rails/generators"

module B4um
  module Generators
    class HelpGenerator < Rails::Generators::Base
      desc "Shows an overview of the available B4UM generators and features"

      def show_help
        say <<~TEXT

          B4UM Generators
          ===============

          INSTALLATION

            bin/rails generate b4um:install

          Installs the B4UM base setup:

            - B4UM component stylesheets
            - Navigation
            - Navigation Stimulus controller
            - Image preview Stimulus controller
            - Image lightbox Stimulus controller
            - Helper methods
            - Layout integration
            - Bento / card components

          During installation, optional features can be selected:

            - bcrypt for password support
            - Active Storage for image attachments
            - Hero section
            - Footer

          If an optional Gem is selected and is not already installed,
          B4UM adds it to the Gemfile and runs bundle install.

          If Active Storage is selected and is not already installed,
          B4UM installs Active Storage and runs the database migration.


          HERO

          The installer can add an optional hero section.

          Select the hero when running:

            bin/rails generate b4um:install

          The hero partial is created at:

            app/views/shared/_hero.html.erb

          The generated hero works without an image by default.

          The template contains examples for:

            - Hero title and text
            - Optional action link
            - Optional hero image

          Hero CSS classes use the b4um-hero prefix.


          BENTO / CARDS

          B4UM includes a responsive Bento-style card system.

          Basic example:

            <div class="b4um-grid">
              <article class="b4um-card">
                ...
              </article>
            </div>

          Available card variants:

            b4um-card
            b4um-card--wide
            b4um-card--large
            b4um-card--full
            b4um-card--soft

          Card content classes include:

            b4um-card__eyebrow
            b4um-card__title
            b4um-card__text
            b4um-card__actions
            b4um-card__media
            b4um-card__image

          The Bento grid is responsive and automatically adapts
          to tablet and mobile layouts.

          B4UM scaffolds automatically use the Bento card system
          for generated index pages.

          Cards use a repeating layout pattern:

            1 - wide
            2 - soft
            3 - normal
            4 - large
            5 - normal

          Long text fields are shortened on index cards while the
          complete content remains visible on the show page.


          FOOTER

          The installer can add an optional footer.

          Select the footer when running:

            bin/rails generate b4um:install

          The footer partial is created at:

            app/views/shared/_footer.html.erb

          The generated footer includes:

            - Automatic current year
            - Application name placeholder
            - Optional footer link examples

          Footer CSS classes use the b4um-footer prefix.


          SCAFFOLD

            bin/rails generate b4um:scaffold MODEL ATTRIBUTES

          Example:

            bin/rails generate b4um:scaffold User name:string email:string

          B4UM scaffold features:

            - B4UM forms
            - B4UM index, show, new and edit views
            - Automatic navigation entry
            - Active navigation state
            - Form validation errors
            - Flash messages
            - Password field support
            - Optional readable URL parameters


          READABLE URL PARAMETERS

          B4UM scaffolds can generate readable URLs while keeping
          the database ID in the URL.

          Use:

            --param=ATTRIBUTE

          Example:

            bin/rails generate b4um:scaffold Article title:string body:text --param=title

          This generates:

            def to_param
              "\#{id} \#{title}".parameterize
            end

          Example URL:

            /articles/17-my-first-article

          The ID remains part of the URL, so the standard Rails
          resource lookup can still be used.

          The readable part of the URL is updated automatically
          when the selected attribute changes.


          PASSWORDS

          For password authentication, use:

            password_digest:string

          Example:

            bin/rails generate b4um:scaffold User name:string email:string password_digest:string

          The B4UM scaffold automatically creates password fields
          instead of displaying password_digest directly.

          Password support requires bcrypt.

          Select bcrypt when running:

            bin/rails generate b4um:install

          B4UM adds bcrypt to the Gemfile if necessary and installs
          the selected Gem automatically.


          ACTIVE STORAGE / IMAGES

          Image attachments require Active Storage.

          Select Active Storage when running:

            bin/rails generate b4um:install

          B4UM installs Active Storage and runs the required database
          migration automatically if Active Storage is not already installed.


          Single image:

            image:attachment

          Example:

            bin/rails generate b4um:scaffold Article title:string image:attachment

          Multiple images:

            images:attachments

          Example:

            bin/rails generate b4um:scaffold Gallery title:string images:attachments

          Image features:

            - Active Storage integration
            - Image preview before saving
            - Existing image preview while editing
            - Add new images without removing existing images
            - Remove individual existing images
            - Image lightbox
            - Previous / next navigation
            - Mouse and touch swipe
            - Keyboard navigation


          CONTROLLER

            bin/rails generate b4um:controller NAME ACTIONS

          Example:

            bin/rails generate b4um:controller Pages home about impressum agb

          B4UM controller features:

            - Uses the standard Rails controller generator
            - Creates the requested actions and views
            - Adds action links to the B4UM navigation automatically


          COMMENTS

            bin/rails generate b4um:comments MODEL

          Example:

            bin/rails generate b4um:comments Article

          Adds polymorphic comments to an existing model.

          B4UM comments features:

            - Polymorphic Comment model
            - Comment association on the selected model
            - Nested create and destroy routes
            - Comments controller
            - Comment list and form
            - Delete confirmation
            - B4UM form and card styling
            - Support for multiple commentable models
            - Safe repeated generator runs

          Additional models can use the same comments system:

            bin/rails generate b4um:comments Product

          Existing B4UM comments controllers are extended automatically.
          Unknown custom comments controllers are left unchanged and cause
          the generator to stop with an error.


          HELP

            bin/rails generate b4um:help

          Shows this overview.

        TEXT
      end
    end
  end
end
