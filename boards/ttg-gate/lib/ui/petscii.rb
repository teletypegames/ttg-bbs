# frozen_string_literal: true

require_relative 'colors'
require_relative 'dial'
require_relative 'petscii/screen'
require_relative 'petscii/gate'

module UI
  # TTG Gate BBS on a Commodore 64: raw PETSCII in the graphics set, the
  # frame of UI::Petscii::Gate (the header, the sidebar, the hint bar)
  # around our own boards, Global Discovery's lists and pages and the
  # Sources.
  module Petscii
    @nodes = []
    @nodes_lock = Mutex.new

    def self.flow(bbs)
      BBS::Flow.define do
        call do |_ctx, runner|
          screen = Screen.new(runner.session)
          Petscii.on_node do |node|
            Gate.new(screen, boards: bbs.directory.boards(petscii: true), browse: bbs.browse, dials: bbs.dials,
                             node: node).run
          end
          Petscii.goodbye(screen)
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end

    # Yields the lowest node number no other C64 caller has, for the call.
    def self.on_node
      node = @nodes_lock.synchronize { (1..).find { |n| !@nodes.include?(n) }.tap { |n| @nodes << n } }
      yield node
    ensure
      @nodes_lock.synchronize { @nodes.delete(node) }
    end

    def self.goodbye(screen)
      canvas = Canvas.new
      canvas.text(9, 10, '> LINK SEVERED', Canvas::GREEN)
      canvas.text(10, 10, '> TRACE WIPED', Canvas::GREEN)
      canvas.text(11, 10, '> TTG GATE BBS OFFLINE', Canvas::GREEN)
      canvas.text(13, 10, 'SEE YOU ON THE WIRE', Canvas::DARK_GREY)
      canvas.text(16, 15, 'NO CARRIER', Canvas::LIGHT_GREEN)
      screen.raw(canvas.frame + [Canvas::LOWERCASE].pack('C*'))
      nil
    end
  end
end
