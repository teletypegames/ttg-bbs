# frozen_string_literal: true

module BBS
  class Flow
    attr_reader :steps

    def self.define(&block)
      flow = new
      flow.instance_eval(&block)
      flow.freeze
    end

    def initialize
      @steps = []
    end

    def screen(name)
      @steps << { type: :screen, name: name }
    end

    def say(text, style: :muted)
      @steps << { type: :say, text: text, style: style }
    end

    def ask(name, prompt:, transform: nil, validate: nil)
      @steps << { type: :ask, name: name, prompt: prompt,
                  transform: transform, validate: validate }
    end

    def persist(*fields)
      @steps << { type: :persist, fields: fields.flatten }
    end

    def pause(message, seconds: 1.0)
      @steps << { type: :pause, message: message, seconds: seconds }
    end

    # Halts the flow unless the block returns truthy.
    def gate(denied:, &check)
      @steps << { type: :gate, check: check, denied: denied }
    end

    # Without block: halts if the user answers no.
    # With block:    runs the block if yes, skips it (with optional message) if no.
    def confirm(message, denied: nil, &block)
      step = { message: message, denied: denied }
      if block_given?
        sub = Flow.new
        sub.instance_eval(&block)
        @steps << step.merge(type: :confirm_block, sub_steps: sub.steps)
      else
        @steps << step.merge(type: :confirm_halt)
      end
    end
  end
end
