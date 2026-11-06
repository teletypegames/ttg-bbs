# frozen_string_literal: true

# TTG BBS: every board of the network in one container, each in a process of
# its own (Rubbs::MultiRunner). A board is a folder of boards/ with a bbs.rb;
# boards.yml gives its port, callers and memory. BBS_BOARDS=feedia,wiki runs
# only those.
require 'rubbs'
require 'ttg/common'
require 'rexml/document'

runner = Rubbs::MultiRunner.new(root: 'boards', settings: 'boards.yml', name: 'ttg-bbs')
runner.run!
