# frozen_string_literal: true

require 'dry-configurable'

module BubbleSocket
  class Settings < Hanami::Settings
    # Define your app settings here, for example:
    #
    # setting :my_flag, default: false, constructor: Types::Params::Bool
    #
    extend Dry::Configurable

    setting :openai_api_key, reader: true
    setting :assistant_id, reader: true
    setting :redis_url, reader: true
    setting :database_url, reader: true
  end
end
