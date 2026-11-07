# frozen_string_literal: true

module TTG
  module Badges
    # The caller's badges on either face (a TTG::Screen), from the
    # Central (Rubbs::Common::Badges::Service +mine+): the earned ones with
    # their emblem and tier, then the ones on the way with how far the
    # caller is, a secret one as <tt>???</tt> until it is earned; and the
    # Hall of Badges, how many have each and who was first.
    class Screen
      # The badges on a screen: a C64 has fewer rows.
      PAGE = { modern: 9, petscii: 5 }.freeze

      # The badges of the caller on +session+.
      def initialize(session)
        @session = session
        @screen  = TTG::Screen.new(session)
        @page    = 0
      end

      # Runs until the caller goes back. Returns +nil+.
      def run
        loop do
          badges = mine or return nil
          show(badges)
          case @screen.menu(items(badges))
          when :next then @page += 1
          when :first then @page = 0
          when :hall then hall
          else return nil
          end
        end
      end

      private

      def proxy = Rubbs.central(Rubbs::Common::Badges::Service)

      def actor = Rubbs::Common::Central::Actor.of(@session)

      def mine
        badges = proxy.mine(actor)['badges']
        return badges if badges

        @screen.tell('The badges cannot be reached now. Please try again later.', :bad)
        nil
      end

      def size = PAGE.fetch(@screen.petscii? ? :petscii : :modern)

      def ordered(badges) = badges.sort_by { |b| [b['earned'].empty? ? 1 : 0, b['secret'] ? 1 : 0] }

      def show(badges)
        earned = badges.count { |b| b['earned'].any? }
        @screen.head('Badges', "#{earned} of #{badges.size} earned, on every board of the network.")
        ordered(badges).drop(@page * size).first(size).each { |badge| draw(badge) }
        @screen.blank
      end

      def draw(badge)
        if badge['earned'].empty? && badge['secret']
          @screen.line("#{emblem(badge)} ???", :meta)
          return @screen.paragraph('A secret badge.', :meta, indent: 2)
        end

        @screen.line("#{emblem(badge)} #{badge['title']}#{tiers(badge)}", badge['earned'].empty? ? :text : :good)
        @screen.paragraph("#{badge['hint']}#{progress(badge)}", :meta, indent: 2)
      end

      def emblem(badge)
        mark = badge['emblem'].to_s
        @screen.petscii? && @screen.plain(mark).include?('?') ? badge['title'].to_s[0] : mark
      end

      def tiers(badge)
        tiers = badge['earned'].reject(&:empty?)
        tiers.empty? ? '' : " (#{tiers.last})"
      end

      def progress(badge)
        goal = Array(badge['goals']).map(&:last).find { |g| g.to_i > badge['value'].to_i }
        return '' unless goal && badge['value'].to_i.positive?

        " #{badge['value'].to_i}/#{goal}"
      end

      def items(badges)
        items = []
        items << ['Next', :next] if (@page + 1) * size < badges.size
        items << ['First', :first] if @page.positive?
        items << ['Hall of Badges', :hall]
        items << ['Back', :back]
      end

      def hall
        badges = proxy.hall['badges'] or return @screen.tell('The hall cannot be reached now.', :bad)

        @screen.head('Hall of Badges', 'How many callers have each badge, and who was first.')
        badges.sort_by { |b| b['count'] }.first(@screen.petscii? ? 8 : 14).each do |b|
          @screen.line("#{emblem(b)} #{b['title']}: #{b['count']}, first #{b['first']}", :text)
        end
        @screen.blank
        @screen.pause
      end
    end
  end
end
