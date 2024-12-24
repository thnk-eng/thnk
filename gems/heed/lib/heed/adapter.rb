# frozen_string_literal: true

require_relative 'adapter/base'
require_relative 'adapter/bsd'
require_relative 'adapter/darwin'
require_relative 'adapter/linux'
require_relative 'adapter/polling'
require_relative 'adapter/windows'

module Heed
  module Adapter
    OPTIMIZED_ADAPTERS = [Darwin, Linux, BSD, Windows].freeze
    POLLING_FALLBACK_MESSAGE = 'Listen will be polling for changes.'\
      'Learn more at https://github.com/guard/listen#listen-adapters.'

    class << self
      def select(options = {})
        Heed.logger.debug 'Adapter: considering polling ...'
        return Polling if options[:force_polling]
        Heed.logger.debug 'Adapter: considering optimized backend...'
        return _usable_adapter_class if _usable_adapter_class
        Heed.logger.debug 'Adapter: falling back to polling...'
        _warn_polling_fallback(options)
        Polling
      rescue
        Heed.logger.warn format('Adapter: failed: %s:%s', $ERROR_POSITION.inspect, $ERROR_POSITION * "\n")
        raise
      end

    private

      def _usable_adapter_class
        OPTIMIZED_ADAPTERS.find(&:usable?)
      end

      def _warn_polling_fallback(options)
        msg = options.fetch(:polling_fallback_message, POLLING_FALLBACK_MESSAGE)
        Heed.adapter_warn("[Heed warning]:\n  #{msg}") if msg
      end
    end
  end
end