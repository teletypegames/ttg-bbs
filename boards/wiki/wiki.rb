# frozen_string_literal: true

require 'bundler/setup'
require 'bbs'
require_relative 'lib/wiki/client'

# WIKI-BBS — the Teletype Games wiki over telnet. Callers get a Norton
# Commander-style two-pane browser: page tree on the left, the page rendered
# as ANSI markdown on the right. Content comes live from the Grav wiki's
# /api/sitemap.json and /api/page.json endpoints.
# Pages flagged private on the wiki (access: site.login) stay locked until the
# caller unlocks the session with this password (Wiki menu > Supervisor login).
# The wiki holds the same secret and only serves private page bodies to
# requests carrying it as ?token= — so the lock is enforced server-side too.
SUPERVISOR_PASSWORD = ENV['SUPERVISOR_PASSWORD'].to_s

WIKI = Wiki::Client.new(base_url: ENV['WIKI_URL'] || 'http://localhost:9120',
                        token: SUPERVISOR_PASSWORD)

MAIN = BBS::Application.define do
  theme BBS::Theme.nortoncommander

  services wiki: WIKI

  helpers do
    def unlocked?
      context[:unlocked] == true
    end

    def supervisor_login
      if unlocked?
        BBS::Dialogs.confirm(self, 'Supervisor access is active. Lock it again?',
                             on_yes: -> { context[:unlocked] = false })
      else
        open_window(:supervisor_login)
      end
    end

    def open_browser
      if services[:wiki].pages.empty?
        BBS::Dialogs.message(self, 'The wiki index is empty. Try Wiki > Refresh index.',
                             title: ' Wiki ')
      else
        open_window(:browser)
      end
    end

    # Re-reads the shared index (every session sees the new one) and reopens
    # the browser so the list reflects it.
    def refresh_pages
      ok = with_loading('Refreshing wiki index...') do
        services[:wiki].clear_cache
        services[:wiki].refresh_index!
        true
      rescue StandardError
        false
      end
      if ok
        close_window while top_window
        open_browser
      else
        BBS::Dialogs.message(self, 'Could not reach the wiki.', title: ' Error ')
      end
    end

    def show_about
      BBS::Windows::Info.open(self,
        title: ' About ',
        width: 56,
        body: [
          { text: 'WIKI-BBS', style: :accent, align: :center },
          { text: 'The Teletype Games wiki over telnet', align: :center },
          :spacer,
          :rule,
          { kv: [['Source', services[:wiki].base_url],
                 ['Pages',  services[:wiki].pages.size.to_s],
                 ['Engine', 'rubbs / Grav']] }
        ])
    end
  end

  init do
    open_browser
  end

  menubar do
    menu '&Wiki' do
      item '&Supervisor login...' do supervisor_login end
      separator
      item '&Browse pages', shortcut: 'F2' do open_browser end
      item '&Refresh index', shortcut: 'F5' do refresh_pages end
      separator
      item 'E&xit', shortcut: 'Alt-X' do :halt end
    end
    menu '&Help' do
      item '&Keys' do
        BBS::Dialogs.message(self,
          'Up/Down: pick page - Tab: focus reader - PgUp/PgDn: scroll - * = supervisor only',
          title: ' Keys ', width: 76)
      end
      item '&About' do show_about end
    end
  end

  status_hint('F2',  'Browse')  { open_browser }
  status_hint('F5',  'Refresh') { refresh_pages }
  status_hint('F10', 'Menu')    { menubar.open(0) }
  status_hint('Alt-X', 'Quit')  { :halt }

  window :browser, type: :master_detail do |w|
    w.title ' Teletype Games Wiki '
    w.list_width 32
    w.empty_message '  (no pages)'
    w.items { |ctx| ctx[:wiki].pages }
    w.item_label do |page, ctx|
      lock = page[:private] && !ctx[:app].unlocked? ? ' *' : ''
      "#{'  ' * (page[:depth] - 1)}#{page[:title]}#{lock}"
    end
    w.render_detail do |page, width, ctx|
      md = if page[:private] && !ctx[:app].unlocked?
             "# Supervisor only\n\nThis page is private. " \
             "Unlock it via **Wiki > Supervisor login**."
           else
             ctx[:wiki].page_markdown(page[:route])
           end
      BBS::Markdown.to_lines(md, width: width, theme: ctx[:app].theme)
    end
    w.bottom_meta do |page, ctx|
      if page[:private] && !ctx[:app].unlocked?
        " #{page[:route]}   SUPERVISOR ONLY"
      else
        " #{page[:route]}   updated #{page[:updated_at]}"
      end
    end
  end

  window :supervisor_login, type: :form do |w|
    w.title ' Supervisor login '
    w.width 46
    w.hint 'Enter the supervisor password:'
    w.field :password, label: 'Password', password: true
    w.submit_label '&Unlock'
    w.on_submit do |values, form, ctx|
      app = ctx[:app]
      if SUPERVISOR_PASSWORD.empty?
        form.error('No supervisor password configured.')
        :keep
      elsif values[:password] == SUPERVISOR_PASSWORD
        app.context[:unlocked] = true
        app.windows.grep(BBS::Windows::MasterDetail).each(&:reload_detail)
        BBS::Dialogs.message(app, 'Supervisor access granted.', title: ' Unlocked ')
        :close
      else
        form.error('Wrong password.')
        :keep
      end
    end
  end
end

# Load the page index once at boot; sessions share it. If the wiki is down,
# start anyway — callers can pull it in later with Wiki > Refresh index.
begin
  WIKI.refresh_index!
  puts "wiki-bbs: indexed #{WIKI.pages.size} pages from #{WIKI.base_url}"
rescue StandardError => e
  warn "wiki-bbs: could not load wiki index at boot " \
       "(#{e.class}: #{e.message}) — use Wiki > Refresh index"
end

BBS.configure do |config|
  config.port         = (ENV['BBS_PORT'] || 2323).to_i
  config.mouse        = true
  config.idle_seconds = (ENV['BBS_IDLE'] || 900).to_i

  config.flow = BBS::Flow.define do
    big_banner 'TTG WIKI', style: :success
    text(style: :muted) { "Teletype Games wiki over telnet — #{WIKI.pages.size} pages indexed." }

    app MAIN

    say 'NO CARRIER', style: :muted
  end
end

BBS.start
