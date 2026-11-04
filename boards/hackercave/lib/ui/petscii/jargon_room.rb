# frozen_string_literal: true

module UI
  # The Jargon File on the C64: the word of the day, a search, the entries
  # by letter, a random entry, and the chapters and folklore to read; an
  # entry is a page with L for the entries it links to and R for a random
  # one.
  class Petscii
    sub_menu(
      :jargon,
      title: 'THE JARGON FILE',
      right: '4.4.7 ',
      above: -> { " #{GR}The lexicon of hacker slang, public domain.#{LG}" },
      gap:   :after
    ) do
      item('1', 'word of the day', 'the same for everyone today') { jargon_today }
      item('2', 'search', 'a headword or words of the text') { jargon_search }
      item('3', 'a to z', 'the entries by letter') { jargon_letters }
      item('4', 'random entry', 'surprise me') { jargon_random }
      item('5', 'chapters and folklore', 'the story of mel, the koans') { jargon_chapters }
      back 'to the main menu'
    end

    private

    def jargon_room
      return alert('The Jargon File is being prepared. Try again in a moment.', color: YE) unless jargon.ready?

      sub_menu(:jargon)
    end

    def jargon_today = jargon_entry(jargon.word_of_the_day)

    def jargon_random = jargon_entry(jargon.random)

    def jargon_search
      title('SEARCH THE JARGON FILE')
      puts
      query = prompt('search', max: 60) or return

      case (found = jargon.search(query))
      when :too_short then alert('A word of two letters or more, please.', color: YE)
      when [] then alert('No entry has these words.', color: YE)
      else jargon_entries("JARGON: #{query.strip.upcase}"[0, 26], found)
      end
    end

    def jargon_letters
      label = ->((l, n)) { "#{l == '0' ? '0-9 and signs' : l.downcase} #{GR}#{n}#{LG}" }
      each_pick('THE LEXICON', jargon.letters, right: "#{jargon.count} ", label: label) do |(l, _)|
        jargon_entries("JARGON: #{l}", jargon.letter(l))
      end
    end

    def jargon_entries(heading, list)
      each_pick(heading, list, empty: 'no entries.', right: "#{list.size} ", label: :headword) { |e| jargon_entry(e) }
    end

    # An entry on pages, then: L its links, R a random one, Q back.
    def jargon_entry(entry)
      while entry
        page(entry.headword.upcase[0, 30], jargon_text(entry), wait: false, numbers: true)
        entry = case actions(%w[l links], %w[r random], %w[q back])
                when 'l' then jargon_links(entry)
                when 'r' then jargon.random
                end
      end
    end

    # The entries +entry+ links to; the one picked, or nil.
    def jargon_links(entry)
      list = jargon.links(entry)
      if list.empty?
        alert("#{entry.headword} links to no other entry.", color: YE)
        return nil
      end

      pick("LINKS OF #{entry.headword.upcase}"[0, 30], list, right: "#{list.size} ", &:headword)
    end

    def jargon_chapters
      list = jargon.sections
      each_pick('CHAPTERS AND FOLKLORE', list, right: "#{list.size} ", label: ->(s) { s.title.downcase }) do |s|
        page(s.title.upcase[0, 30], jargon_paragraphs(s.paragraphs), numbers: true)
      end
    end

    def jargon_text(entry)
      [*(" #{GR}#{plain(entry.pron)}#{LG}" unless entry.pron.empty?), *jargon_paragraphs(entry.paragraphs), '',
       " #{GR}#{JargonService::CREDIT.downcase}#{LG}"]
    end

    # Paragraphs wrapped to the screen: a heading white, a {link} cyan, an
    # example line by line.
    def jargon_paragraphs(list)
      list.each_with_index.flat_map do |(kind, body), i|
        [*('' unless i.zero?), *jargon_paragraph(kind, plain(body))]
      end
    end

    def jargon_paragraph(kind, body)
      case kind
      when :heading then wrap(body).map { |l| " #{WH}#{l}#{LG}" }
      when :pre then body.split("\n").flat_map { |l| l.strip.scan(/.{1,#{WIDTH}}/) }.map { |l| " #{GR}#{l}#{LG}" }
      else wrap(body.gsub(JargonEntryModel::LINK) { "#{CY}#{::Regexp.last_match(1)}#{LG}" }).map { |l| " #{l}" }
      end
    end
  end
end
