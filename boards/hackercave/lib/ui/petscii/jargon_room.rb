# frozen_string_literal: true

module UI
  module Petscii
    # The Jargon File on the C64: the word of the day, a search, the
    # entries by letter, a random entry, and the chapters and folklore to
    # read; an entry is a page with L for the entries it links to and R for
    # a random one.
    class JargonRoom
      def initialize(jargon, screen)
        @jargon = jargon
        @screen = screen
      end

      def run
        return message('The Jargon File is being prepared. Try again in a moment.') unless @jargon.ready?

        loop do
          @screen.title('THE JARGON FILE', '4.4.7 ')
          @screen.say('The lexicon of hacker slang, public domain.', color: GR)
          @choice = @screen.menu(items, index: items.index { |i|
            i.value == @choice
          }, back: 'q', hint: 'crsr: choose  return: take')
          return if @choice == 'q'

          take(@choice)
        end
      end

      private

      def items
        @items ||= [
          BBS::Selector.item('word of the day', key: '1', value: '1', about: 'the same for everyone today'),
          BBS::Selector.item('search', key: '2', value: '2', about: 'a headword or words of the text'),
          BBS::Selector.item('a to z', key: '3', value: '3', about: 'the entries by letter'),
          BBS::Selector.item('random entry', key: '4', value: '4', about: 'surprise me'),
          BBS::Selector.item('chapters and folklore', key: '5', value: '5', about: 'the story of mel, the koans'),
          BBS::Selector.item('back', key: 'q', value: 'q', about: 'to the main menu')
        ]
      end

      def take(choice)
        case choice
        when '1' then entry(@jargon.word_of_the_day)
        when '2' then search
        when '3' then letters
        when '4' then entry(@jargon.random)
        when '5' then chapters
        end
      end

      def search
        @screen.title('SEARCH THE JARGON FILE')
        @screen.puts
        query = BBS::Field.ask(@screen.session, ' search> ', max: 60)
        return if query.nil? || query.strip.empty?

        case (found = @jargon.search(query))
        when :too_short then message('A word of two letters or more, please.')
        when [] then message('No entry has these words.')
        else entries("JARGON: #{query.strip.upcase}"[0, 26], found)
        end
      end

      def letters
        list = @jargon.letters
        loop do
          picked = @screen.pick('THE LEXICON', list, right: "#{@jargon.count} ") do |(l, n)|
            "#{l == '0' ? '0-9 and signs' : l.downcase} #{GR}#{n}#{LG}"
          end
          return unless picked

          entries("JARGON: #{picked.first}", @jargon.letter(picked.first))
        end
      end

      def entries(heading, list)
        loop do
          picked = @screen.pick(heading, list, empty: 'no entries.', right: "#{list.size} ", &:headword)
          return unless picked

          entry(picked)
        end
      end

      # An entry on pages, then: L its links, R a random one, Q back.
      def entry(entry)
        while entry
          @screen.page(entry.headword.upcase[0, 30], text(entry), wait: false, numbers: true)
          entry = case @screen.actions(%w[l links], %w[r random], %w[q back])
                  when 'l' then links(entry)
                  when 'r' then @jargon.random
                  end
        end
      end

      # The entries +entry+ links to; the one picked, or nil.
      def links(entry)
        list = @jargon.links(entry)
        if list.empty?
          message("#{entry.headword} links to no other entry.")
          return nil
        end

        @screen.pick("LINKS OF #{entry.headword.upcase}"[0, 30], list, right: "#{list.size} ", &:headword)
      end

      def chapters
        list = @jargon.sections
        loop do
          picked = @screen.pick('CHAPTERS AND FOLKLORE', list, right: "#{list.size} ") { |s| s.title.downcase }
          return unless picked

          @screen.page(picked.title.upcase[0, 30], paragraphs(picked.paragraphs), numbers: true)
        end
      end

      def text(entry)
        [*(" #{GR}#{@screen.plain(entry.pron)}#{LG}" unless entry.pron.empty?), *paragraphs(entry.paragraphs), '',
         " #{GR}#{JargonService::CREDIT.downcase}#{LG}"]
      end

      # Paragraphs wrapped to the screen: a heading white, a {link} cyan, an
      # example line by line.
      def paragraphs(list)
        list.each_with_index.flat_map do |(kind, body), i|
          [*('' unless i.zero?), *paragraph(kind, @screen.plain(body))]
        end
      end

      def paragraph(kind, body)
        case kind
        when :heading then @screen.wrap(body).map { |l| " #{WH}#{l}#{LG}" }
        when :pre then body.split("\n").flat_map { |l| l.strip.scan(/.{1,#{WIDTH}}/) }.map { |l| " #{GR}#{l}#{LG}" }
        else @screen.wrap(body.gsub(JargonEntryModel::LINK) { "#{CY}#{::Regexp.last_match(1)}#{LG}" }).map { |l| " #{l}" }
        end
      end

      def message(text)
        @screen.puts
        @screen.say(text, color: YE)
        @screen.pause
      end
    end
  end
end
