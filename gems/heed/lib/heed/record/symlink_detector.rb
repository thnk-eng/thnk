# frozen_string_literal: true

require 'set'
require_relative '../error'

module Heed
  # @private api
  class Record
    class SymlinkDetector
      README_URL = 'https://github.com/guard/listen/blob/master/README.md'

      SYMLINK_LOOP_ERROR = <<-EOS.freeze
        ** ERROR: directory is already being watched! **

        Directory: %s

        is already being watched through: %s

        MORE INFO: #{README_URL}
      EOS

      Error = ::Heed::Error # for backward compatibility

      def initialize
        @real_dirs = Set.new
      end

      def verify_unwatched!(entry)
        real_path = entry.real_path
        @real_dirs.add?(real_path) or _fail(entry.sys_path, real_path)
      end

      # Leaving this stub here since some warning work-arounds were referring to it.
      # Deprecated. Will be removed in Listen v4.0.
      def warn(message)
        Heed.adapter_warn(message)
      end

    private

      def _fail(symlinked, real_path)
        warn(format(SYMLINK_LOOP_ERROR, symlinked, real_path))
        raise ::Heed::Error::SymlinkLoop, 'Failed due to looped symlinks'
      end
    end
  end
end