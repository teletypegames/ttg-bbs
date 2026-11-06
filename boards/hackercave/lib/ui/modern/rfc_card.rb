# frozen_string_literal: true

module UI
  module Modern
    # An RFC's record on the right of a list: the title, the authors and the
    # date, the status and the series, a red line when a newer RFC replaced
    # it, the other links, the abstract and the credit.
    module RfcCard
      def rfc_lines(entry)
        rfc = entry.rfc
        [*rfc_heading(entry), *rfc_links(rfc), '', *abstract_lines(rfc), rfc_credit(rfc), '', dim(rfc_hint(rfc))]
      end

      private

      def rfc_heading(entry)
        rfc = entry.rfc
        [bright("#{rfc.name}: #{rfc.title}"),
         *(paint(:label, entry.note) if entry.kind == :remark),
         *("#{paint(:label, 'Found:')} #{entry.note}" if entry.kind == :match),
         *(accent(rfc.author_list.join(', ')) unless rfc.authors.empty?),
         dim(rfc_facts(rfc).join(' · '))]
      end

      def rfc_facts(rfc)
        reads = library.reads(rfc)
        [rfc.date_label, ("#{rfc.pages} pages" if rfc.pages.positive?), rfc.ien? ? 'Internet Experiment Note' : rfc_status(rfc),
         "read #{reads} time#{'s' unless reads == 1} here"].compact.reject(&:empty?)
      end

      def rfc_status(rfc)
        return nil if rfc.status.empty?

        series = library.series_of(rfc)
        series.empty? ? rfc.status_label : "#{rfc.status_label} (#{series.join(', ')})"
      end

      # The relations of the RFC, "obsoleted by" in red, and its errata.
      def rfc_links(rfc)
        return [] if rfc.status.empty?

        links = library.relations(rfc).map do |kind, numbers|
          "#{paint(kind == 'obsoleted by' ? :error : :label, "#{kind.capitalize}:")} #{numbers.map { |n| "RFC #{n}" }.join(', ')}"
        end
        [*links, *errata_line(rfc)]
      end

      def errata_line(rfc)
        count = library.errata_count(rfc)
        return [] if count[:total].zero?

        ["#{paint(:label, 'Errata:')} #{count[:total]} (#{count[:verified]} verified) — Alt-E"]
      end

      def abstract_lines(rfc)
        return [] if rfc.abstract.empty?

        [*rfc.abstract.split("\n\n").flat_map { |p| [p, ''] }]
      end

      def rfc_hint(rfc)
        return "Only a scan of it is kept: #{rfc.url}" unless rfc.text?

        'Enter reads it. Alt-L: its links.'
      end

      def rfc_credit(rfc) = dim("#{rfc.name}#{', IETF' unless rfc.ien?} · #{rfc.url}")
    end
  end
end
