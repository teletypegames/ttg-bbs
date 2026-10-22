# frozen_string_literal: true

FtpEntry = Struct.new(:name, :path, :bytes, :modified, :dir, keyword_init: true)
