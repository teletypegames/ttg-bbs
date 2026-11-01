# frozen_string_literal: true

module Discovery
  # The bytes of a downloaded list as UTF-8 text: UTF-8 when they are valid
  # UTF-8, else the code page of the list (CP437 for the FTN nodelists and
  # SyncTERM, Latin-1 for HTML).
  module TextDecoder
    module_function

    def decode(bytes, fallback: Encoding::IBM437)
      text = bytes.to_s.dup.force_encoding(Encoding::UTF_8)
      return text.delete_prefix('﻿') if text.valid_encoding?

      bytes.to_s.dup.force_encoding(fallback).encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: '?')
    end
  end
end
