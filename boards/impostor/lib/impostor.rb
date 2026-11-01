# frozen_string_literal: true

require 'bbs'
require_relative 'impostor/code_generator'

# The debrief terminal of Definitely not an Impostor as a rubbs flow, with
# two faces: Impostor::Modern for an ANSI terminal and Impostor::Petscii for a
# PETSCII line, each with its own screens. It runs the standalone Impostor
# BBS (bbs.rb), and another rubbs BBS mounts it as a door:
# `door :impostor, Impostor::Modern.flow(sessions: store), label: '&Impostor'`.
module Impostor
  SCREENS = File.expand_path('../screens', __dir__)

  SESSION_HEADERS = %w[session_id timestamp player_name code feedback email].freeze

  # A player name: one to CodeGenerator::NAME_LEN letters A-Z, the letters a
  # personal code is made of. A line that is anything else (a web scanner's
  # GET request, a TLS handshake on the wrong port) is no player.
  NAME = /\A[A-Z]{1,#{CodeGenerator::NAME_LEN}}\z/

  def self.sessions_store(path) = BBS::Store.new(path: path, headers: SESSION_HEADERS)

  # Whether +name+ is a player name (NAME).
  def self.name?(name) = NAME.match?(name.to_s)

  # The flow both faces share; +screens_dir+ holds the face's welcome and
  # congrats screens, +sessions+ keeps what the caller types (anything with
  # BBS::Store's +upsert+).
  def self.debrief(sessions:, screens_dir:)
    identify = identification(sessions)
    options  = debrief_menu(sessions)
    BBS::Flow.define(screens_dir: screens_dir) do
      instance_exec(&identify)
      confirm 'Norman, is that you?', denied: 'Very well. Goodbye.' do
        screen :congrats
        instance_exec(&options)
      end
    end
  end

  # Whether +code+ is the personal code of the player +name+.
  def self.verified?(name, code) = CodeGenerator.decrypt(code) == name.to_s[0, CodeGenerator::NAME_LEN]

  # The steps that ask for the player's name and code and refuse a wrong one.
  def self.identification(sessions)
    proc do
      screen :welcome
      banner 'IDENTITY VERIFICATION', style: :info
      ask :player_name, prompt: 'Player Name', transform: :upcase, validate: Impostor.method(:name?)
      ask :code,        prompt: 'Code'
      persist :player_name, :code, store: sessions
      pause 'Verifying identity...', seconds: 1.2
      gate(denied: 'Access denied. Code mismatch.') { |ctx| Impostor.verified?(ctx[:player_name], ctx[:code]) }
    end
  end

  # The menu after the debrief: feedback, the update list, exit.
  def self.debrief_menu(sessions)
    proc do
      menu '>', loop: true do
        option 'Leave feedback' do
          ask :feedback, prompt: 'Feedback'
          persist :feedback, store: sessions
          say 'Feedback recorded. Thank you.', style: :success
        end
        option 'Subscribe to updates' do
          ask :email, prompt: 'Email address', validate: :email
          persist :email, store: sessions
          say "Perfect. We'll be in touch.", style: :success
        end
        option('Exit') { exit_menu }
      end
    end
  end
  private_class_method :identification, :debrief_menu
end

require_relative 'impostor/modern'
require_relative 'impostor/petscii'
