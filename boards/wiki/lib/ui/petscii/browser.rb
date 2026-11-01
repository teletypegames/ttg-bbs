# frozen_string_literal: true

module UI
  module Petscii
    # The wiki tree on the C64, one level per screen: the pages of a level
    # numbered, the ones with pages under them marked with >. A number opens
    # the page or goes down a level, where the first line is the page itself;
    # q goes back up. At the top S unlocks the private pages (marked *) and R
    # re-reads the index.
    class Browser
      PUBLIC_HOST = 'wiki.teletypegames.org'
      # The colours of a wiki page on the C64, in the keys of a BBS::Theme.
      MARKDOWN = { text: LG, text_bright: WH, accent: YE, label: CY, text_dim: GR }.freeze
      TOP = { 's' => 'login', 'r' => 'refresh' }.freeze

      def initialize(bbs, screen, ctx)
        @wiki       = bbs.wiki
        @supervisor = bbs.supervisor
        @screen     = screen
        @ctx        = ctx
      end

      def run
        level(nil)
      end

      private

      def unlocked? = @ctx[:unlocked] == true

      def locked?(page) = page.private? && !unlocked?

      # One level of the tree under +parent+ (nil: the top), until q.
      def level(parent)
        loop do
          children = tree[parent&.route] || []
          items    = parent ? [parent, *children] : children
          heading  = parent ? parent.title.upcase : 'TTG WIKI BBS'
          right    = parent ? '' : "#{'sv ' if unlocked?}#{@wiki.pages.size} pages "
          choice   = @screen.pick(heading, items, commands: parent ? {} : TOP, right: right) do |page|
            label(page, own: page.equal?(parent))
          end
          case choice
          when nil then return
          when 's' then supervisor_login
          when 'r' then refresh
          else
            next read(choice) if choice.equal?(parent) || (tree[choice.route] || []).empty?

            level(choice)
          end
        end
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
        pages = @wiki.pages
        return @tree if @tree_of.equal?(pages)

        routes   = pages.to_h { |p| [p.route, p] }
        @tree_of = pages
        @tree    = pages.group_by do |p|
          parts = p.route.split('/').reject(&:empty?)
          parts.pop
          parts.size.downto(1).map { |n| "/#{parts.first(n).join('/')}" }.find { |r| routes.key?(r) }
        end
      end

      def read(page)
        heading = page.title.upcase[0, 30]
        if locked?(page)
          @screen.title(heading)
          @screen.puts
          @screen.say('Supervisor only.', RD)
          @screen.say('This page is private. S on the top level unlocks it.', GR)
          @screen.pause
          return
        end
        @screen.title(heading)
        @screen.say('loading...', GR)
        md    = @wiki.page_markdown(page.route)
        lines = BBS::Markdown.to_lines(md, width: WIDTH, theme: MARKDOWN).map { |l| " #{l}" }
        @screen.page(heading, lines + ['', " #{GR}updated #{page.updated_at}#{LG}",
                                       " #{CY}#{PUBLIC_HOST}#{page.route}#{LG}"], numbers: true)
      end

      def supervisor_login
        @screen.title('SUPERVISOR')
        @screen.puts
        if unlocked?
          @ctx[:unlocked] = false if @screen.choose(" #{WH}supervisor access is on. lock it? (y/n)#{LG} ", %w[y n]) == 'y'
          return
        end
        if !@supervisor.configured?
          @screen.say('No supervisor password configured.', RD)
        elsif @supervisor.unlock(@screen.ask(" #{WH}password#{LG}: ", mask: '*')) == :granted
          @ctx[:unlocked] = true
          @screen.say('Supervisor access granted.', GN)
        else
          sleep 2
          @screen.say('Wrong password.', RD)
        end
        @screen.pause
      end

      # Re-reads the shared index: every session sees the new one.
      def refresh
        @screen.title('TTG WIKI BBS')
        @screen.say('refreshing the index...', GR)
        @wiki.clear_cache
        @wiki.refresh_index!
      rescue StandardError
        @screen.say('Could not reach the wiki.', RD)
        @screen.pause
      end
    end
  end
end
