# frozen_string_literal: true

require_relative 'wording'

module UI
  # The wiki on a Commodore 64: PETSCII on a 40×25 screen, one level of the
  # page tree per screen as a numbered cursor list, the ones with pages
  # under them marked with >. A number opens the page or goes down a level,
  # where the first line is the page itself; q goes back up. At the top S
  # unlocks the private pages (marked *) and R re-reads the index. A page
  # comes in screenfuls that wait for RETURN.
  class Petscii < Rubbs::Petscii::Face
    include Wording

    LOGO_COLORS = [CY, CY, LB, LB, BL].freeze

    title('TTG WIKI BBS') { right }

    masthead do
      gap
      logo 'TTG WIKI', colors: LOGO_COLORS, glyphs: Rubbs::Common::Text::BlockFont::WIDE_W
      gap
      line(color: WH) { " ttg wiki bbs#{LG}, the c64 side" }
      line(color: GR) { " #{wiki.pages.size} pages indexed" }
      gap
    end

    def run
      show_masthead
      say('CRSR and RETURN, or the number, opens a page; Q goes back. Pages marked * are private.', color: GR)
      pause('return: enter the wiki')
      level(nil)
    end

    private

    # One level of the tree under +parent+ (nil: the top), until q.
    def level(parent)
      loop do
        case (choice = pick_on(parent))
        when nil then return
        when 'p' then own_profile
        when 'r' then refresh
        else enter(choice, parent)
        end
      rescue Rubbs::Common::Line::Abort
        next
      end
    end

    # The page picked on the level of +parent+, a top-level command, or nil.
    def pick_on(parent)
      return pick('TTG WIKI BBS', tree[nil] || [], commands: top, right: right) { |page| label(page) } unless parent

      pick(parent.title.upcase, [parent, *tree[parent.route]]) { |page| label(page, own: page.equal?(parent)) }
    end

    # The commands of the top level: the profile and the refresh.
    def top = { 'p' => 'profile', 'r' => 'refresh' }

    def right = "#{'sv ' if supervisor?}#{wiki.pages.size} pages "

    # Reads +page+, or goes down to its level when it has pages under it.
    def enter(page, parent)
      page.equal?(parent) || (tree[page.route] || []).empty? ? read(page) : level(page)
    end

    def label(page, own: false)
      mark = if own then " #{DG}(this page)"
             elsif tree.key?(page.route) then " #{CY}>"
             else ''
             end
      lock = locked?(page) ? " #{RD}*" : ''
      "#{own ? WH : LG}#{page.title}#{mark}#{lock}#{LG}"
    end

    # Route of the parent → its pages, each page under its nearest ancestor
    # in the index; the top level (and the home page, /) under nil. Built
    # again when the index changes.
    def tree
      pages = wiki.pages
      return @tree if @tree_of.equal?(pages)

      routes   = pages.to_h { |p| [p.route, p] }
      @tree_of = pages
      @tree    = pages.group_by do |p|
        parts = p.route.split('/').reject(&:empty?)
        parts.pop
        parts.size.downto(1).map { |n| "/#{parts.first(n).join('/')}" }.find { |r| routes.key?(r) }
      end
    end

    def read(wiki_page)
      heading = wiki_page.title.upcase[0, 30]
      title(heading)
      fail_with(locked_text('P on the top level: the profile, to log in.')) if locked?(wiki_page)

      lines = markdown(loading('loading...') { wiki.page_markdown(wiki_page) })
      page(
        heading,
        [*lines, '', " #{GR}updated #{wiki_page.updated_at}#{LG}", " #{CY}#{PUBLIC_HOST}#{wiki_page.route}#{LG}"],
        numbers: true,
        wait:    false,
        room:    2
      )
      show_qr(wiki_page) if actions(['c', 'qr code'], %w[q back]) == 'c'
    end

    # The page's address as a QR code in the middle of the screen, for a
    # phone to open it on the web.
    def show_qr(wiki_page)
      title('SCAN THE PAGE', right)
      pause if qr(wiki_page.public_url)
    end

    # The caller's profile (Rubbs::Common::Auth::Profile: log in, a new account, the
    # password, log out); an account without the wiki-supervisor role is
    # told the private pages stay locked.
    def own_profile
      open_profile
      alert(not_supervisor(identity.name)) if signed_in? && !supervisor?
    end

    # Re-reads the shared index: every session sees the new one.
    def refresh
      home
      report(loading('refreshing the index...') { wiki.refresh(caller_key) }, REFRESH)
    end
  end
end
