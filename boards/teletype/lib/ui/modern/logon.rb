# frozen_string_literal: true

module UI
  module Modern
    # The logon sequence of a modern call: who is calling, then the scans of
    # the old boards; any key (or two minutes) goes on to the desktop.
    module Logon
      WAIT = 120

      def self.show(runner, bbs)
        context = runner.context
        summary = bbs.logon_summary(context[:username], registered: context[:authenticated],
                                                        session_id: context[:session_id])
        context[:caller_number] = summary[:caller_number]
        Formatters::Logon.screen(runner, **summary)
        runner.session.readkey(timeout: WAIT)
        nil
      end
    end
  end
end
