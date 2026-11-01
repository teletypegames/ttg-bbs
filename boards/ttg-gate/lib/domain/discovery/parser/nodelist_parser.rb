# frozen_string_literal: true

module Discovery
  # An FTN nodelist (FTS-5000; FidoNet, fsxNet, Micronet, …): one node a line,
  # +keyword,number,name,location,sysop,phone,speed,flags…+, the words joined
  # by underscores. A node is a telnet endpoint when it has the ITN flag:
  # +ITN+ (port 23), +ITN:port+, +ITN:host+ or +ITN:host:port+; without a host
  # there it is the node's first INA:host, or the system name when that is a
  # host name. Down nodes and comments are left out.
  module NodelistParser
    TELNET_PORT = 23

    module_function

    # The telnet nodes of +bytes+ as RecordModels of +source+ (a SourceModel),
    # one an endpoint (the first node wins).
    def parse(bytes, source)
      zone = net = nil
      records = []
      TextDecoder.decode(bytes).each_line do |raw|
        line = raw.strip
        next if line.empty? || line.start_with?(';', "\x1A")

        fields = line.split(',', -1)
        number = Integer(fields[1].to_s, 10, exception: false)
        next if fields.size < 7 || number.nil?

        keyword = fields[0].strip.downcase
        node = 0
        case keyword
        when 'zone' then zone = net = number
        when 'region', 'host' then net = number
        when 'down' then next
        else node = number
        end
        next if zone.nil?

        record = record(fields, "#{zone}:#{net}/#{node}", source)
        records << record if record
      end
      records.uniq(&:key)
    end

    def record(fields, address, source)
      flags = fields[7..] || []
      endpoint = telnet(fields[2], flags)
      return unless endpoint

      RecordModel.new(source_id: source.id, host: endpoint[0], port: endpoint[1],
                      name: words(fields[2]), location: words(fields[3]), sysop: words(fields[4]),
                      ftn_address: address)
    end

    # [host, port] of a node's ITN flag, or nil.
    def telnet(name, flags)
      itn = flags.map(&:strip).find { |f| f.match?(/\AITN(?::|\z)/i) }
      return unless itn

      value = itn.split(':', 2)[1].to_s
      host, port = if value.empty? then [nil, TELNET_PORT]
                   elsif value.match?(/\A\d+\z/) then [nil, value]
                   elsif value.include?(':') then value.split(':', 2)
                   else [value, TELNET_PORT]
                   end
      host = Address.host(host || ina(flags) || name.to_s.tr('_', '.'))
      port = Address.port(port)
      host && port ? [host, port] : nil
    end

    def ina(flags)
      flag = flags.map(&:strip).find { |f| f.match?(/\AINA:/i) }
      flag&.split(':', 2)&.last
    end

    def words(field) = Address.text(field.to_s.tr('_', ' '))
  end
end
