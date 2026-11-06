# frozen_string_literal: true

module UI
  module Modern
    # The post office from the street, the desktop of the modern face: the art of
    # lib/content/art/post_office.yml as a rubbs Scene, its hotspots filled from the caller's
    # desk (a DeskModel the application gives): the clock in the sign, the caller's name over the
    # door, the pillar box's flag up and its count for new letters, a pigeon flying a letter
    # across the sky a step a second, and the street's line.
    class PostOffice < Rubbs::Modern::Widgets::Scene
      ART = Rubbs::Common::Art.load(File.expand_path('../../content/art/post_office.yml', __dir__))
      # The pigeon and its letter, a frame a step.
      PIGEON = ["\e[38;5;252m\\v/\e[38;5;231m✉", "\e[38;5;252m-v-\e[38;5;231m✉"].freeze
      FLAG   = "\e[38;5;220;48;5;17m▄▀▀\n\e[38;5;220;48;5;17m▌  "
      STREET = "\e[38;5;245;48;5;236m"

      # The scene; +desk+ gives the caller's DeskModel, +name+ their name (nil for a guest).
      def initialize(desk:, name:)
        super(art: ART, align: :center, valign: :top)
        @desk  = desk
        @name  = name
        @ticks = 0
        fills
      end

      # One step of the pigeon, a second.
      def tick = @ticks += 1

      private

      def fills
        fill(:sky)    { |spot| pigeon(spot) }
        fill(:clock)  { |spot| "\e[38;5;220;48;5;52m#{Time.now.strftime('%H:%M').center(spot.width)}" }
        fill(:caller) { |spot| "\e[38;5;223;48;5;58m#{welcome.center(spot.width)[0, spot.width]}" }
        fill(:flag)   { FLAG if unread.positive? }
        fill(:count)  { |spot| count(spot) }
        fill(:status) { |spot| "#{STREET}#{street.ljust(spot.width)[0, spot.width]}" }
      end

      def desk = @desk.call

      def unread = desk.summary.unread

      def welcome = @name.call ? "Welcome, #{@name.call}" : 'Welcome, guest'

      def pigeon(spot)
        at = (@ticks % (spot.width + 8)) - 4
        return nil if at.negative? || at > spot.width - 4

        "#{' ' * at}#{PIGEON[@ticks % 2]}"
      end

      def count(spot)
        return "\e[38;5;231;48;5;160m#{'—'.center(spot.width)}" unless desk.summary.reachable

        "\e[38;5;231;48;5;160m#{(unread.positive? ? "✉ #{unread}" : '0').center(spot.width)}"
      end

      def street
        return ' The post office is closed: the mail cannot be reached now.' unless desk.summary.reachable
        return ' F2 your mailbox · F3 the wall · You › Profile to log in, mail is for the accounts' unless @name.call

        new = unread.positive? ? "#{unread} new letter#{'s' unless unread == 1} in your box!" : 'No new letters.'
        " #{new} · F2 your mailbox · F3 the wall · F7 the sysops"
      end
    end
  end
end
