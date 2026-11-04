# frozen_string_literal: true

require 'json'

module Discovery
  # The CBBS Outpost's list of Commodore BBSes (commodorebbs.com/api/bbs, the
  # site's own public JSON): an array of objects, one a board. Only the facts
  # are taken: the name, the telnet address and port, the location, the
  # software, the hardware, the website and when the entry was updated.
  # Everything personal (the sysop, the e-mail, the owner's user name) and
  # the site's own judgements (online, the comment, the screenshot, the
  # favourite marks) are never read into a record.
  #
  # An address may be a URL (telnet:// is read, http(s):// is a web site and
  # left out), carry an IP in brackets, or name two hosts ("a or b"); the
  # first host wins. Every record has the hint platform: Commodore, the claim
  # of the list a source-map rule turns into claims:petscii.
  module CbbsJsonParser
    TELNET_PORT = 23
    # The fields a record is made of; nothing else of an entry is looked at.
    TAKEN = %w[name address port location software hardware website updated_at].freeze

    module_function

    def parse(bytes, source)
      entries = JSON.parse(TextDecoder.decode(bytes))
      raise ArgumentError, 'the CBBS list is not a JSON array' unless entries.is_a?(Array)

      entries.filter_map { |e| record(e.slice(*TAKEN), source) if e.is_a?(Hash) }.uniq(&:key)
    rescue JSON::ParserError => e
      raise ArgumentError, "the CBBS list is not JSON: #{e.message[0, 80]}"
    end

    def record(entry, source)
      host, port = endpoint(entry['address'].to_s, entry['port'])
      return unless host && port

      RecordModel.new(
        source_id: source.id,
        host:      host,
        port:      port,
        name:      text(entry['name']),
        location:  text(entry['location']),
        software:  text(entry['software']),
        hardware:  text(entry['hardware']),
        website:   website(entry['website']),
        hints:     { 'platform' => 'Commodore', 'updated_at' => text(entry['updated_at']) }.compact
      )
    end

    # [host, port] of an entry, or nil when it is no telnet address.
    def endpoint(address, port)
      address = address.strip
      return if address.match?(%r{\A[a-z][a-z0-9+.-]*://}i) && !address.match?(%r{\Atelnet://}i)

      address = address.sub(%r{\Atelnet://}i, '').sub(%r{/.*\z}, '')
      token = address.split(/[\s,;]+/).find { |t| Address.host(t.sub(/:\d+\z/, '')) }
      return unless token

      host, own_port = token.match(/\A(.+?)(?::(\d+))?\z/).captures
      [Address.host(host), Address.port(own_port || port || TELNET_PORT)]
    end

    # A web address the list gives, nil for its "None".
    def website(value)
      value = text(value)
      value unless value.nil? || value.casecmp?('none') || !value.match?(/\w\.\w/)
    end

    def text(value) = Address.text(value)
  end
end
