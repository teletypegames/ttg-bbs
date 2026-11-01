# frozen_string_literal: true

module UI
  class Board
    # Writing a post: the fields one after the other for a new one, then a
    # menu of fields until it is saved or dropped. The body is Markdown, typed
    # in a line editor with slash commands, which a C64 can type as well as a
    # modern terminal.
    module Composer
      ERRORS = {
        no_title:     'The post needs a title.',
        long_title:   "The title is longer than #{PostService::MAX_TITLE} characters.",
        long_summary: "The summary is longer than #{PostService::MAX_SUMMARY} characters.",
        long_body:    'The body is too long.',
        bad_category: 'Pick a category from the list.',
        not_saved:    'The post could not be saved. Try again later.'
      }.freeze

      private

      # A new post, or +post+ edited. True when saved.
      def compose(post = nil)
        draft = post ? draft_of(post) : new_draft
        return false unless draft

        saved = post ? draft.dup : {}
        loop do
          choice = draft_choice(draft, post)
          return true if choice == 'w' && save?(draft, post)
          return false if choice == 'q' && (draft == saved || drop?)

          change(draft, choice)
        end
      end

      def draft_of(post) = { title: post.title, summary: post.summary, body: post.body, category: post.category }

      def new_draft
        title = ask_title('')
        return nil unless title

        category = pick_category
        return nil unless category

        { title: title, summary: ask_summary(''), body: edit_body('') || '', category: category }
      end

      # The field of +key+ asked again; a field the caller quit stays.
      def change(draft, key)
        case key
        when 't' then keep(draft, :title, ask_title(draft[:title]))
        when 'c' then keep(draft, :category, pick_category)
        when 's' then draft[:summary] = ask_summary(draft[:summary])
        when 'b' then keep(draft, :body, edit_body(draft[:body]))
        when 'v' then preview(draft)
        end
      end

      def keep(draft, field, value)
        draft[field] = value unless value.nil?
      end

      # The draft on its screen and the key of the caller's choice.
      def draft_choice(draft, post)
        draft_screen(draft, post)
        @screen.choose("\r\n #{WH}edit#{LG}> ", %w[t c s b v w q])
      end

      def draft_screen(draft, post)
        @screen.title(post ? "EDIT POST #{post.id}" : 'NEW POST', right)
        field('T', 'title', draft[:title])
        field('C', 'category', @categories.find(draft[:category]).name)
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
        @screen.say("Up to #{PostService::MAX_TITLE} characters. Return alone or Stop: back.", GR)
        @screen.puts
        title = @screen.ask(" #{WH}title#{LG}> ", text: current, max: PostService::MAX_TITLE)
        title.empty? ? nil : title
      end

      # The summary in the editor; the current one when the caller quit.
      def ask_summary(current)
        summary = @screen.edit(current, title: 'SUMMARY', single_line: true, max: PostService::MAX_SUMMARY)
        summary.nil? ? current : summary.strip
      end

      def pick_category
        @screen.pick('CATEGORY', @categories.all, empty: 'no categories are configured.', right: right, &:name)&.id
      end

      # The body in the editor, in Markdown; nil when the caller quit.
      def edit_body(body)
        @screen.edit(body.to_s, title: 'BODY (MARKDOWN)', max: PostService::MAX_BODY)&.rstrip
      end

      def preview(draft)
        post = PostModel.new(id: 0, slug: '', **draft, author: user.name, face: face, published: true,
                              published_at: nil, created_at: Time.now, updated_at: Time.now)
        @screen.page('PREVIEW', post_lines(post), right: right)
      end

      def save?(draft, post)
        result = post ? @posts.update(post.id, **draft) : @posts.create(author: user, face: face, **draft)
        if result.is_a?(Symbol)
          @screen.notice(ERRORS.fetch(result, 'The post could not be saved.'), RD)
          return false
        end
        @screen.notice(post ? 'Saved.' : saved_new(result), GN)
        true
      end

      def saved_new(post)
        "Saved as number #{post.id}, unpublished: only the editors see it. Open it and press P to publish it."
      end

      def drop? = @screen.confirm?('Drop the changes?', RD)
    end
  end
end
