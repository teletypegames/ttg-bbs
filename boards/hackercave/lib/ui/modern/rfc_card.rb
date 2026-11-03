# frozen_string_literal: true

module UI
  module Modern
    # An RFC's record on the right of a list: the title, the authors and the
    # date, the status and the series, a red line when a newer RFC replaced
    # it, the other links, the abstract and the credit.
    module RfcCard
      def rfc_lines(entry, width)
        rfc = entry.rfc
        wrap = ->(s) { s.empty? ? [s] : BBS::FrameBuffer.wrap_ansi(s, width - 1) }
        [*rfc_heading(entry), *rfc_links(rfc), '', *abstract_lines(rfc), rfc_credit(rfc), '',
         "#{theme[:text_dim]}Enter reads it. Alt-L: its links.#{theme[:text]}"].flat_map { |line| wrap.call(line) }
      end

      private

      def rfc_heading(entry)
        t = theme
        rfc = entry.rfc
        ["#{t[:text_bright]}#{rfc.name}: #{rfc.title}#{t[:text]}",
         *("#{t[:label]}#{entry.note}#{t[:text]}" if entry.kind == :remark),
         *("#{t[:accent]}#{rfc.author_list.join(', ')}#{t[:text]}" unless rfc.authors.empty?),
         "#{t[:text_dim]}#{rfc_facts(rfc).join(' · ')}#{t[:text]}"]
      end

      def rfc_facts(rfc)
        reads = library.reads(rfc)
        [rfc.date_label, ("#{rfc.pages} pages" if rfc.pages.positive?), rfc_status(rfc),
         "read #{reads} time#{'s' unless reads == 1} here"].compact.reject(&:empty?)
      end

      def rfc_status(rfc)
        return nil if rfc.status.empty?

        series = library.series_of(rfc)
        series.empty? ? rfc.status_label : "#{rfc.status_label} (#{series.join(', ')})"
      end

      # The relations of the RFC, "obsoleted by" in red.
      def rfc_links(rfc)
        return [] if rfc.status.empty?

        library.relations(rfc).map do |kind, numbers|
          style = kind == 'obsoleted by' ? :error : :label
          "#{theme[style]}#{kind.capitalize}:#{theme[:text]} #{numbers.map { |n| "RFC #{n}" }.join(', ')}"
        end
      end

      def abstract_lines(rfc)
        return [] if rfc.abstract.empty?

        [*rfc.abstract.split("\n\n").flat_map { |p| [p, ''] }]
      end

      def rfc_credit(rfc) = "#{theme[:text_dim]}#{rfc.name}, IETF · #{rfc.url}#{theme[:text]}"
    end
  end
end
