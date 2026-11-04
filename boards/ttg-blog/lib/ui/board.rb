# frozen_string_literal: true

require_relative 'post_page'
require_relative 'board/composer'

module UI
  # One call of the blog, line by line on either face: the readers' menu (the
  # latest posts, the categories, a post paged a screenful at a time) and,
  # after an editor (the blogger role) logs in, writing, editing and deleting posts. The body is
  # Markdown, typed in a line editor with slash commands, which a C64 can
  # type as well as a modern terminal. A face (UI::Modern, UI::Petscii) gives
  # it its masthead and the shape of its menus.
  class Board < BBS::Petscii::Face
    include Composer

    MOTTO = 'news from teletype games'

    # The name on the masthead, in BBS::BlockFont.
    LOGO = 'TTG BLOG'

    title('TTG BLOG BBS') { right }

    # The items of the main menu on both faces: the readers' items, the
    # editor's after a login.
    ITEMS = proc do
      item('l', 'latest posts', 'every post, newest first') { latest }
      item('c', 'categories', -> { categories.all.map(&:name).join(', ') }) { browse_categories }
      item('g', 'go to post #', 'by the number the web shows') { go_to }
      item('u', -> { unpublished_label }, 'waiting to be published', if: -> { user }) { unpublished }
      item('w', -> { "write a post#{drafts_note}" }, 'it waits unpublished until you publish it', if: -> { user }) do
        compose
      end
      item('p', 'profile', -> { signed_in? ? identity.name : 'log in: the editors of the blog' }) { open_profile }
      log_off
    end

    main_menu(&ITEMS)

    private

    def unpublished_label = "unpublished posts #{GR}(#{posts.total(published: false)})#{LG}"

    # What an editor does with a post after its last page: e, p, d, c
    # (a published post's QR code) or q.
    def post_choice(post)
      flip = post.published? ? 'unpublish' : 'publish'
      qr   = post.published? ? "#{YE}C#{LG} qr  " : ''
      choose(
        "\r\n #{qr}#{YE}E#{LG} edit  #{YE}P#{LG} #{flip}  #{YE}D#{LG} delete  #{DG}return: back#{LG} ",
        [*('c' if post.published?), 'e', 'p', 'd', 'q', :enter]
      )
    end

    # What a reader does after the last page of a post: c or q.
    def reader_choice
      choose("\r\n #{YE}C#{LG} qr code of its web page  #{DG}return: back#{LG} ", ['c', 'q', :enter])
    end

    def face_name = session.petscii? ? 'petscii' : 'modern'

    def latest = browse('LATEST POSTS') { posts.all(published: shown) }

    def unpublished = browse('UNPUBLISHED POSTS') { posts.all(published: false) }

    # The editor on the line: the caller's BBS::Auth::Identity when it has
    # the blogger role, else +nil+ (a reader).
    def user = role?(:blogger) ? identity : nil

    # What the caller may read: everything for an editor, the published
    # posts for a reader (nil and true, as PostService#all takes them).
    def shown = user ? nil : true

    def readable?(post) = post && (user || post.published?)

    def draft_tag = wide? ? 'unpublished' : 'u'

    def wide? = screen.cols >= 60

    def right = user ? "#{user.name} " : "#{posts.total(published: true)} posts "

    # The drafts of new posts waiting, as " (2 drafts)"; empty for none.
    def drafts_note
      n = posts.drafts.size
      n.zero? ? '' : " #{GR}(#{n} draft#{'s' unless n == 1})#{LG}"
    end

    # A post by its number, the one the web shows beside it.
    def go_to
      title('GO TO POST', right)
      say('The number of a post, as the web shows it. Return alone: back.', color: GR)
      id = number('post #', 1.., max: 4)
      return unless id
      return show(id) if readable?(posts.find(id))

      alert("No post number #{id}.")
    end

    def browse_categories
      label = lambda do |c|
        about = wide? && !c.about.empty? ? " #{GR}#{c.about}#{LG}" : ''
        "#{c.name} #{GR}(#{posts.count(c.id, published: shown)})#{LG}#{about}"
      end
      each_pick('CATEGORIES', categories.all, empty: 'no categories are configured.', right: right, label: label) do |c|
        browse(c.name.upcase) { posts.all(category: c.id, published: shown) }
      end
    end

    # The posts the block lists, listed again after one was changed.
    def browse(heading, &list)
      found = list.call
      loop do
        post = pick(heading, found, empty: 'no posts here yet.', right: right) { |p| headline(p) }
        break unless post

        found = list.call if show(post.id)
      end
    end

    def headline(post)
      tag   = wide? ? " #{CY}#{categories.find(post.category).name}#{LG}" : ''
      draft = post.published? ? '' : "#{RD}#{draft_tag}#{LG} "
      "#{GR}#{post.created_at.localtime.strftime(wide? ? '%Y-%m-%d' : '%m-%d')}#{LG} #{draft}#{post.title}#{tag}"
    end

    # The post paged; an editor gets to edit or delete it after its last
    # page. True when it was changed or deleted.
    def show(id)
      post = posts.find(id)
      return false unless readable?(post)

      page(categories.find(post.category).name.upcase, post_lines(post), right: right, wait: false, room: 2)
      unless user
        show_qr(post) if reader_choice == 'c'
        return false
      end

      case post_choice(post)
      when 'c' then show_qr(post)
      when 'e' then compose(post)
      when 'p' then publish?(post, !post.published?)
      when 'd' then delete?(post)
      else false
      end
    end

    # The QR code of the post's web page in the middle of the screen, until
    # a key. Returns nil.
    def show_qr(post)
      title('SCAN THE ADDRESS', right)
      pause if qr(board.post_url(post))
      nil
    end

    def post_lines(post) = PostPage.lines(categories, post, screen, long_dates: wide?)

    # Publishes the post, or takes it back to the editors. True when changed.
    def publish?(post, published)
      question = published ? "Publish \"#{post.title}\" on the web and to the readers?" : "Take \"#{post.title}\" back?"
      return false unless confirm?(question)

      posts.set_published(post.id, published)
      notice(published ? 'Published.' : 'Unpublished: only the editors see it now.')
      true
    end

    def delete?(post)
      return false unless confirm?("Delete \"#{post.title}\" for good?")

      posts.delete(post.id)
      notice('Deleted.')
      true
    end
  end
end
