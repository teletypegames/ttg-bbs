# frozen_string_literal: true

require_relative 'wording'

module UI
  # The board on a Commodore 64: PETSCII on a 40×25 screen. A cursor main
  # menu, the games as numbered cursor lists, a game on a page of its own with
  # its actions on one row, the Wikipedia lead and the tips as pages that wait
  # for RETURN, and a line for a search and for a new tip.
  class Petscii < Rubbs::Petscii::Face
    LOGO_COLORS = [LB, LB, CY, CY, WH].freeze
    # The letters of the companies side by side, each with its count.
    LETTER_COLUMNS = 6

    title('COMMODEX BBS') { "#{catalog.count} games" }

    masthead do
      gap
      rule
      gap
      logo 'COMMODEX', colors: LOGO_COLORS, indent: 4
      gap
      rule
      line " #{Wording::TAGLINE.downcase}", color: WH
      line(color: GR) { " #{catalog.count} games, cheats and tips" }
      rule
    end

    main_menu do
      item('s', 'search titles', 'a part of a title finds the game') { search }
      item('y', 'browse by year', 'the games of one year') { groups('YEARS', catalog.years) { |y| catalog.in_year(y) } }
      item('g', 'browse by genre', 'shoot-em-ups, platformers, sports') do
        groups('GENRES', catalog.genres) { |genre| catalog.of_genre(genre) }
      end
      item('c', 'publishers & developers', 'the games of one company') { companies }
      item('r', 'random game', 'a game picked at random') { game(catalog.random) }
      item('t', 'games with tips', 'the games callers left tips for') do
        games('GAMES WITH TIPS', tips.games_with_tips, empty: 'no game has a tip yet. be the first!')
      end
      item('w', 'the wall', 'talk games with the other callers') { TTG::Wall.open(@session) }
      item('f', 'write to the sysops', 'a wrong game, a missing one, an idea') { TTG::Feedback.open(@session) }
      item('i', 'about commodex bbs', 'where the games come from') do
        page('ABOUT COMMODEX BBS', [Wording::ABOUT, '', Wording::SOURCES])
      end
      log_off
    end

    private

    def search
      title('SEARCH')
      say('Type a part of a game title, return alone goes back.', color: GR)
      puts
      query = ask(" #{WH}title?#{LG} ", max: 30)
      return if query.empty?

      found = catalog.search(query)
      return games("SEARCH: #{query.upcase}", found) if found.is_a?(Array) && found.any?

      alert(Wording.search(found, query))
    end

    # A list of [name, count] groups, then the games of the one picked.
    def groups(heading, list)
      each_pick(heading, list, right: list.size.to_s, label: ->((name, count)) { "#{name} #{GR}#{count}#{LG}" }) do |picked|
        games(picked.first.to_s.upcase, yield(picked.first))
      end
    end

    def companies
      letters = catalog.letters
      loop do
        title('PUBLISHERS & DEVELOPERS')
        say('The first letter of the name:')
        puts
        k = menu(
          letters.map { |l, count| Rubbs::Common::Screens::Selector.item(count.to_s, key: l, value: l) },
          columns: LETTER_COLUMNS,
          hint:    'crsr or letter, return  stop: back'
        )
        return unless k

        groups("COMPANIES: #{k.upcase}", catalog.companies(k)) { |name| catalog.of_company(name) }
      end
    end

    def games(heading, list, empty: 'no games here.')
      loop do
        picked = pick(heading, list, empty: empty, right: "#{list.size} games", &:label)
        return unless picked

        game(picked)
        return if list.size == 1
      end
    end

    def game(game)
      loop do
        count = tips.count(game)
        lines = [*wrap(game.title).map { |l| " #{WH}#{l}#{LG}" }, '',
                 *Wording.facts(game).map { |label, text| " #{CY}#{label.downcase}:#{LG} #{text}" },
                 " #{CY}tips:#{LG} #{Wording.tips(count)}"]
        page('GAME', lines, right: game.id, wait: false)
        case actions(%w[w wiki], %w[t tips], ['a', 'add a tip'], %w[q back])
        when 'w' then read_about(game)
        when 't' then show_tips(game, count)
        when 'a' then add_tip(game)
        when 'q' then return
        end
      end
    end

    def read_about(game)
      say('asking wikipedia…', color: GR)
      found = about.summary(game)
      if found.is_a?(Symbol)
        say(Wording.about(found), color: RD)
        return pause
      end

      page('ABOUT', [" #{WH}#{found.title}#{LG}", '', *found.paragraphs.flat_map { |p| [" #{p}", ''] },
                     " #{GR}#{SummaryModel::LICENSE.downcase}:#{LG}", " #{GR}#{found.url}#{LG}"])
    end

    def show_tips(game, count)
      lines = tips.tips(game).flat_map { |t| [" #{CY}#{t.author}#{GR} #{t.date}#{LG}", " #{t.text}", ''] }
      lines = [" #{GR}no tips yet. press a on the game page to add one.#{LG}"] if lines.empty?
      page("TIPS: #{game.title.upcase}", lines, right: Wording.tips(count))
    end

    def add_tip(game)
      return alert(Wording::TIP[:account]) unless signed_in?

      tip_heading(game)
      text = edit('', title: "YOUR TIP FOR #{game.title.upcase}", single_line: true, max: TipService::MAX_TEXT)
      title("A TIP: #{game.title.upcase}")
      return alert_nothing_sent if text.to_s.strip.empty?

      report(tips.submit(game, text: text, handle: identity.name.to_s, caller: caller_key), Wording::TIP)
    end

    def tip_heading(game)
      title("A TIP: #{game.title.upcase}")
      say(Wording::TIP_RULES, color: GR)
      say('An empty tip goes back.', color: GR)
      puts
    end

    def alert_nothing_sent
      say('Nothing sent.', color: GR)
      pause
    end
  end
end
