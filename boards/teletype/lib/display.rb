# frozen_string_literal: true

require 'time'

module Display
  W = 70

  RESET   = "\e[0m"
  BOLD    = "\e[1m"
  CYAN    = "\e[0;36m"
  YELLOW  = "\e[0;33m"
  GREEN   = "\e[1;32m"
  RED     = "\e[1;31m"
  MAGENTA = "\e[0;35m"
  WHITE   = "\e[1;37m"
  BLUE    = "\e[0;34m"
  GRAY    = "\e[0;37m"

  module_function

  def hr(color = GRAY)
    "  #{color}#{'─' * (W - 4)}#{RESET}\r\n"
  end

  def box_header(title, color = CYAN)
    pad = [W - title.length - 6, 2].max
    "  #{color}┌─ #{WHITE}#{title} #{color}#{'─' * pad}┐#{RESET}\r\n"
  end

  def strip_md(text)
    text.gsub(/\[([^\]]+)\]\([^)]+\)/, '\1')
        .gsub(/[#*_`~>|\\]/, '')
        .gsub(/\r?\n+/, ' ')
        .strip
  end

  def wrap(text, indent: 4, width: W - 6)
    words = strip_md(text).split
    lines = []
    line  = +''
    words.each do |word|
      if line.empty?
        line << word
      elsif line.length + 1 + word.length <= width
        line << ' ' << word
      else
        lines << line.dup
        line = +word
      end
    end
    lines << line unless line.empty?
    lines.map { |l| "#{' ' * indent}#{l}\r\n" }.join
  end

  def fmt_date(iso)
    Time.parse(iso).strftime('%Y-%m-%d')
  rescue
    iso.to_s
  end

  def wait_enter(runner)
    runner.write "\r\n  #{GRAY}Press ENTER to continue...#{RESET}"
    runner.readline
  end

  def render_messages(messages, runner)
    runner.write "\r\n"
    runner.write box_header('Message Board')
    runner.write "\r\n"
    if messages.empty?
      runner.write "  #{GRAY}No messages yet.#{RESET}\r\n"
    else
      messages.each_with_index do |msg, i|
        runner.write "  #{GRAY}[#{i + 1}]#{RESET} #{YELLOW}#{msg.timestamp}#{RESET} #{WHITE}#{msg.username}#{RESET}: #{GRAY}#{msg.text}#{RESET}\r\n"
      end
    end
    runner.write "\r\n"
    wait_enter(runner)
  end

  def render_wiki_list(wiki, tag, title, color, runner)
    runner.write "\r\n"
    runner.write box_header(title, color)
    runner.write "\r\n  #{GRAY}Loading...#{RESET}\r\n"

    pages = wiki.list(tag)
    runner.write "\e[1A\e[2K"

    if pages.empty?
      runner.write "  #{RED}No results.#{RESET}\r\n\r\n"
      wait_enter(runner)
      return
    end

    shown = pages.first(25)
    shown.each_with_index do |page, i|
      runner.write "  #{GRAY}#{i + 1}.#{RESET} #{color}#{page['title']}#{RESET} #{GRAY}#{fmt_date(page['createdAt'])}#{RESET}\r\n"
      desc = page['description'].to_s.strip
      runner.write "     #{GRAY}#{desc[0...65]}#{RESET}\r\n" unless desc.empty?
    end

    runner.write "\r\n  #{GRAY}Enter number to read (blank to go back):#{RESET} "
    input = runner.readline&.strip
    return if input.nil? || input.empty?

    idx  = input.to_i - 1
    page = shown[idx]
    unless page
      runner.write "\r\n  #{RED}Invalid selection.#{RESET}\r\n"
      wait_enter(runner)
      return
    end

    runner.write "\r\n  #{GRAY}Loading page...#{RESET}\r\n"
    body = wiki.content(page['id'])
    runner.write "\e[1A\e[2K"

    runner.write "\r\n"
    runner.write hr(color)
    runner.write "  #{color}#{page['title']}#{RESET}\r\n"
    runner.write "  #{GRAY}#{fmt_date(page['createdAt'])}  #{wiki.page_url(page['locale'], page['path'])}#{RESET}\r\n"
    runner.write hr(color)
    runner.write "\r\n"
    runner.write wrap(body)
    runner.write "\r\n"
    wait_enter(runner)
  end

  def render_catalog(catalog, runner)
    runner.write "\r\n"
    runner.write box_header('Game Catalog', CYAN)
    runner.write "\r\n  #{GRAY}Loading...#{RESET}\r\n"

    games = catalog.fetch
    runner.write "\e[1A\e[2K"

    unless games.is_a?(Array) && !games.empty?
      runner.write "  #{RED}Could not load catalog.#{RESET}\r\n\r\n"
      wait_enter(runner)
      return
    end

    games.each_with_index do |entry, i|
      next unless entry.is_a?(Hash)
      sw      = entry['software']      || {}
      latest  = entry['latestRelease'] || {}
      count   = (entry['releases'] || []).length

      runner.write "\r\n"
      runner.write hr
      runner.write "  #{CYAN}#{i + 1}. #{sw['title']}#{RESET}  #{GRAY}#{sw['platform']}  #{sw['author']}#{RESET}\r\n"
      runner.write wrap(sw['desc'].to_s) unless sw['desc'].to_s.strip.empty?

      badges = []
      badges << "#{GREEN}[▶ Play]#{RESET}"       if latest['htmlFolderPath'].to_s  != ''
      badges << "#{YELLOW}[⬇ Download]#{RESET}"  if latest['cartridgePath'].to_s   != ''
      badges << "#{BLUE}[Source]#{RESET}"        if latest['sourcePath'].to_s      != ''
      badges << "#{MAGENTA}[Docs]#{RESET}"       if latest['docsFolderPath'].to_s  != ''
      runner.write "  #{badges.join('  ')}\r\n" unless badges.empty?

      if latest['htmlFolderPath'].to_s != ''
        runner.write "  #{GRAY}#{catalog.play_url(latest['htmlFolderPath'])}#{RESET}\r\n"
      end
      runner.write "  #{GRAY}#{count} versions available#{RESET}\r\n" if count > 1
    end

    runner.write "\r\n"
    runner.write hr
    runner.write "  #{GRAY}#{CatalogClient::GAMES_URL}#{RESET}\r\n\r\n"
    wait_enter(runner)
  end

  def render_online(online, my_sid, my_name, runner)
    runner.write "\r\n"
    runner.write box_header('Online Users', YELLOW)
    runner.write "\r\n"

    snapshot = online.snapshot
    snapshot.sort.each do |sid, name|
      marker = sid == my_sid ? "  #{GRAY}← you#{RESET}" : ''
      runner.write "  #{WHITE}#{name}#{RESET}#{marker}\r\n"
    end

    runner.write "\r\n  #{GRAY}#{snapshot.size} user(s) online#{RESET}\r\n\r\n"
    wait_enter(runner)
  end

  def render_sysinfo(online, messages, runner)
    runner.write "\r\n"
    runner.write box_header('System Info', MAGENTA)
    runner.write "\r\n"
    runner.write "  #{GRAY}Online users   #{WHITE}#{online.count}#{RESET}\r\n"
    runner.write "  #{GRAY}Messages       #{WHITE}#{messages.count}#{RESET}\r\n"
    runner.write "  #{GRAY}Wiki           #{WHITE}https://wiki.teletype.hu#{RESET}\r\n"
    runner.write "  #{GRAY}Games API      #{WHITE}https://games.teletype.hu#{RESET}\r\n"
    runner.write "  #{GRAY}Platform       #{WHITE}#{RUBY_PLATFORM}#{RESET}\r\n"
    runner.write "  #{GRAY}Ruby           #{WHITE}#{RUBY_VERSION}#{RESET}\r\n"
    runner.write "\r\n"
    wait_enter(runner)
  end
end
