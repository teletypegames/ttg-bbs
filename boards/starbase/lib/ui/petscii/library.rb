# frozen_string_literal: true

module UI
  module Petscii
    # One call: the menu, the series, a series' seasons and episodes, the
    # episodes aired on this day, an episode's card; the articles go to the
    # Reader.
    class Library
      def initialize(catalog, library, screen)
        @catalog = catalog
        @screen  = screen
        @reader  = Reader.new(library, screen)
      end

      def run
        @screen.cls
        Petscii.masthead.each { |l| @screen.puts l }
        loop do
          @screen.puts
          @choice = @screen.menu(menu_items, index: menu_items.index { |i| i.value == @choice }, back: 'q',
                                             hint: 'crsr: choose  return: take')
          return if @choice == 'q'

          take(@choice)
          @screen.title('STARBASE BBS', right)
        end
      end

      private

      def right = "#{@catalog.size} episodes "

      def menu_items
        @menu_items ||= [
          BBS::Selector.item('series and films', key: 's', value: 's', about: "#{@catalog.series.size} to browse"),
          BBS::Selector.item('on this day', key: 't', value: 't', about: 'first aired on this day'),
          BBS::Selector.item('library computer', key: 'l', value: 'l', about: 'search memory alpha'),
          BBS::Selector.item('random article', key: 'r', value: 'r', about: 'wherever the archive takes you'),
          BBS::Selector.item('log off', key: 'q', value: 'q', about: 'hang up. live long and prosper!')
        ]
      end

      def take(choice)
        case choice
        when 's' then series_list
        when 't' then today
        when 'l' then @reader.search
        when 'r' then @reader.random
        end
      rescue Reader::Failed => e
        @screen.puts
        @screen.say(e.message, color: RD)
        @screen.pause
      end

      def series_list
        loop do
          series = @screen.pick('SERIES AND FILMS', @catalog.series, right: right) { |s| "#{s.short_title} #{GR}#{s.years}#{LG}" }
          break unless series

          seasons(series)
        end
      end

      def seasons(series)
        list = @catalog.seasons(series)
        return episodes(series, list.first.last) if list.size == 1

        loop do
          picked = @screen.pick(series.short_title.upcase[0, 30], list) { |n, e| "season #{n || '?'} #{GR}(#{e.size})#{LG}" }
          break unless picked

          episodes(series, picked.last)
        end
      end

      def episodes(series, list)
        loop do
          episode = @screen.pick(series.short_title.upcase[0, 30], list, &:label)
          break unless episode

          card(episode, series)
        end
      end

      def today
        entries = @catalog.on_this_day(Date.today)
        heading = "ON #{Date.today.strftime('%B %-d').upcase}"
        loop do
          episode, series = @screen.pick(heading, entries, empty: 'nothing first aired on this day.') do |e, s|
            "#{e.year} #{s.abbreviation.downcase} #{e.title}"
          end
          break unless episode

          card(episode, series)
        end
      end

      # An episode's card; R reads its article.
      def card(episode, series)
        lines = [" #{WH}#{episode.title}#{LG}", '', *Card.episode(episode, series).flat_map { |k, v| row(k, v) }]
        @screen.page(series.short_title.upcase[0, 30], lines, wait: false, room: 2)
        @reader.read_episode(episode) if @screen.actions(%w[r read], %w[q back]) == 'r'
      rescue Reader::Failed => e
        @screen.puts
        @screen.say(e.message, color: RD)
        @screen.pause
      end

      def row(key, value)
        [" #{GR}#{key.downcase}#{LG}", *@screen.wrap(value.to_s, WIDTH - 2).map { |l| "   #{l}" }]
      end
    end
  end
end
