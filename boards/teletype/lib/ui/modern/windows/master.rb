# frozen_string_literal: true

module UI
  module Modern
    module Windows
      # Help > Ask the TTG Master: the sysop who answers callers' questions.
      module Master
        MASTER_GREETING = 'Hey, caller! I am the sysop of this board. Ask me where things are, what is new, what is coming up.'

        extend Section

        section :help do
          # The TTG Master answers in a thread of his own and the window
          # picks the reply up on its next tick, so the board never waits
          # for the model.
          window :master, :stream do
            title       'Ask the TTG Master'
            placeholder 'Ask about the board and press Enter…'
            lines do
              ask_master(replies, question) if question
              Formatters::Master.lines('TTG Master', MASTER_GREETING, cols)
            end
            on_submit { |text| ask_master(replies, text.strip) }
            on_poll   { Array.new(replies.size) { replies.pop } }
          end
        end

        helpers do
          def open_master(question = nil) = show(:master, replies: Queue.new, question: question)

          def ask_master(replies, question)
            Formatters::Master.lines('You', question, cols, you: true).each { |line| replies << line }
            return master_says(replies, 'One question at a time, caller.', cols) if context[:master_busy]

            context[:master_busy] = true
            width = cols
            Thread.new do
              master_says(replies, master.answer(question, context), width)
            rescue StandardError => e
              Rubbs.log('TTG Master', e)
            ensure
              context[:master_busy] = false
            end
          end

          def master_says(replies, text, width)
            Formatters::Master.lines('TTG Master', text, width).each { |line| replies << line }
          end
        end
      end
    end
  end
end
