# frozen_string_literal: true

module UI
  # The board on a Commodore 64: PETSCII on a 40×25 screen. A title typed at
  # the prompt is looked up, the results come as a numbered list, and an
  # article as its contents, each section paged a screenful at a time.
  class Petscii < BBS::Petscii::Face
    LOGO_COLORS = [CY, CY, LB, LB, BL].freeze
    LANGUAGES   = { 'en' => 'english', 'hu' => 'magyar', 'de' => 'deutsch' }.freeze
    NO_ANSWER   = 'Wikipedia did not answer. Try again later.'
    QR_COMMAND  = { 'c' => 'qr code' }.freeze
    TOWER       = ['▄▀▄', '▐*▌', '▄███▄', '▐█▀█▌', '▄█████▄', '▄██▀▀▀██▄'].freeze
    WAVES       = '▄▀▀▄▄▄▀▄▄▀▀▀▄▄▀▄'

    # The Pharos of Alexandria by the sea, its light thrown both ways.
    PHAROS = TOWER.each_with_index.map do |t, i|
      next "#{YE}#{'░░░▒▒▒▒▓▓▓▓████'.rjust(19)}#{LG}▐#{WH}*#{LG}▌#{YE}████▓▓▓▓▒▒▒▒░░░#{LG}" if i == 1

      "  #{LG}#{t.center(37).rstrip}"
    end.push("#{BL}#{(WAVES * 3)[0, 39]}#{LG}").freeze

    title('ALEXANDRIA BBS') { "#{lang}.wikipedia " }

    masthead do
      gap
      art PHAROS
      gap
      logo 'ALEXANDRIA', colors: LOGO_COLORS, glyphs: BBS::BlockFont::NARROW_I
      gap
      line 'wikipedia on your commodore', color: WH
    end

    main_menu back: 's' do
      item 's', 'search a title', 'back to the prompt'
      item('r', 'random article', 'wherever the wiki takes you') { read(articles.random(lang: lang)) }
      item('l', -> { "language: #{WH}#{language_name}#{LG}" }, 'the next wikipedia') { next_language }
      log_off 'hang up. see you!'
    end

    # The prompt, again and again; return alone brings the menu.
    def run
      context[:lang] ||= articles.languages.first
      show_masthead
      loop do
        query = ask_title
        next look_up(query) if query
        break if main_menu_choice == :log_off
      rescue BBS::Abort
        home
      end
    end

    private

    def lang = context[:lang]

    def language_name = LANGUAGES.fetch(lang, lang)

    def next_language = context[:lang] = articles.next_language(lang)

    def ask_title
      puts
      say('type a title and return.', color: GR)
      prompt(language_name, hint: 'return alone: menu', max: 80)
    end

    def look_up(query)
      article, results = loading('searching…') { articles.look_up(query, lang: lang) }
      return show(article) if article

      fail_with(NO_ANSWER) if results.nil?
      fail_with("Nothing found for \"#{query}\".") if results.empty?

      each_pick("SEARCH: #{query.upcase}"[0, 30], results, right: lang, label: :title) { |r| read(r.title) }
      home
    end

    def read(title)
      fail_with(NO_ANSWER) unless title
      show(loading('loading…', failed: "Wikipedia has no article \"#{title}\", or did not answer.") do
        articles.article(title, lang: lang)
      end)
    end

    # The article: its contents when it has sections, else its one page; C
    # shows its QR code.
    def show(article)
      heading = article.title.upcase[0, 30]
      if article.sections.size == 1
        section(article, article.sections.first, heading, wait: false)
        show_qr(article) if actions(['c', 'qr code'], %w[q back]) == 'c'
      else
        each_pick(heading, article.sections, right: lang, label: :title, commands: QR_COMMAND) do |picked|
          picked == 'c' ? show_qr(article) : section(article, picked, heading)
        end
      end
      home
    end

    def show_qr(article)
      title('SCAN THE ARTICLE', lang)
      pause if qr(article.short_url)
    end

    def section(article, section, heading, wait: true)
      lines = markdown(section.markdown)
      if section == article.sections.first
        lines.unshift(" #{GR}(redirected from #{article.redirected_from})#{LG}", '') if article.redirected_from
        lines += ['', " #{GR}source, under cc by-sa:#{LG}", *article.url.scan(/.{1,37}/).map { |w| " #{CY}#{w}#{LG}" }]
      else
        lines.unshift(" #{WH}#{section.title}#{LG}", '')
      end
      page(heading, lines, right: lang, wait: wait, room: 2)
    end
  end
end
