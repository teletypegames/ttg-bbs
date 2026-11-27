# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'securerandom'
require 'time'

module TTG
  module Feedback
    # Feedback the Central did not take because it was away (the gate
    # restarting): kept on the board, a JSON file each in
    # <tt>data/feedback-outbox</tt>, and sent again every RETRY seconds with
    # the time it was written, oldest first, until the Central takes it. One
    # older than KEEP is dropped (and logged).
    module Outbox
      # Seconds between two tries.
      RETRY = 60
      # Seconds a kept feedback is tried for.
      KEEP = 7 * 86_400
      # The answers that mean "not now": the feedback stays.
      LATER = %w[unavailable limited].freeze

      @lock = Mutex.new

      class << self
        # The folder of the kept feedback (default: the board's <tt>data/feedback-outbox</tt>).
        attr_writer :dir

        # The folder of the kept feedback.
        def dir = @dir || File.expand_path('data/feedback-outbox', Dir.pwd)
      end

      # Keeps the feedback of +actor+ (a Rubbs::Common::Central::Actor) with
      # +fields+ (the +submit+ op's) and starts the tries. Returns the file's path.
      def self.keep(actor, fields, at: Time.now)
        FileUtils.mkdir_p(dir)
        path = File.join(dir, "#{at.utc.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(3)}.json")
        File.write("#{path}.tmp", JSON.generate('actor' => actor.to_h, 'fields' => fields, 'at' => at.utc.iso8601))
        File.rename("#{path}.tmp", path)
        resume
        path
      end

      # Starts the tries when something is kept and none run. Returns the Thread, or +nil+.
      def self.resume
        @lock.synchronize do
          return nil if @worker&.alive? || pending.empty?

          @worker = Rubbs.background('feedback outbox', every: RETRY) { deliver }
        end
      end

      # The kept files, oldest first.
      def self.pending = Dir.glob(File.join(dir, '*.json'))

      # Sends what is kept, oldest first, until the Central says "not now".
      # Returns the number the Central took.
      def self.deliver(now: Time.now)
        sent = 0
        pending.each do |path|
          result = deliver_one(path, now)
          break if result == :later

          sent += 1 if result == :sent
        end
        sent
      end

      # Sends the feedback kept in +path+: +:sent+, +:later+ (the Central
      # says "not now", it stays) or +:dropped+ (too old, broken, or refused
      # for good).
      def self.deliver_one(path, now)
        item = JSON.parse(File.read(path))
        return drop(path, 'too old') || :dropped if now - Time.iso8601(item['at']) > KEEP

        answer = Feedback.box.call(:submit, actor_of(item['actor']), **fields_of(item), at: item['at'])
        return :later if LATER.include?(answer['result'])

        File.delete(path)
        answer['result'] == 'ok' ? :sent : :dropped
      rescue JSON::ParserError, ArgumentError, SystemCallError => e
        drop(path, "#{e.class}: #{e.message}") || :dropped
      end

      # The Actor of a kept Hash.
      def self.actor_of(hash) = Rubbs::Common::Central::Actor.new(**hash.transform_keys(&:to_sym))

      # The +submit+ fields of a kept item, as keywords.
      def self.fields_of(item) = item['fields'].to_h.transform_keys(&:to_sym)

      # Removes +path+, logging +why+. Returns +nil+.
      def self.drop(path, why)
        Rubbs.log('feedback outbox', "dropped #{File.basename(path)}: #{why}", level: :warn)
        FileUtils.rm_f(path)
        nil
      end
    end
  end
end
