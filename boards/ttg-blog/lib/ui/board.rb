# frozen_string_literal: true

require_relative 'screen'
require_relative 'post_page'
require_relative 'board/account'
require_relative 'board/composer'

module UI
  # One call of the blog, line by line on either face: the readers' menu (the
  # latest posts, the categories, a post paged a screenful at a time) and,
  # after an editor logs in, writing, editing and deleting posts. The body is
  # Markdown, typed in a line editor with slash commands, which a C64 can
  # type as well as a modern terminal. It works on the services of a
  # TTGBlogBBS; a face (UI::Modern::Board, UI::Petscii::Board) gives it its
  # FACE, its screen and its masthead.
  class Board
    include Account
    include Composer

    MOTTO = 'news from teletype games'

    # The name on the masthead, in BBS::BlockFont.
    LOGO = 'TTG BLOG'

    # The main menu's keys and what they do; q hangs up.
    ACTIONS = { 'l' => :latest, 'u' => :unpublished, 'c' => :categories, 'g' => :go_to, 'e' => :login,
                'w' => :compose, 'p' => :password, 'o' => :log_out }.freeze

    def initialize(bbs, screen, ctx)
      @posts      = bbs.posts
      @editors    = bbs.editors
      @categories = bbs.categories
      @screen     = screen
      @ctx        = ctx
    end

    def run
      start
      loop do
        choice = main_choice
        return if choice == 'q'

        choice.is_a?(PostModel) ? show(choice.id) : ACTIONS[choice]&.then { |action| __send__(action) }
      end
    end

    def goodbye = BBS::Goodbye.petscii(@screen, bar: 'thanks for reading ttg blog bbs', color: YE)

    private

    # The lines over the menu, drawn by the face.
    def masthead = raise(NotImplementedError)

    # The screen before the first menu: the masthead.
    def start
      @screen.cls
      @screen.puts
      masthead.each { |l| @screen.puts l }
    end

    # The main menu, under the masthead the first time and under a title
    # bar after: the key of the caller's choice.
    def main_choice
      @screen.title('TTG BLOG BBS', right) if @home_shown
      @home_shown = true
      @screen.puts
      menu_line('L', 'latest posts')
      menu_line('C', 'categories')
      menu_line('G', 'go to post #')
      if user
        menu_line('U', "unpublished posts #{GR}(#{@posts.total(published: false)})#{LG}")
        menu_line('W', 'write a post')
        menu_line('P', 'change your password')
        menu_line('O', "log out #{GR}(#{user.name})#{LG}")
      else
        menu_line('E', 'editor login')
      end
      menu_line('Q', 'log off')
      @screen.choose("\r\n #{WH}ttgblog#{LG}> ", user ? %w[l c g u w p o q] : %w[l c g e q])
    end

    # What an editor does with a post after its last page: e, p, d or q.
    def post_choice(post)
      flip = post.published ? 'unpublish' : 'publish'
      @screen.choose("\r\n #{YE}E#{LG} edit  #{YE}P#{LG} #{flip}  #{YE}D#{LG} delete  #{DG}return: back#{LG} ",
                     ['e', 'p', 'd', 'q', :enter])
    end

    # The draft on its screen and the key of the caller's choice.
    def draft_choice(draft, post)
      draft_screen(draft, post)
      @screen.choose("\r\n #{WH}edit#{LG}> ", %w[t c s b v w q])
    end

    def face = self.class::FACE

    def latest = browse('LATEST POSTS') { @posts.all(published: shown) }

    def unpublished = browse('UNPUBLISHED POSTS') { @posts.all(published: false) }

    def log_out = @ctx.delete(:user)

    def user = @ctx[:user]

    # What the caller may read: everything for an editor, the published
    # posts for a reader (nil and true, as PostService#all takes them).
    def shown = user ? nil : true

    def readable?(post) = post && (user || post.published)

    def draft_tag = wide? ? 'unpublished' : 'u'

    def wide? = @screen.cols >= 60

    def right = user ? "#{user.name} " : "#{@posts.total(published: true)} posts "

    def menu_line(key, text) = @screen.puts(" #{YE}#{key}#{LG} #{text}")

    # A post by its number, the one the web shows beside it.
    def go_to
      @screen.title('GO TO POST', right)
      @screen.say('The number of a post, as the web shows it. Return alone: back.', GR)
      @screen.write "\r\n #{WH}post ##{LG} "
      id = @screen.number
      return if id.nil? || id.zero?
      return show(id) if readable?(@posts.find(id))

      @screen.say("No post number #{id}.", RD)
      @screen.pause
    end

    def categories
      loop do
        category = @screen.pick('CATEGORIES', @categories.all, empty: 'no categories are configured.', right: right) do |c|
          about = wide? && !c.about.empty? ? " #{GR}#{c.about}#{LG}" : ''
          "#{c.name} #{GR}(#{@posts.count(c.id, published: shown)})#{LG}#{about}"
        end
        break unless category

        browse(category.name.upcase) { @posts.all(category: category.id, published: shown) }
      end
    end

    # The posts the block lists, listed again after one was changed.
    def browse(heading, &posts)
      list = posts.call
      loop do
        post = @screen.pick(heading, list, empty: 'no posts here yet.', right: right) do |p|
          tag   = wide? ? " #{CY}#{@categories.find(p.category).name}#{LG}" : ''
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
      post = @posts.find(id)
      return false unless readable?(post)

      heading = @categories.find(post.category).name.upcase
      unless user
        @screen.page(heading, post_lines(post), right: right)
        return false
      end

      @screen.page(heading, post_lines(post), right: right, wait: false, room: 2)
      case post_choice(post)
      when 'e' then compose(post)
      when 'p' then publish?(post, !post.published)
      when 'd' then delete?(post)
      else false
      end
    end

    def post_lines(post) = PostPage.lines(@categories, post, width: @screen.width, long_dates: wide?)

    # Publishes the post, or takes it back to the editors. True when changed.
    def publish?(post, published)
      question = published ? "Publish \"#{post.title}\" on the web and to the readers?" : "Take \"#{post.title}\" back?"
      return false unless @screen.confirm?(question, published ? GN : RD)

      @posts.set_published(post.id, published)
      @screen.notice(published ? 'Published.' : 'Unpublished: only the editors see it now.', GN, gap: false)
      true
    end

    def delete?(post)
      return false unless @screen.confirm?("Delete \"#{post.title}\" for good?", RD)

      @posts.delete(post.id)
      @screen.notice('Deleted.', GN, gap: false)
      true
    end
  end
end
