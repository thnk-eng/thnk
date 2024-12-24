# frozen_string_literal: true

require_relative '../thread'
require 'digest'
require 'pathname'
require 'rb-fsevent'

module Heed
  module Adapter
    # Adapter implementation for Mac OS X `FSEvents`.
    class Darwin < Base
      OS_REGEXP = /darwin(?<major_version>(1|2)\d+)/i

      # The default delay between checking for changes.
      DEFAULTS = { latency: 0.1 }.freeze

      INCOMPATIBLE_GEM_VERSION = <<-EOS.gsub(/^ {8}/, '')
        rb-fsevent > 0.9.4 no longer supports OS X 10.6 through 10.8.

        Please add the following to your Gemfile to avoid polling for changes:
          require 'rbconfig'
          if RbConfig::CONFIG['target_os'] =~ /darwin(1[0-3])/i
            gem 'rb-fsevent', '<= 0.9.4'
          end
      EOS

      def self.usable?
        version = RbConfig::CONFIG['target_os'][OS_REGEXP, :major_version]
        return false unless version
        return true if version.to_i >= 13 # darwin13 is OS X 10.9
        require 'rb-fsevent'
        fsevent_version = Gem::Version.new(FSEvent::VERSION)
        return true if fsevent_version <= Gem::Version.new('0.9.4')
        Heed.adapter_warn(INCOMPATIBLE_GEM_VERSION)
        false
      end

      def initialize(options = {})
        super
        @callbacks = {}
        @file_hashes = {}
      end

    private

      def _configure(dir, &callback)
        @callbacks[dir] = callback
      end

      def _run
        worker = FSEvent.new
        dirs_to_watch = @callbacks.keys.map(&:to_s)
        Heed.logger.info { "fsevent: watching: #{dirs_to_watch.inspect}" }
        worker.watch(dirs_to_watch, { latency: options.latency }, &method(:_process_changes))
        @worker_thread = Heed::Thread.new("worker_thread") { worker.run }
      end

      def _process_changes(dirs)
        dirs.each do |dir|
          dir = Pathname.new(dir.sub(%r{/$}, ''))

          @callbacks.each do |watched_dir, callback|
            if watched_dir.eql?(dir) || Heed::Directory.ascendant_of?(watched_dir, dir)
              callback.call(dir)
            end
          end
        end
      end

      def _process_event(dir, path)
        Heed.logger.debug { "fsevent: processing path: #{path.inspect}" }
        rel_path = path.relative_path_from(dir).to_s

        if should_process_event?(path)
          _queue_change(:dir, dir, rel_path, recursive: true)
        end
      end

      def should_process_event?(path)
        return true if /1|true/ =~ ENV['HEED_GEM_DISABLE_HASHING']

        stat = path.lstat
        return true unless inaccurate_mac_time?(stat)

        # Check if change happened within 2 seconds
        time_difference = Time.now.to_f - stat.mtime.to_f
        if time_difference < 2.0
          old_sha = @file_hashes[path]
          new_sha = Digest::SHA256.file(path).digest
          @file_hashes[path] = new_sha
          return old_sha != new_sha
        end

        false
      end

      def inaccurate_mac_time?(stat)
        [stat.mtime, stat.ctime, stat.atime].map(&:usec).all?(&:zero?)
      end

      def _stop
        @worker_thread&.kill
        super
      end
    end
  end
end