# frozen_string_literal: true

require 'yaml'

# TTG Trivia: a door game of the old kind, ten questions against the clock
# and a hall of fame. Half the questions come from the board's own
# content (the catalog, the team), the rest from lib/content/trivia.yml.
module Trivia
  ROUNDS     = 10
  SECONDS    = 20
  KEEP       = 10
  FIXED      = File.expand_path('../content/trivia.yml', __dir__)
  FAKE_GAMES = ['Pixel Plumber', 'Space Accountant', 'Disk Error 64', 'The Last Floppy',
                'Modem Wars', 'Lord of the Prompt', 'Sprite Sorcerer', 'Cassette Quest'].freeze

  Question = Struct.new(:text, :answers, :right)

  def self.door(games:, site:, scores:)
    ->(session, ctx) { Game.new(session, ctx, games: games, site: site, scores: scores).run }
  end

  # One question about each of a few games and members, the rest fixed.
  def self.questions(games, site)
    released = games.all.select { |g| g.released? && !g.dev_build? }
    pool = fixed + platform_questions(released) + [title_question(released), motto_question(site)].compact
    pool.sample(ROUNDS).map { |q| Question.new(q.text, q.answers.shuffle, q.right) }
  end

  def self.fixed
    YAML.safe_load_file(FIXED).map do |q|
      Question.new(q['question'], q['answers'].map(&:to_s), q['answers'].first.to_s)
    end
  end

  def self.platform_questions(released)
    platforms = released.map { |g| GamesService.platform_name(g.platform) }.uniq
    return [] if platforms.size < 4

    released.sample(3).map do |g|
      right = GamesService.platform_name(g.platform)
      Question.new("Which platform is #{g.title} made for?", [right, *(platforms - [right]).sample(3)], right)
    end
  end

  def self.title_question(released)
    titles = released.map(&:title).uniq
    return if titles.empty?

    right = titles.sample
    Question.new('Which of these is a Teletype Games title?', [right, *FAKE_GAMES.sample(3)], right)
  end

  def self.motto_question(site)
    with_motto = site.members.reject { |m| m.motto.to_s.strip.empty? }
    return if with_motto.size < 4

    m = with_motto.sample
    Question.new("Whose motto is it? \"#{m.motto}\"", [m.nick, *(with_motto - [m]).map(&:nick).sample(3)], m.nick)
  end

  class Game
    Y = "\e[1;33m"
    C = "\e[1;36m"
    W = "\e[1;37m"
    D = "\e[0;37m"
    G = "\e[1;32m"
    R = "\e[1;31m"
    M = "\e[1;35m"
    O = "\e[0m"

    LOGO = [[Y, '▀█▀ ▀█▀ █▀▀   ▀█▀ █▀█ █ █ █ █ ▄▀█'], [Y, ' █   █  █▄█    █  █▀▄ █ ▀▄▀ █ █▀█'],
            [D, ''], [D, 'a door game of the Teletype BBS']].freeze

    def initialize(session, ctx, games:, site:, scores:)
      @session = session
      @ctx     = ctx
      @games   = games
      @site    = site
      @scores  = scores
      @name    = ctx[:username] || 'Anonymous'
    end

    def run
      title
      return unless wait_key

      questions = Trivia.questions(@games, @site)
      @points = @correct = @streak = 0
      questions.each_with_index do |q, i|
        result = ask(q, i + 1, questions.size, @points)
        return nil if result.nil?

        score(q, result)
        sleep 1.2
      end
      finish(@points, @correct, questions.size)
    end

    private

    def out(text) = @session.write(text)

    # Counts the answer worth +result+ (0 or less: time out or wrong) and
    # tells the caller.
    def score(question, result)
      return missed(question, result) unless result.positive?

      @streak += 1
      bonus    = @streak >= 3 ? 50 : 0
      @points += result + bonus
      @correct += 1
      out "\r\n  #{G}RIGHT!#{O} #{W}+#{result}#{O}#{"  #{M}streak bonus +#{bonus}#{O}" if bonus.positive?}\r\n"
    end

    def missed(question, result)
      @streak = 0
      out "\r\n  #{R}#{result.zero? ? 'TIME!' : 'WRONG.'}#{O} The answer: #{Y}#{question.right}#{O}\r\n"
    end

    def title
      out "\e[0m\e[2J\e[H"
      out "  #{C}╔#{'═' * 62}╗\r\n"
      LOGO.each { |color, text| out "  ║#{color}   #{text.ljust(59)}#{C}║\r\n" }
      out "  ╚#{'═' * 62}╝#{O}\r\n\r\n"
      out "  #{W}#{ROUNDS} questions#{O} about Teletype Games, the board and the old days.\r\n"
      out "  Answer with #{Y}A#{O}-#{Y}D#{O}. #{SECONDS} seconds each: the faster, the more points,\r\n"
      out "  and three right in a row earn a streak bonus. #{Y}Q#{O} quits.\r\n\r\n"
      hall
      out "\r\n  #{W}Press any key to start, Q to go back...#{O}"
    end

    def hall
      best = @scores.best(KEEP)
      out "  #{C}─── Hall of Fame ──────────────────────────────────#{O}\r\n"
      if best.empty?
        out "  #{D}(empty: the first name here is yours to take)#{O}\r\n"
      else
        best.each_with_index do |s, i|
          out format(
            "  #{Y}%2d.#{O} #{W}%-20s#{O} %5d pts  #{D}%2s/#{ROUNDS}  %s#{O}\r\n",
            i + 1,
            s.username.to_s[0, 20],
            s.points.to_i,
            s.correct,
            s.timestamp.to_s[0, 10]
          )
        end
      end
    end

    def wait_key
      loop do
        key = @session.readkey(timeout: 60)
        return false if key.nil? || key == :escape || (key.is_a?(String) && key.casecmp?('q'))
        return true unless key == :idle
      end
    end

    # Points for the answer: 0 on time out, -1 wrong, nil when the caller quits.
    def ask(q, n, total, points)
      show_question(q, n, total, points)
      started = Time.now
      loop do
        left = SECONDS - (Time.now - started).to_i
        clock(left)
        return 0 if left <= 0

        answer = answer(q, left)
        return answer unless answer == :none
      end
    end

    def show_question(q, n, total, points)
      out "\e[0m\e[2J\e[H"
      out "  #{C}TTG TRIVIA#{O}   #{D}question #{n}/#{total}#{O}   #{W}#{points} pts#{O}   #{D}caller: #{@name}#{O}\r\n"
      out "  #{C}#{'─' * 66}#{O}\r\n\r\n"
      wrap(q.text, 66).each { |l| out "  #{W}#{l}#{O}\r\n" }
      out "\r\n"
      q.answers.each_with_index { |a, i| out "    #{Y}#{(65 + i).chr})#{O} #{a}\r\n" }
      out "\r\n"
    end

    def clock(left)
      bar = ('█' * left) + ('░' * (SECONDS - left))
      out "\r  #{left > 5 ? G : R}#{bar}#{O} #{format('%2d', left)}s  "
    end

    # The points of the key pressed within half a second, nil to quit,
    # :none for no answer yet.
    def answer(q, left)
      key = @session.readkey(timeout: 0.5)
      return nil if key.nil? || (key.is_a?(String) && key.casecmp?('q'))
      return :none unless key.is_a?(String)

      index = key.upcase.ord - 65
      return :none unless index.between?(0, q.answers.size - 1)

      q.answers[index] == q.right ? 50 + (left * 10) : -1
    end

    def finish(points, correct, total)
      out "\e[0m\e[2J\e[H\r\n"
      out "  #{C}═══ GAME OVER ═══#{O}\r\n\r\n"
      out "  #{W}#{@name}#{O}, you answered #{Y}#{correct}#{O} of #{total} and scored #{Y}#{points}#{O} points.\r\n\r\n"
      if @name.casecmp?(MemberService::ANONYMOUS)
        out "  #{D}Anonymous scores do not go on the wall: call with a name next time.#{O}\r\n\r\n"
      else
        @scores.add(@name, points, correct)
      end
      hall
      out "\r\n  #{W}Press any key to return to the BBS...#{O}"
      @session.readkey(timeout: 120)
    end

    def wrap(text, width)
      text.split.each_with_object([+'']) do |word, lines|
        if lines.last.empty? then lines.last << word
        elsif lines.last.length + word.length + 1 <= width then lines.last << " #{word}"
        else lines << word.dup
        end
      end
    end
  end
end
