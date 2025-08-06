# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Only configure assets if Sprockets is available (Rails < 8.0 or when explicitly added)
if Rails.application.config.respond_to?(:assets)
  # Version of your assets, change this if you want to expire all your assets.
  Rails.application.config.assets.version = '1.0'

  # Add additional assets to the asset load path.
  # Rails.application.config.assets.paths << Emoji.images_path
end
