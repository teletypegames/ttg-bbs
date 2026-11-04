# frozen_string_literal: true

require 'cgi'

module Discovery
  # The Synchronet BBS List as Vertrauen exports it in HTML (sbbslist.html,
  # written by sbbslist_html.js): a table row a system, its cells the name
  # and description, the year it went online, the operators, the location, the
  # terminal services, the networks and the last verification. Every telnet
  # service of a system is an endpoint; its comment (e.g. PETSCII-40) and the
  # system's networks are hints. The software is the verification's software
  # line ("Synchronet BBS for Linux  Version 3.22").
  module SblHtmlParser
    module_function

    def parse(bytes, source)
      html = TextDecoder.decode(bytes, fallback: Encoding::ISO_8859_1).gsub(%r{<pre\b.*?</pre>}m, '')
      body = html[%r{<tbody>(.*)</tbody>}m, 1]
      return [] unless body

      body.split('<td class="bbsName">').drop(1).flat_map { |chunk| system(chunk, source) }.uniq(&:key)
    end

    def system(chunk, source)
      cells = chunk.split('</table>')
      return [] if cells.size < 7

      fields = system_fields(cells)
      ftn, names = networks(cells[5])
      services(cells[4]).map do |host, port, comment|
        RecordModel.new(
          source_id:   source.id,
          host:        host,
          port:        port,
          ftn_address: ftn,
          **fields,
          hints:       { 'comment' => comment, 'networks' => names }.reject { |_, v| v.nil? || v.empty? }
        )
      end
    end

    # The fields of a system that hold for each of its services.
    def system_fields(cells)
      {
        name:     name(cells[0]),
        since:    cells[1][/\b(?:19|20)\d\d\b/]&.to_i,
        sysop:    Address.text(rows(cells[2]).join(', ')),
        location: rows(cells[3]).first,
        software: software(cells[6])
      }
    end

    # [the first FTN address, the network names] of the networks cell.
    def networks(cell)
      networks = cell.scan(%r{<div(?:\s+title="([^"]*)")?>\s*([^<]+?)\s*</div>}m)
      ftn = networks.filter_map { |title, _| title.to_s[%r{\b\d+:\d+/\d+\b}] }.first
      [ftn, networks.map { |_, n| clean(n) }.compact.uniq]
    end

    # The system's name: the link's text, or the bare text after the anchor.
    def name(cell)
      head = cell.sub(%r{<a name="[^"]*"\s*/?>(?:</a>)?}, '').split('<tr>').first.to_s
      clean(head)
    end

    def rows(cell) = cell.split('<tr').filter_map { |row| clean(row.sub(/\A[^>]*>/, '')) }

    # [host, port, comment] of each telnet service.
    def services(cell)
      cell.scan(%r{<a href="telnet://([^"]+)">.*?</a>\s*\(telnet\)([^<\n]*)}m).filter_map do |url, comment|
        host, port = url.chomp('/').match(/\A(\[[^\]]+\]|[^:]+)(?::(\d+))?\z/)&.captures
        host = Address.host(CGI.unescapeHTML(host.to_s))
        port = Address.port(port || 23)
        [host, port, Address.text(comment)] if host && port
      end
    end

    def software(cell)
      lines = cell.split(/<div[^>]*>/, 2)[1].to_s.split('</div>').first.to_s.lines.filter_map { |l| clean(l) }
      lines.find { |l| l.match?(/\bversion\b/i) }
    end

    def clean(html) = Address.text(CGI.unescapeHTML(html.to_s.gsub(/<[^>]*>/, ' ')))
  end
end
