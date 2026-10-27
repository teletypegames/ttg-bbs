# frozen_string_literal: true

module UI
  # The wiki on an ANSI terminal: a Norton Commander-style two-pane browser
  # that fills the screen between the menubar and the statusbar — page tree
  # on the left (indented by route depth), the selected page rendered as
  # ANSI markdown on the right. F5 / Alt-Enter (the window's zoom) puts it
  # back into a window and out again.
  module Modern
    def self.flow(wiki)
      browser = app(wiki)
      BBS::Flow.define do
        big_banner 'TTG WIKI', style: :success
        text(style: :muted) { "Teletype Games wiki over telnet — #{wiki.pages.size} pages indexed." }

        app browser

        say 'NO CARRIER', style: :muted
      end
    end

    def self.app(wiki)
      BBS::Application.define do
        theme BBS::Theme.nortoncommander

        services wiki: wiki

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

          # The browser opens maximized: as much of the page as the screen holds.
          def open_browser
            if services[:wiki].pages.empty?
              BBS::Dialogs.message(self, 'The wiki index is empty. Try Wiki > Refresh index.',
                                   title: ' Wiki ')
            else
              browser = open_window(:browser)
              browser.toggle_maximize unless browser.maximized?
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
            item '&Refresh index', shortcut: 'F8' do refresh_pages end
            separator
            item 'E&xit', shortcut: 'Alt-X' do :halt end
          end
          menu '&Help' do
            item '&Keys' do
              BBS::Dialogs.message(self,
                'Up/Down: pick page - Tab: focus reader - PgUp/PgDn: scroll - ' \
                'F5: window/full screen - * = supervisor only',
                title: ' Keys ', width: 76)
            end
            item '&About' do show_about end
          end
        end

        status_hint('F2',  'Browse')  { open_browser }
        status_hint('F8',  'Refresh') { refresh_pages }
        status_hint('F10', 'Menu')    { menubar.open(0) }
        status_hint('Alt-X', 'Quit')  { :halt }

        window :browser, type: :master_detail do |w|
          w.title ' Teletype Games Wiki '
          w.maximizable true
          w.close_button false
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
    end
  end
end
