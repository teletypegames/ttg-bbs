# frozen_string_literal: true

require_relative 'screen'

module UI
  # One call of the blog, line by line on either face: the readers' menu (the
  # latest posts, the categories, a post paged a screenful at a time) and,
  # after an editor logs in, writing, editing and deleting posts. The body is
  # Markdown, typed in a line editor with slash commands, which a C64 can
  # type as well as a modern terminal. The faces (UI::Modern, UI::Petscii) give
  # it a screen and a masthead.
  class Board
    LOGIN_TRIES = 3

    LOGO_FONT = {
      'T' => %w[### .#. .#. .#. .#.], 'G' => %w[### #.. #.# #.# ###], 'B' => %w[##. #.# ##. #.# ##.],
      'L' => %w[#.. #.. #.. #.. ###], 'O' => %w[### #.# #.# #.# ###], ' ' => %w[. . . . .]
    }.freeze

    MOTTO = 'news from teletype games'

    ERRORS = {
      no_title:     'The post needs a title.',
      long_title:   "The title is longer than #{Blog::MAX_TITLE} characters.",
      long_summary: "The summary is longer than #{Blog::MAX_SUMMARY} characters.",
      long_body:    'The body is too long.',
      bad_category: 'Pick a category from the list.'
    }.freeze

    # TTG BLOG as five rows of bits, # set and . clear, for a face to draw.
    def self.logo_bits = 5.times.map { |row| 'TTG BLOG'.chars.map { |c| LOGO_FONT[c][row] }.join('.') }

    # The flow of a face: the block makes the screen and the masthead of a
    # call from its session.
    def self.flow(blog, &face)
      BBS::Flow.define do
        call do |ctx, runner|
          screen, masthead = face.call(runner.session)
          board = Board.new(blog, screen, ctx, masthead: masthead)
          board.run
          board.goodbye
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end

    def initialize(blog, screen, ctx, masthead:)
      @blog     = blog
      @screen   = screen
      @ctx      = ctx
      @masthead = masthead
    end

    def run
      @screen.cls
      @screen.puts
      @masthead.each { |l| @screen.puts l }
      loop do
        @screen.puts
        menu_line('L', 'latest posts')
        menu_line('C', 'categories')
        if user
          menu_line('W', 'write a post')
          menu_line('P', 'change your password')
          menu_line('O', "log out #{GR}(#{user.name})#{LG}")
        else
          menu_line('E', 'editor login')
        end
        menu_line('Q', 'log off')
        keys = user ? %w[l c w p o q] : %w[l c e q]
        case @screen.choose("\r\n #{WH}ttgblog#{LG}> ", keys)
        when 'l' then browse('LATEST POSTS') { @blog.posts }
        when 'c' then categories
        when 'e' then login
        when 'w' then compose
        when 'p' then password
        when 'o' then @ctx.delete(:user)
        when 'q' then return
        end
        @screen.title('TTGBLOG', right)
      end
    end

    def goodbye
      @screen.cls
      @screen.puts
      @screen.puts " #{YE}#{RV}#{' thanks for reading ttgblog'.ljust(@screen.cols - 1)}#{RO}#{LG}"
      @screen.puts
      @screen.say('More of us: teletypegames.org', GR)
      @screen.puts
      sleep 1.2
      @screen.puts " #{LG}+++"
      sleep 0.6
      @screen.puts ' ATH0'
      sleep 0.4
      @screen.puts " #{RD}NO CARRIER#{LG}"
      @screen.puts
    end

    private

    def user = @ctx[:user]

    def wide? = @screen.cols >= 60

    def right = user ? "#{user.name} " : "#{@blog.total} posts "

    def menu_line(key, text) = @screen.puts(" #{YE}#{key}#{LG} #{text}")

    def date(time, long: wide?) = time.localtime.strftime(long ? '%Y-%m-%d %H:%M' : '%Y-%m-%d')

    def categories
      loop do
        category = @screen.pick('CATEGORIES', @blog.categories, empty: 'no categories are configured.', right: right) do |c|
          about = wide? && !c.about.empty? ? " #{GR}#{c.about}#{LG}" : ''
          "#{c.name} #{GR}(#{@blog.count(c.id)})#{LG}#{about}"
        end
        break unless category

        browse(category.name.upcase) { @blog.posts(category: category.id) }
      end
    end

    # The posts the block lists, listed again after one was changed.
    def browse(heading, &posts)
      list = posts.call
      loop do
        post = @screen.pick(heading, list, empty: 'no posts here yet.', right: right) do |p|
          tag = wide? ? " #{CY}#{@blog.category(p.category).name}#{LG}" : ''
          "#{GR}#{p.created_at.localtime.strftime(wide? ? '%Y-%m-%d' : '%m-%d')}#{LG} #{p.title}#{tag}"
        end
        break unless post

        list = posts.call if show(post.id)
      end
    end

    # The post paged; an editor gets to edit or delete it after its last
    # page. True when it was changed or deleted.
    def show(id)
      post = @blog.post(id)
      return false unless post

      heading = @blog.category(post.category).name.upcase
      unless user
        @screen.page(heading, post_lines(post), right: right)
        return false
      end

      @screen.page(heading, post_lines(post), right: right, wait: false)
      case @screen.choose("\r\n #{YE}E#{LG} edit  #{YE}D#{LG} delete  #{DG}return: back#{LG} ", ['e', 'd', 'q', :enter])
      when 'e' then compose(post)
      when 'd' then delete?(post)
      else false
      end
    end

    def post_lines(post)
      meta = [@blog.category(post.category).name, date(post.created_at), post.author].compact.join(' · ')
      lines = @screen.wrap(post.title).map { |l| " #{WH}#{l}#{LG}" }
      lines << " #{GR}#{meta}#{LG}"
      lines << " #{GR}updated #{date(post.updated_at)}#{LG}" if post.updated?
      lines << ''
      lines.concat(@screen.wrap(post.summary).map { |l| " #{CY}#{l}#{LG}" }) unless post.summary.empty?
      lines << " #{DG}#{'─' * (@screen.width - 1)}#{LG}"
      body = post.body.strip.empty? ? '*(no text yet)*' : post.body
      lines.concat(BBS::Markdown.to_lines(body, width: @screen.width, theme: MARKDOWN).map { |l| " #{l}" })
    end

    def delete?(post)
      @screen.puts
      @screen.say("Delete \"#{post.title}\" for good?", RD)
      return false unless @screen.choose(" #{WH}y/n#{LG}> ", %w[y n], back: 'n') == 'y'

      @blog.delete(post.id)
      @screen.say('Deleted.', GN)
      @screen.pause
      true
    end

    def login
      if @ctx[:tries].to_i >= LOGIN_TRIES
        @screen.puts
        @screen.say('No more tries on this call.', RD)
        @screen.pause
        return
      end

      @screen.title('EDITOR LOGIN', right)
      @screen.say('For the editors of the blog. Return alone: back.', GR)
      @screen.puts
      name = @screen.ask(" #{WH}name#{LG}> ", max: Blog::MAX_NAME)
      return if name.empty?

      pass = @screen.ask(" #{WH}password#{LG}> ", mask: '*', max: 200)
      found = @blog.authenticate(name, pass)
      @screen.puts
      if found
        @ctx[:user] = found
        @screen.say("Welcome, #{found.name}. Open a post to edit it, or write a new one.", GN)
      else
        @ctx[:tries] = @ctx[:tries].to_i + 1
        warn "ttgblog: failed login for #{name.inspect} (#{@ctx[:session_id]})"
        sleep 1
        @screen.say('Wrong name or password.', RD)
      end
      @screen.pause
    end

    def password
      @screen.title('CHANGE PASSWORD', right)
      @screen.say("At least #{Blog::MIN_PASS} characters. Return alone: back.", GR)
      @screen.puts
      old = @screen.ask(" #{WH}current#{LG}> ", mask: '*', max: 200)
      return if old.empty?

      fresh = @screen.ask(" #{WH}new#{LG}> ", mask: '*', max: 200)
      again = @screen.ask(" #{WH}again#{LG}> ", mask: '*', max: 200)
      @screen.puts
      if !@blog.authenticate(user.name, old)
        @screen.say('The current password is wrong.', RD)
      elsif fresh != again
        @screen.say('The two new ones differ.', RD)
      elsif @blog.set_password(user.name, fresh) == :ok
        @screen.say('Password changed.', GN)
      else
        @screen.say("The new password needs at least #{Blog::MIN_PASS} characters.", RD)
      end
      @screen.pause
    end

    # A new post, or +post+ edited: the fields one after the other for a new
    # one, then a menu of fields until it is saved or dropped. True when saved.
    def compose(post = nil)
      draft = if post
                { title: post.title, summary: post.summary, body: post.body, category: post.category }
              else
                new_draft
              end
      return false unless draft

      saved = post ? draft.dup : {}
      loop do
        draft_screen(draft, post)
        case @screen.choose("\r\n #{WH}edit#{LG}> ", %w[t c s b v w q])
        when 't' then (t = ask_title(draft[:title])) && draft[:title] = t
        when 'c' then (c = pick_category) && draft[:category] = c
        when 's' then draft[:summary] = ask_summary(draft[:summary])
        when 'b' then (b = edit_body(draft[:body])) && draft[:body] = b
        when 'v' then preview(draft)
        when 'w' then return true if save(draft, post)
        when 'q' then return false if draft == saved || drop?
        end
      end
    end

    def new_draft
      title = ask_title('')
      return nil unless title

      category = pick_category
      return nil unless category

      summary = ask_summary('')
      body    = edit_body('')
      { title: title, summary: summary, body: body || '', category: category }
    end

    def draft_screen(draft, post)
      @screen.title(post ? "EDIT POST #{post.id}" : 'NEW POST', right)
      field('T', 'title', draft[:title])
      field('C', 'category', @blog.category(draft[:category]).name)
      field('S', 'summary', draft[:summary].empty? ? '-' : draft[:summary])
      field('B', 'body', "#{draft[:body].lines.size} lines")
      @screen.puts
      @screen.puts " #{YE}V#{LG} view  #{YE}W#{LG} save  #{YE}Q#{LG} quit"
    end

    def field(key, name, value)
      @screen.puts " #{YE}#{key}#{LG} #{GR}#{name}#{LG}"
      @screen.wrap(value, @screen.width - 3).first(3).each { |l| @screen.puts "    #{l}" }
    end

    # The title in the editor, the current one to start from. Nil when the
    # caller quit or left it empty.
    def ask_title(current)
      title = @screen.edit(current, title: 'TITLE', single_line: true, max: Blog::MAX_TITLE)&.strip
      title.nil? || title.empty? ? nil : title
    end

    # The summary in the editor; the current one when the caller quit.
    def ask_summary(current)
      summary = @screen.edit(current, title: 'SUMMARY', single_line: true, max: Blog::MAX_SUMMARY)
      summary.nil? ? current : summary.strip
    end

    def pick_category
      @screen.pick('CATEGORY', @blog.categories, empty: 'no categories are configured.', right: right, &:name)&.id
    end

    def preview(draft)
      post = Blog::Post.new(id: 0, **draft, author: user.name, created_at: Time.now, updated_at: Time.now)
      @screen.page('PREVIEW', post_lines(post), right: right)
    end

    def save(draft, post)
      result = if post
                 @blog.update(post.id, **draft)
               else
                 @blog.create(author: user, **draft)
               end
      @screen.puts
      if result.is_a?(Symbol)
        @screen.say(ERRORS.fetch(result, 'The post could not be saved.'), RD)
        @screen.pause
        return false
      end
      @screen.say(post ? 'Saved.' : "Posted as number #{result.id}.", GN)
      @screen.pause
      true
    rescue SQLite3::Exception => e
      warn "ttgblog: saving failed: #{e.message}"
      @screen.say('The post could not be saved. Try again later.', RD)
      @screen.pause
      false
    end

    def drop?
      @screen.puts
      @screen.say('Drop the changes?', RD)
      @screen.choose(" #{WH}y/n#{LG}> ", %w[y n], back: 'n') == 'y'
    end

    # The body in the editor, in Markdown; nil when the caller quit.
    def edit_body(body)
      @screen.edit(body.to_s, title: 'BODY (MARKDOWN)', max: Blog::MAX_BODY)&.rstrip
    end
  end
end
