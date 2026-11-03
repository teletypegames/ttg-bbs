# frozen_string_literal: true

module UI
  module Modern
    # The Jargon File on the modern face: the word of the day, the letters,
    # the search, a random entry, the chapters, and an entry with its links.
    module Jargon
      NOT_READY = 'The Jargon File is being prepared. Try again in a moment.'

      def jargon_today = open_jargon(jargon.word_of_the_day, 'Word of the day: ')

      def jargon_random = open_jargon(jargon.random)

      def jargon_letters
        return jargon_preparing unless jargon.ready?

        show(:jargon_letters, letters: jargon.letters)
      end

      def jargon_letter(letter)
        list = jargon.letter(letter)
        show(:jargon_entries, entries: list, heading: "Jargon: #{letter == '0' ? '0-9' : letter} (#{list.size})")
      end

      def jargon_search
        return jargon_preparing unless jargon.ready?

        ask('Words of a headword or of the text:', title: 'Search the lexicon', value: context[:jargon_query].to_s,
                                                   width: 64) { |query| jargon_find(query) }
      end

      def jargon_find(query)
        context[:jargon_query] = query
        case (found = jargon.search(query))
        when :too_short then message('A word of two letters or more, please.', title: 'Jargon')
        when [] then message('No entry has these words.', title: 'Jargon')
        else show(:jargon_entries, entries: found, heading: "Jargon: #{query.strip[0, 40]} (#{found.size})")
        end
      end

      def jargon_chapters
        return jargon_preparing unless jargon.ready?

        show(:jargon_sections, sections: jargon.sections)
      end

      # An entry: the headword, its pronunciation, the text with its
      # {links}, and the File's credit under it.
      def open_jargon(entry, prefix = '')
        return jargon_preparing unless entry

        show(:jargon_entry, entry: entry, heading: "#{prefix}#{entry.headword}")
      end

      def jargon_paragraphs(entry)
        [[:heading, [entry.headword, entry.pron].reject(&:empty?).join('  ')], *entry.paragraphs]
      end

      def jargon_links(entry)
        list = jargon.links(entry)
        return message("#{entry.headword} links to no other entry.", title: 'Links') if list.empty?

        show(:jargon_entries, entries: list, heading: "Links of #{entry.headword} (#{list.size})")
      end

      def open_section(section)
        show(:text, heading: section.title, paragraphs: section.paragraphs, credit: JargonService::CREDIT)
      end

      def jargon_preparing = message(NOT_READY, title: 'Jargon File')
    end
  end
end
