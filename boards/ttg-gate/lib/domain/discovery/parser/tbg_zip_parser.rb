# frozen_string_literal: true

require 'cgi'

module Discovery
  # The Telnet BBS Guide's monthly list (telnetbbsguide.com, IBBSmmyy.ZIP):
  # the zip as it is downloaded, or its full listing alone. The full listing
  # (full_<Mon>_<yy>.txt) is the one file of the zip with the facts: a block
  # a board between dashed lines, its name on the first line (in capitals, a
  # "* " in front of a new one), then fixed "Key: value" lines from Last
  # Updated to Software and a free description; the blocks without a Last
  # Updated line are the list's own header. The EtherTerm phonebook of the zip (dialdirectory.xml) gives
  # the names as their sysops write them, by host and port.
  #
  # Only the facts are taken: the name, the Telnet host:port, the location,
  # the software, the web address and the date of the entry. The Email line
  # and the description are never read into a record, except that a
  # description naming PETSCII becomes the hint mentions: PETSCII, the claim a
  # source-map rule turns into claims:petscii. The SSH, web-only and dial-up
  # entries have no Telnet line and are left out.
  module TbgZipParser
    TELNET_PORT = 23
    FULL        = /\Afull_\w+_\d{2}\.txt\z/i
    PHONEBOOK   = /\Adialdirectory\.xml\z/i
    SEPARATOR   = /^-{40,}\s*$/
    FIELD       = /\A\s*(Telnet|SSH|WEB|Email|Location|Dial-Up|Software|Last Updated):[ \t]*(.*)\z/i
    # The words of a description that are a claim the source map reads.
    MENTIONS = { 'PETSCII' => /\bpetscii\b/i }.freeze

    module_function

    def parse(bytes, source)
      full, phonebook = members(bytes)
      names = phonebook ? names(TextDecoder.decode(phonebook)) : {}
      blocks = TextDecoder.decode(full).split(SEPARATOR)
      records = blocks.filter_map { |b| record(b, names, source) }.uniq(&:key)
      raise ArgumentError, 'the Telnet BBS Guide list has no boards' if records.empty?

      records
    end

    # [the full listing, the phonebook or nil] of a zip, or the bytes alone.
    def members(bytes)
      return [bytes, nil] unless bytes.b.start_with?(ZipReader::LOCAL)

      full = ZipReader.read(bytes, FULL) or raise ArgumentError, 'no full_*.txt in the Telnet BBS Guide zip'
      [full, ZipReader.read(bytes, PHONEBOOK)]
    end

    # The phonebook's names by host:port, its Telnet entries only.
    def names(xml)
      xml.scan(/<BBS\s[^>]*>/i).each_with_object({}) do |tag, names|
        attrs = tag.scan(/(\w+)="([^"]*)"/).to_h { |k, v| [k.downcase, CGI.unescapeHTML(v)] }
        next unless attrs['protocol'].to_s.casecmp?('telnet')

        host = Address.host(attrs['ip'])
        port = Address.port(attrs['port'].to_s.empty? ? TELNET_PORT : attrs['port'])
        name = text(attrs['name'])
        names["#{host}:#{port}"] ||= name if host && port && name
      end
    end

    def record(block, names, source)
      lines = block.lines.map(&:rstrip)
      fields, last = labelled(lines)
      return unless last && fields.key?('last updated')

      host, port = endpoint(fields['telnet'])
      return unless host && port

      RecordModel.new(
        source_id: source.id,
        host:      host,
        port:      port,
        name:      names["#{host}:#{port}"] || title(lines),
        location:  location(fields['location']),
        software:  software(fields['software']),
        website:   website(fields['web']),
        hints:     hints(fields, lines[(last + 1)..].join("\n"))
      )
    end

    # The "Label: value" fields of a block by their lowercase label, and the
    # index of the last one (the description follows it).
    def labelled(lines)
      fields = {}
      last = nil
      lines.each_with_index do |line, i|
        next unless (m = line.match(FIELD))

        fields[m[1].downcase] = m[2]
        last = i
      end
      [fields, last]
    end

    # The block's first line that is not empty, without its star.
    def title(lines)
      title = lines.find { |l| !l.strip.empty? && !l.strip.casecmp?('&nbsp;') }
      text(title.to_s.sub(/\A\s*\*\s*/, ''))
    end

    def software(value) = text(value.to_s.sub(/\s*Total Nodes:.*\z/i, ''))

    # The update date and what the +description+ mentions.
    def hints(fields, description)
      mentions = MENTIONS.select { |_, pattern| description.match?(pattern) }.keys
      { 'updated_at' => text(fields['last updated']), 'mentions' => mentions.empty? ? nil : mentions }.compact
    end

    # [host, port] of a Telnet line ("host" or "host:port"), or nil.
    def endpoint(value)
      token = text(value).to_s.sub(%r{\Atelnet://}i, '').split(/[\s,;]+/).first.to_s.sub(%r{/.*\z}, '')
      host, port = token.match(/\A(.+?)(?::(\d+))?\z/)&.captures
      [Address.host(host), Address.port(port || TELNET_PORT)]
    end

    # "Hofheim, , Germany" without its empty parts.
    def location(value)
      text(text(value).to_s.split(',').filter_map { |part| text(part) }.join(', '))
    end

    def website(value)
      value = text(value)
      value if value&.match?(/\w\.\w/)
    end

    def text(value) = Address.text(value && CGI.unescapeHTML(value.to_s))
  end
end
