# frozen_string_literal: true

require 'time'

module TTG
  module PrivateMessage
    # How a letter looks on the line: a sheet in a frame with the stamp in its
    # top right corner (the network's, in red), the writer, the reader and
    # the day on the left, the subject and the letter under a rule, and the
    # postmark of TTG MAIL at the bottom; and the little film of a letter
    # going into the pillar box when it is sent. The same on either face, cut
    # to its columns; the C64's characters on a C64.
    module Stationery
      # Back to the plain colours.
      R = Rubbs::Modern::Ansi::RESET
      # The colours of the sheet: the frame, the stamp, the labels, the text,
      # the subject, the postmark.
      INK = {
        frame:    Rubbs::Modern::Ansi::GREY,
        stamp:    Rubbs::Modern::Ansi::BRIGHT_RED,
        label:    Rubbs::Modern::Ansi::YELLOW,
        text:     Rubbs::Modern::Ansi::WHITE,
        subject:  Rubbs::Modern::Ansi::BRIGHT_CYAN,
        postmark: Rubbs::Modern::Ansi::BRIGHT_GREEN
      }.freeze
      # The stamp's inner width.
      STAMP = 7
      # The frames of the film, the steps of the letter to the box.
      STEPS = 12
      # Seconds a frame of the film stays.
      FRAME = 0.06

      # The lines of +entry+ (a letter of the Central's answer) on a sheet
      # +cols+ wide; +petscii+ for a C64 (its glyphs, no ✉).
      def self.sheet(entry, cols, petscii: false)
        width = [cols, 30].max - 1
        inner = width - 2
        left  = inner - STAMP - 3
        [top(left), *head(entry, left, petscii), rule(inner), *letter(entry, inner), bottom(entry, inner)]
      end

      # The frames of the film: the letter on its way to the pillar box, in
      # +cols+ columns.
      def self.film(cols, petscii: false)
        letter = petscii ? '*' : '✉'
        road   = (cols - 12).clamp(10, 30)
        (0..STEPS).map do |step|
          at = road * step / STEPS
          "#{' ' * 2}#{INK[:frame]}#{'·' * at}#{INK[:subject]}#{letter}#{INK[:frame]}#{' ' * (road - at)}#{INK[:stamp]}▐█▌#{R}"
        end
      end

      class << self
        private

        def top(left) = ink(:frame, "┌#{'─' * left}┬#{'─' * (STAMP + 2)}┐")

        def head(entry, left, petscii)
          rows = [field('From', entry['from_name'], left), field('To', entry['to_name'], left), dated(entry, left)]
          rows.zip(stamp(petscii ? '*' : '✉')).map { |row, part| "#{row}#{ink(:frame, '│') unless row == rows.last}#{part}" }
        end

        def dated(entry, left)
          ink(:frame, '│') + ink(:text, " #{when_text(entry['created_at'])} · #{entry['board']}"[0, left - 1].ljust(left))
        end

        def stamp(mark)
          ["#{ink(:stamp, " ▒#{'TTG'.center(STAMP - 2)}▒ ")}#{ink(:frame, '│')}",
           "#{ink(:stamp, " ▒#{mark.center(STAMP - 2)}▒ ")}#{ink(:frame, '│')}",
           ink(:frame, "└#{'─' * (STAMP + 2)}┤")]
        end

        def field(label, value, left)
          "#{ink(:frame, '│')} #{ink(:label, label.ljust(5))}#{ink(:text, value.to_s.ljust(left - 7)[0, left - 7])} "
        end

        def rule(inner) = ink(:frame, "├#{'─' * inner}┤")

        def letter(entry, inner)
          subject = entry['subject'].to_s.empty? ? '…' : entry['subject'].to_s
          body = entry['body'].to_s.split("\n").flat_map do |line|
            line.strip.empty? ? [''] : Rubbs::Modern::FrameBuffer.wrap_ansi(line, inner - 2)
          end
          [boxed(subject[0, inner - 2], :subject, inner), boxed('', :text, inner),
           *body.map { |line| boxed(line, :text, inner) }]
        end

        def boxed(text, role, inner) = "#{ink(:frame, '│')} #{ink(role, text.ljust(inner - 2))} #{ink(:frame, '│')}"

        def bottom(entry, inner)
          mark = " ~ TTG MAIL #{postmark_day(entry['created_at'])} ~ "
          ink(:frame, "└#{'─' * (inner - mark.length - 2)}") + ink(:postmark, mark) + ink(:frame, '──┘')
        end

        def ink(role, text) = "#{INK.fetch(role)}#{text}#{R}"

        def when_text(iso) = Time.parse(iso.to_s).localtime.strftime('%Y-%m-%d %H:%M')

        def postmark_day(iso) = Time.parse(iso.to_s).localtime.strftime('%d %b').upcase
      end
    end
  end
end
