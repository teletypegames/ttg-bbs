# frozen_string_literal: true

require_relative 'bbs/code_generator'
require_relative 'bbs/renderer'
require_relative 'bbs/telnet'
require_relative 'bbs/store'
require_relative 'bbs/flow'
require_relative 'bbs/flow_runner'
require_relative 'bbs/session'
require_relative 'bbs/server'
require_relative 'bbs/flows/debrief'

BBS::Server.new(port: (ENV['BBS_PORT'] || 2323).to_i).run
