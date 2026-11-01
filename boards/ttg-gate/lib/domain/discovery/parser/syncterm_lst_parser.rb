# frozen_string_literal: true

module Discovery
  # A SyncTERM BBS list (syncterm.lst): an ini section an entry, the section
  # name the entry's name (the SBL export pads a second word, the service, to
  # the right: "Vertrauen           PETSCII-40"), ConnectionType, Address,
  # Port, ScreenMode and Comment its keys. Only the telnet entries are taken;
  # ScreenMode, the service word and the comment are hints.
  module SynctermLstParser
    TELNET_PORT = 23

    module_function

    def parse(bytes, source)
      sections(TextDecoder.decode(bytes)).filter_map { |title, keys| record(title, keys, source) }.uniq(&:key)
    end

    def sections(text)
      sections = []
      text.each_line do |raw|
        line = raw.strip
        next if line.empty? || line.start_with?(';', '#')

        if (title = line[/\A\[(.*)\]\z/, 1])
          sections << [title, {}]
        elsif sections.any? && (pair = line.match(/\A([^=]+)=(.*)\z/))
          sections.last[1][pair[1].strip.downcase] = pair[2].strip
        end
      end
      sections
    end

    def record(title, keys, source)
      return unless keys['connectiontype'].to_s.casecmp?('telnet')

      address = keys['address'].to_s
      port = keys['port']
      if (m = address.match(/\A([^:\[\]]+):(\d+)\z/))
        address, port = m.captures
      end
      host = Address.host(address)
      port = Address.port(port || TELNET_PORT)
      return unless host && port

      name, service = title.strip.split(/\s{2,}/, 2)
      hints = { 'screen_mode' => keys['screenmode'], 'service' => Address.text(service),
                'comment' => Address.text(keys['comment']) }.compact
      RecordModel.new(source_id: source.id, host: host, port: port, name: Address.text(name), hints: hints)
    end
  end
end
