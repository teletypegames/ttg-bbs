# frozen_string_literal: true

module UI
  class Board < BBS::Petscii::Face
    # Writing a post: the fields one after the other for a new one, then a
    # menu of fields until it is saved or left. The body is Markdown, typed
    # in a line editor with slash commands, which a C64 can type as well as a
    # modern terminal.
    #
    # What is written is kept as a draft (PostService#autosave): after every
    # field, every few seconds in the editor, and when the caller hangs up.
    # The draft is made at the first change, so a look leaves nothing behind.
    # Saving writes it into its post; quitting keeps it for later or throws
    # it away. A post with drafts, and a new post while there are drafts of
    # new posts, starts from a list of them.
    module Composer
      ERRORS = {
        no_title:     'The post needs a title.',
        long_title:   "The title is longer than #{PostService::MAX_TITLE} characters.",
        long_summary: "The summary is longer than #{PostService::MAX_SUMMARY} characters.",
        long_body:    'The body is too long.',
        bad_category: 'Pick a category from the list.',
        gone:         'The post or its draft is gone: another editor deleted or saved it.',
        not_saved:    'The post could not be saved. Try again later.'
      }.freeze

      # What a composer works on: the draft's +id+ (nil until the first
      # change), the +original+ post (nil for a new one), the +fields+ as
      # they stand, the fields last +kept+ in the draft, and whether this
      # call +touched+ the draft.
      Work = Struct.new(:id, :original, :fields, :kept, :touched)

      private

      # A new post, or +post+ edited. True when saved.
      def compose(post = nil)
        start = choose_draft(post)
        work  = start && (start == :fresh ? fresh_work(post) : resumed_work(start, post))
        return false unless work

        loop do
          choice = draft_choice(work.fields, post)
          return true if choice == 'w' && save?(work)
          return false if choice == 'q' && leave?(work)

          change(work, choice)
        end
      rescue *BBS::LINE_DROPPED
        keep(work) if work
        raise
      end

      # :fresh, a draft to go on with, or nil to go back. Without drafts,
      # :fresh at once.
      def choose_draft(post)
        loop do
          drafts = posts.drafts(post)
          return :fresh if drafts.empty?

          choice = pick(post ? "EDIT POST #{post.id}" : 'NEW POST', [:fresh, *drafts], right: right,
                        item_commands: { 'd' => 'discard' }) { |d| draft_label(d, post) }
          return choice unless choice.is_a?(Array)

          discard_draft(choice.last)
        end
      end

      def draft_label(draft, post)
        return post ? 'the post as it is now' : 'start a new post' if draft == :fresh

        title = draft.title.empty? ? "#{GR}(no title)#{LG}" : draft.title
        lines = wide? ? " #{GR}#{draft.body.lines.size} lines#{LG}" : ''
        "#{GR}#{draft.updated_at.localtime.strftime('%m-%d %H:%M')}#{LG} #{CY}#{draft.author}#{LG} #{title}#{lines}"
      end

      def discard_draft(draft)
        return if draft == :fresh
        return unless confirm?("Throw away the draft of #{draft.updated_at.localtime.strftime('%m-%d %H:%M')}?")

        posts.discard(draft.id)
      end

      def fresh_work(post)
        return new_work unless post

        fields = { title: post.title, summary: post.summary, body: post.body, category: post.category }
        Work.new(nil, post, fields, fields.dup, false)
      end

      def resumed_work(draft, post)
        fields = { title: draft.title, summary: draft.summary, body: draft.body, category: draft.category }
        Work.new(draft.id, post, fields, fields.dup, false)
      end

      # A new post asked field by field; kept from the category on. Nil when
      # the caller quit before.
      def new_work
        title = ask_title('')
        return nil unless title

        category = pick_category
        return nil unless category

        work = Work.new(nil, nil, { title: title, summary: '', body: '', category: category }, nil, false)
        keep(work)
        ask_summary(work)
        edit_body(work)
        work
      end

      # The field of +key+ asked again; a field the caller quit stays.
      def change(work, key)
        case key
        when 't' then work.fields[:title] = ask_title(work.fields[:title]) || work.fields[:title]
        when 'c' then work.fields[:category] = pick_category || work.fields[:category]
        when 's' then ask_summary(work)
        when 'b' then edit_body(work)
        when 'v' then preview(work.fields)
        end
        keep(work)
      end

      # Keeps the fields in the draft when they changed since the last time
      # (or always, with +force+), making the draft the first time.
      def keep(work, force: false)
        return if work.fields == work.kept && !(force && work.id.nil?)

        id = posts.autosave(work.id, author: user, face: face_name, original: work.original, **work.fields)
        return unless id

        work.id      = id
        work.kept    = work.fields.dup
        work.touched = true
      end

      def dirty?(work) = work.touched || work.fields != work.kept

      # The draft on its screen and the key of the caller's choice.
      def draft_choice(draft, post)
        draft_screen(draft, post)
        choose("\r\n #{WH}edit#{LG}> ", %w[t c s b v w q])
      end

      def draft_screen(draft, post)
        title(post ? "EDIT POST #{post.id}" : 'NEW POST', right)
        field('T', 'title', draft[:title])
        field('C', 'category', categories.find(draft[:category]).name)
        field('S', 'summary', draft[:summary].empty? ? '-' : draft[:summary])
        field('B', 'body', "#{draft[:body].lines.size} lines")
        puts
        puts " #{YE}V#{LG} view  #{YE}W#{LG} save  #{YE}Q#{LG} quit"
      end

      def field(key, name, value)
        puts " #{YE}#{key}#{LG} #{GR}#{name}#{LG}"
        wrap(value, screen.width - 3).first(3).each { |l| puts "    #{l}" }
      end

      # The title in a field, the current one to start from. Nil when the
      # caller quit or left it empty.
      def ask_title(current)
        title('TITLE', right)
        prompt('title', hint: "Up to #{PostService::MAX_TITLE} characters. Return alone or Stop: back.", text: current,
                        max: PostService::MAX_TITLE)
      end

      # The summary in the editor, autosaved; the one before when the
      # caller quit.
      def ask_summary(work)
        in_editor(work, :summary, title: 'SUMMARY', single_line: true, max: PostService::MAX_SUMMARY, &:strip)
      end

      def pick_category
        pick('CATEGORY', categories.all, empty: 'no categories are configured.', right: right, &:name)&.id
      end

      # The body in the editor, in Markdown, autosaved; the one before when
      # the caller quit.
      def edit_body(work) = in_editor(work, :body, title: 'BODY (MARKDOWN)', max: PostService::MAX_BODY, &:rstrip)

      # Field +name+ of the work in the editor, kept every autosave_seconds
      # while it changes; +tidy+ trims what the editor gives back. When the
      # caller quits, the field and the draft go back to what they were.
      def in_editor(work, name, **options, &tidy)
        before = work.fields[name]
        text   = edit(before.to_s, autosave: board.autosave_seconds, **options) do |typed|
          work.fields[name] = tidy.call(typed)
          keep(work)
        end
        work.fields[name] = text.nil? ? before : tidy.call(text)
        keep(work)
      end

      def preview(draft)
        post = PostModel.new(id: 0, slug: '', **draft, author: user.name, face: face_name, status: 'published',
                             original_id: nil, base_updated_at: nil, published_at: nil, created_at: Time.now,
                             updated_at: Time.now)
        page('PREVIEW', post_lines(post), right: right)
      end

      # Saves the draft into its post; on a conflict, after asking. True
      # when saved; the draft stays when not.
      def save?(work)
        keep(work, force: true)
        result = work.id ? posts.commit(work.id) : :not_saved
        result = posts.commit(work.id, force: true) if result == :conflict && overwrite?(work.original)
        return false if result == :conflict
        if result.is_a?(Symbol)
          alert(ERRORS.fetch(result, 'The post could not be saved.'))
          return false
        end
        notice(work.original ? 'Saved.' : saved_new(result))
        true
      end

      def overwrite?(post)
        saved = posts.find(post.id)
        at    = saved ? saved.updated_at.localtime.strftime('%H:%M') : '?'
        confirm?("Another editor saved this post at #{at}, after you began. Overwrite it with yours?")
      end

      def saved_new(post)
        "Saved as number #{post.id}, unpublished: only the editors see it. Open it and press P to publish it."
      end

      # Whether to leave the composer: at once when nothing was written,
      # else with the draft kept for later or thrown away.
      def leave?(work)
        return true unless dirty?(work)

        case leave_choice
        when 'k' then keep(work)
        when 'd' then posts.discard(work.id) if work.id
        else return false
        end
        true
      end

      def leave_choice
        puts
        choose(" #{YE}K#{LG} keep the draft  #{YE}D#{LG} discard it  #{DG}return: back#{LG} ", ['k', 'd', :enter])
      end
    end
  end
end
