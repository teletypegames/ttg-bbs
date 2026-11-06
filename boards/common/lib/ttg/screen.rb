# frozen_string_literal: true

module TTG
  # The line-by-line screen TTG::Feedback and TTG::Wall draw on, the same on
  # either face, like rubbs' profile: the screen cleared, a title and a few
  # lines of intro, then lines, questions (a field), a cursor menu
  # (Rubbs::Common::Screens::Selector) or the full-screen editor
  # (Rubbs::Common::Screens::Editor). On a Commodore 64 the text is cut to 39
  # columns and turned into what the C64 can show (Rubbs::Petscii.plain).
  class Screen
    # The colours of a line's role (ANSI; the C64's line turns them into its own).
    COLORS = {
      title: Rubbs::Modern::Ansi::BRIGHT_CYAN,
      intro: Rubbs::Modern::Ansi::WHITE,
      text:  Rubbs::Modern::Ansi::WHITE,
      meta:  Rubbs::Modern::Ansi::GREY,
      name:  Rubbs::Modern::Ansi::YELLOW,
      good:  Rubbs::Modern::Ansi::BRIGHT_GREEN,
      bad:   Rubbs::Modern::Ansi::BRIGHT_RED
    }.freeze

    # The Rubbs::Common::Line::Session it draws on.
    attr_reader :session

    # A screen on +session+.
    def initialize(session)
      @session = session
      @runner  = Rubbs::Common::Call::FlowRunner.new(session, session.session_id, Rubbs::Common::Call::Flow.new)
    end

    # Whether the caller is on a Commodore 64.
    def petscii? = @session.respond_to?(:petscii?) && @session.petscii?

    # The columns a line may take.
    def cols = petscii? ? Rubbs::Petscii::COLS - 1 : [@session.term_cols.to_i, 20].max - 1

    # Clears the screen and writes +title+ and +intro+ (a String, may be
    # +nil+) under it, then an empty line.
    def head(title, intro = nil)
      @session.write(petscii? ? Rubbs::Petscii::CLEAR : "#{Rubbs::Modern::Ansi::RESET}#{Rubbs::Modern::Ansi::CLEAR}")
      line(title.to_s.upcase, :title)
      paragraph(intro, :intro) if intro
      blank
    end

    # Writes +text+ in the colour of +role+ (COLORS), wrapped to #cols, with
    # +indent+ spaces before each line.
    def paragraph(text, role = :text, indent: 0)
      wrap(text.to_s, cols - indent).each { |part| line("#{' ' * indent}#{part}", role) }
    end

    # Writes one line in the colour of +role+, cut to #cols.
    def line(text, role = :text)
      text = plain(text.to_s)[0, cols]
      @session.write("#{COLORS.fetch(role)}#{text}#{Rubbs::Modern::Ansi::RESET}#{Rubbs::Modern::Ansi::CRLF}")
    end

    # An empty line.
    def blank = @session.write(Rubbs::Modern::Ansi::CRLF)

    # +text+ cut into lines of +width+ at the spaces.
    def wrap(text, width) = Rubbs::Modern::FrameBuffer.wrap_ansi(plain(text), [width, 10].max)

    # +text+ as this face shows it: the C64's characters on a C64.
    def plain(text) = petscii? ? Rubbs::Petscii.plain(text) : text

    # Asks +label+ on a line of its own; the answer stripped, or +nil+ when
    # the caller gave none. Raises Rubbs::Common::Line::Hangup when the line drops.
    def ask(label)
      answer = @runner.ask("#{COLORS[:name]}#{plain(label)}: #{Rubbs::Modern::Ansi::RESET}")
      raise Rubbs::Common::Line::Hangup if answer.nil?

      answer.to_s.strip.empty? ? nil : answer.to_s.strip
    end

    # The full-screen editor with +title+, starting from +text+, at most
    # +max+ characters. The text, or +nil+ when the caller quit.
    def edit(title, text: '', max: nil)
      Rubbs::Common::Screens::Editor.new(@session, text: text, title: plain(title.to_s.upcase), max: max).run
    end

    # A cursor menu of +items+, pairs of [label, value] (the first letter
    # of the label is its key); the value taken, or +nil+.
    def menu(items)
      items = items.map { |label, value| Rubbs::Common::Screens::Selector.item(plain(label), key: label[0].downcase, value: value) }
      width = [items.map { |item| item.label.length }.max.to_i + 6, 24].max
      Rubbs::Common::Screens::Selector.new(@session, items, width: [width, cols].min, back: :back).run
    end

    # Writes +text+ in the colour of +role+ and waits for a key.
    def tell(text, role = :good)
      paragraph(text, role)
      pause
    end

    # Writes the key hint and waits for a key. Raises Rubbs::Common::Line::Hangup when
    # the line drops.
    def pause
      line(petscii? ? 'PRESS A KEY' : 'Press a key', :meta)
      @session.readkey or raise Rubbs::Common::Line::Hangup
    end
  end
end
