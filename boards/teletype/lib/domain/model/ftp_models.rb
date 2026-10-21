# frozen_string_literal: true

FtpEntry = Struct.new(:name, :bytes, :modified, :dir, keyword_init: true)
FtpApp   = Struct.new(:folder, :title, :version, :platform, :description, :files, keyword_init: true)
