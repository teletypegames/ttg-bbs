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

    # A post as the board pages it, +width+ columns wide; the web shows the
    # C64 screen of a post from the same lines.
    def self.post_lines(blog, post, width:, long_dates: width >= 58)
      wrap = ->(text) { BBS::FrameBuffer.wrap_ansi(text.to_s, width) }
      date = ->(time) { time.localtime.strftime(long_dates ? '%Y-%m-%d %H:%M' : '%Y-%m-%d') }
      meta = [blog.category(post.category).name, date.call(post.created_at), post.author].compact.join(' · ')
      lines = wrap.call(post.title).map { |l| " #{WH}#{l}#{LG}" }
      lines << " #{GR}#{meta}#{LG}"
      lines << " #{GR}updated #{date.call(post.updated_at)}#{LG}" if post.updated?
      lines << " #{RD}unpublished: only the editors see it#{LG}" unless post.published
      lines << ''
      lines.concat(wrap.call(post.summary).map { |l| " #{CY}#{l}#{LG}" }) unless post.summary.empty?
      lines << " #{DG}#{'─' * (width - 1)}#{LG}"
      body = post.body.strip.empty? ? '*(no text yet)*' : post.body
      lines.concat(BBS::Markdown.to_lines(body, width: width, theme: MARKDOWN).map { |l| " #{l}" })
    end

    # The flow of a face, +face+ one of Blog::FACES: the block makes the
    # screen and the masthead of a call from its session.
    def self.flow(blog, face:, &screen_of)
      BBS::Flow.define do
        call do |ctx, runner|
          screen, masthead = screen_of.call(runner.session)
          board = Board.new(blog, screen, ctx, masthead: masthead, face: face)
          board.run
          board.goodbye
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end

    def initialize(blog, screen, ctx, masthead:, face:)
      @blog     = blog
      @screen   = screen
      @ctx      = ctx
      @masthead = masthead
      @face     = face
    end

    def run
      @screen.cls
      @screen.puts
      @masthead.each { |l| @screen.puts l }
      loop do
        @screen.puts
        menu_line('L', 'latest posts')
        menu_line('C', 'categories')
        menu_line('G', 'go to post #')
        if user
          menu_line('U', "unpublished posts #{GR}(#{@blog.total(published: false)})#{LG}")
          menu_line('W', 'write a post')
          menu_line('P', 'change your password')
          menu_line('O', "log out #{GR}(#{user.name})#{LG}")
        else
          menu_line('E', 'editor login')
        end
        menu_line('Q', 'log off')
        keys = user ? %w[l c g u w p o q] : %w[l c g e q]
        case @screen.choose("\r\n #{WH}ttgblog#{LG}> ", keys)
        when 'l' then browse('LATEST POSTS') { @blog.posts(published: shown) }
        when 'u' then browse('UNPUBLISHED POSTS') { @blog.posts(published: false) }
        when 'c' then categories
        when 'g' then go_to
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

    # What the caller may read: everything for an editor, the published
    # posts for a reader (nil and true, as Blog#posts takes them).
    def shown = user ? nil : true

    def readable?(post) = post && (user || post.published)

    def draft_tag = wide? ? 'unpublished' : 'u'

    def wide? = @screen.cols >= 60

    def right = user ? "#{user.name} " : "#{@blog.total(published: true)} posts "

    def menu_line(key, text) = @screen.puts(" #{YE}#{key}#{LG} #{text}")

    # A post by its number, the one the web shows beside it.
    def go_to
      @screen.title('GO TO POST', right)
      @screen.say('The number of a post, as the web shows it. Return alone: back.', GR)
      @screen.write "\r\n #{WH}post ##{LG} "
      id = @screen.number
      return if id.nil? || id.zero?
      return show(id) if readable?(@blog.post(id))

      @screen.say("No post number #{id}.", RD)
      @screen.pause
    end

    def categories
      loop do
        category = @screen.pick('CATEGORIES', @blog.categories, empty: 'no categories are configured.', right: right) do |c|
          about = wide? && !c.about.empty? ? " #{GR}#{c.about}#{LG}" : ''
          "#{c.name} #{GR}(#{@blog.count(c.id, published: shown)})#{LG}#{about}"
        end
        break unless category

        browse(category.name.upcase) { @blog.posts(category: category.id, published: shown) }
      end
    end

    # The posts the block lists, listed again after one was changed.
    def browse(heading, &posts)
      list = posts.call
      loop do
        post = @screen.pick(heading, list, empty: 'no posts here yet.', right: right) do |p|
          tag   = wide? ? " #{CY}#{@blog.category(p.category).name}#{LG}" : ''
          draft = p.published ? '' : "#{RD}#{draft_tag}#{LG} "
          "#{GR}#{p.created_at.localtime.strftime(wide? ? '%Y-%m-%d' : '%m-%d')}#{LG} #{draft}#{p.title}#{tag}"
        end
        break unless post

        list = posts.call if show(post.id)
      end
    end

    # The post paged; an editor gets to edit or delete it after its last
    # page. True when it was changed or deleted.
    def show(id)
      post = @blog.post(id)
      return false unless readable?(post)

      heading = @blog.category(post.category).name.upcase
      unless user
        @screen.page(heading, post_lines(post), right: right)
        return false
      end

      @screen.page(heading, post_lines(post), right: right, wait: false)
      flip = post.published ? 'unpublish' : 'publish'
      case @screen.choose("\r\n #{YE}E#{LG} edit  #{YE}P#{LG} #{flip}  #{YE}D#{LG} delete  #{DG}return: back#{LG} ",
                          ['e', 'p', 'd', 'q', :enter])
      when 'e' then compose(post)
      when 'p' then publish?(post, !post.published)
      when 'd' then delete?(post)
      else false
      end
    end

    def post_lines(post) = Board.post_lines(@blog, post, width: @screen.width, long_dates: wide?)

    # Publishes the post, or takes it back to the editors. True when changed.
    def publish?(post, published)
      @screen.puts
      question = published ? "Publish \"#{post.title}\" on the web and to the readers?" : "Take \"#{post.title}\" back?"
      @screen.say(question, published ? GN : RD)
      return false unless @screen.choose(" #{WH}y/n#{LG}> ", %w[y n], back: 'n') == 'y'

      @blog.set_published(post.id, published)
      @screen.say(published ? 'Published.' : 'Unpublished: only the editors see it now.', GN)
      @screen.pause
      true
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

    # The title in a field, the current one to start from. Nil when the
    # caller quit or left it empty.
    def ask_title(current)
      @screen.title('TITLE', right)
      @screen.say("Up to #{Blog::MAX_TITLE} characters. Return alone or Stop: back.", GR)
      @screen.puts
      title = @screen.ask(" #{WH}title#{LG}> ", text: current, max: Blog::MAX_TITLE)
      title.empty? ? nil : title
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
      post = Blog::Post.new(id: 0, slug: '', **draft, author: user.name, face: @face, published: true,
                            published_at: nil, created_at: Time.now, updated_at: Time.now)
      @screen.page('PREVIEW', post_lines(post), right: right)
    end

    def save(draft, post)
      result = if post
                 @blog.update(post.id, **draft)
               else
                 @blog.create(author: user, face: @face, **draft)
               end
      @screen.puts
      if result.is_a?(Symbol)
        @screen.say(ERRORS.fetch(result, 'The post could not be saved.'), RD)
        @screen.pause
        return false
      end
      if post
        @screen.say('Saved.', GN)
        @screen.pause
      else
        @screen.say("Saved as number #{result.id}, unpublished: only the editors see it.", GN)
        publish?(result, true)
      end
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
