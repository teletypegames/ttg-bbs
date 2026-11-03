# frozen_string_literal: true

module UI
  module Modern
    # A BBS::Part whose windows belong to a part of the board: the ones
    # declared in <tt>section :messages do … end</tt> wear its colour on
    # their frame (Accent) and its sign before their title (Icon).
    module Section
      include BBS::Part

      def section(name)
        @section = name
        yield
      ensure
        @section = nil
      end

      def window(name, type, &block)
        section = @section
        return super unless section

        super do
          Section.dress(self, section)
          instance_eval(&block)
        end
      end

      # The accent and the title sign of +section+ on the BBS::WindowSpec +spec+.
      def self.dress(spec, section)
        sign = Icon::SIGNS.fetch(section)
        spec.accent Accent::STYLES.fetch(section)
        spec.define_singleton_method(:title) do |text = nil, &dynamic|
          super(dynamic ? proc { "#{sign} #{instance_exec(&dynamic)}" } : "#{sign} #{text}")
        end
      end
    end
  end
end
