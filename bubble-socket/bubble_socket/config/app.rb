# frozen_string_literal: true
require 'hanami'

module BubbleSocket
  class App < Hanami::App
    config.actions.format :json

    environment(:development) do
      # Add development-specific configuration
    end

    environment(:test) do
      # Add test-specific configuration
    end

    environment(:production) do
      # Add production-specific configuration
    end
  end
end
