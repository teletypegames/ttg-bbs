# frozen_string_literal: true

require_relative 'card'

module UI
  # The library on a Commodore 64: PETSCII on a 40×25 screen, a cursor menu,
  # the series, their seasons and episodes as numbered lists, an episode's
  # card a page, and Memory Alpha's articles section by section.
  class Petscii < BBS::Petscii::Face
    LOGO_COLORS = [WH, LB, LB, CY, BL].freeze
    LOGO_INDENT = [(COLS - BBS::BlockFont.width('STARBASE')) / 2, 0].max
    STARS       = "#{DG}  .    *        .     +     .     *   .#{LG}".freeze
    NO_ANSWER   = 'Memory Alpha did not answer. Try again later.'
    QR_COMMAND  = { 'c' => 'qr code' }.freeze

    title('STARBASE BBS') { "#{catalog.size} episodes " }

    masthead do
      gap
      art STARS
      gap
      logo 'STARBASE', colors: LOGO_COLORS, indent: LOGO_INDENT
      gap
      art STARS
      gap
      line ' a star trek library on your commodore', color: WH
    end

    main_menu do
      item('s', 'series and films', -> { "#{catalog.series.size} to browse" }) { series_list }
      item('t', 'on this day', 'first aired on this day') { today }
      item('l', 'library computer', 'search memory alpha') { search }
      item('r', 'random article', 'wherever the archive takes you') { random }
      log_off 'hang up. live long and prosper!'
    end

    private

    def episodes_right = "#{catalog.size} episodes "

    def series_list
      each_pick('SERIES AND FILMS', catalog.series, right: episodes_right,
                                                    label: ->(s) { "#{s.short_title} #{GR}#{s.years}#{LG}" }) do |series|
        seasons(series)
      end
    end

    def seasons(series)
      list = catalog.seasons(series)
      return episodes(series, list.first.last) if list.size == 1

      each_pick(heading_of(series), list, label: ->((n, e)) { "season #{n || '?'} #{GR}(#{e.size})#{LG}" }) do |picked|
        episodes(series, picked.last)
      end
    end

    def episodes(series, list)
      each_pick(heading_of(series), list, label: :label) { |episode| card(episode, series) }
    end

    def today
      each_pick("ON #{Date.today.strftime('%B %-d').upcase}", catalog.on_this_day(Date.today),
                empty: 'nothing first aired on this day.',
                label: ->((e, s)) { "#{e.year} #{s.abbreviation.downcase} #{e.title}" }) do |episode, series|
        card(episode, series)
      end
    end

    def heading_of(series) = series.short_title.upcase[0, 30]

    # An episode's card; R reads its article.
    def card(episode, series)
      lines = [" #{WH}#{episode.title}#{LG}", '', *Card.episode(episode, series).flat_map { |k, v| row(k, v) }]
      page(heading_of(series), lines, wait: false, room: 2)
      read_episode(episode) if actions(%w[r read], %w[q back]) == 'r'
    rescue BBS::Abort
      nil
    end

    def row(key, value)
      [" #{GR}#{key.downcase}#{LG}", *wrap(value.to_s, WIDTH - 2).map { |l| "   #{l}" }]
    end

    # The library computer: a title opens its article, other words the
    # search results.
    def search
      title('LIBRARY COMPUTER')
      puts
      say('A title opens its article, any other words the search results. Return alone: back.', color: GR)
      puts
      query = prompt('search', max: 80)
      look_up(query) if query
    end

    def look_up(query)
      article, results = loading('accessing…') { library.look_up(query) }
      return show_article(article) if article
      fail_with(NO_ANSWER) if results.nil?
      fail_with("Nothing found for \"#{query}\".") if results.empty?

      each_pick("SEARCH: #{query.upcase}"[0, 30], results, label: :title) { |hit| read(hit.title) }
    end

    def random = read(library.random || fail_with(NO_ANSWER))

    def read(title) = show_article(library.article(title) || not_found(title))

    def read_episode(episode) = show_article(library.article_of(episode) || not_found(episode.title))

    def not_found(title) = fail_with("Memory Alpha has no article \"#{title}\", or did not answer.")

    # The article: its contents when it has sections, else its one page; C
    # shows its QR code.
    def show_article(article)
      heading = article.title.upcase[0, 30]
      if article.sections.size == 1
        section(article, article.sections.first, heading, wait: false)
        show_qr(article) if actions(['c', 'qr code'], %w[q back]) == 'c'
      else
        each_pick(heading, article.sections, label: :title, commands: QR_COMMAND) do |picked|
          picked == 'c' ? show_qr(article) : section(article, picked, heading)
        end
      end
    end

    def section(article, section, heading, wait: true)
      lines = markdown(section.markdown)
      if section == article.sections.first
        lines.unshift(" #{GR}(redirected from #{article.redirected_from})#{LG}", '') if article.redirected_from
        lines += ['', " #{GR}memory alpha, under cc by-nc:#{LG}", *article.url.scan(/.{1,37}/).map { |w| " #{CY}#{w}#{LG}" }]
      else
        lines.unshift(" #{WH}#{section.title}#{LG}", '')
      end
      page(heading, lines, wait: wait, room: 2)
    end

    def show_qr(article)
      title('SCAN THE ARTICLE')
      pause if qr(article.short_url)
    end
  end
end
