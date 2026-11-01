# frozen_string_literal: true

module Discovery
  # The first screen of a stored banner, for the preview of the board page
  # (TTG_DISCOVERY.md §8.2, D6). The bytes are a stranger's, so only what
  # draws goes through: text, CR, LF, TAB, and the CSI sequences of colour,
  # cursor movement and erasing. Titles, OSC and DCS strings, modes and every
  # other escape are dropped.
  module BannerPreview
    ROWS = 24
    C64_ROWS = 25
    # The CSI finals let through: SGR, the cursor moves and positions, erase.
    CSI_FINALS = 'mHfABCDGJKsu'
    CSI   = %r{\A\e\[([0-9;]*)([ -/]*)([@-~])}n
    OTHER = %r{\A\e(?:\][^\a\e]*(?:\a|\e\\)?|[P_^X][^\e]*(?:\e\\)?|\[[ -?]*[ -/]*[@-~]?|.)}mn
    CLR = 0x93
    RETURN = 0x0D

    module_function

    # +bytes+ (an ANSI or ASCII banner) as UTF-8 for a modern terminal, up to
    # the end of its first screen: the second clear-screen, or +rows+ lines.
    # CP437 unless the bytes are UTF-8 text.
    def ansi(bytes, rows: ROWS)
      rest = bytes.to_s.b
      out = +''.b
      lines = 0
      until rest.empty? || lines >= rows
        rest, piece = step(rest, out)
        break if piece == :end

        out << piece
        lines += 1 if piece == "\n"
      end
      decode(out.delete("\x7F"))
    end

    # [what is left of +rest+, the piece of it kept]: a CSI that draws, a
    # printable byte, or nothing; :end at the clear-screen after +out+ drew.
    def step(rest, out)
      if (m = CSI.match(rest)) then [m.post_match, csi(m, out)]
      elsif rest.start_with?("\e") then [rest.sub(OTHER, ''), '']
      else [rest.byteslice(1..), printable(rest.getbyte(0))]
      end
    end

    def csi(match, out)
      return '' unless CSI_FINALS.include?(match[3]) && match[2].empty?
      return :end if match[3] == 'J' && match[1] == '2' && visible?(out)

      match[0]
    end

    def printable(byte) = byte >= 0x20 || [0x0A, 0x0D, 0x09].include?(byte) ? byte.chr : ''

    # +bytes+ (a PETSCII banner) up to the end of its first screen: the
    # second CLR after something was drawn, or +rows+ RETURNs. Raw PETSCII.
    def petscii(bytes, rows: C64_ROWS)
      out = +''.b
      returns = 0
      bytes.to_s.b.each_byte do |byte|
        break if byte == CLR && out.bytes.any? { |b| b.between?(0x20, 0x7F) || b >= 0xA0 }

        out << byte
        returns += 1 if byte == RETURN
        break if returns >= rows
      end
      out
    end

    def visible?(out) = out.gsub(/\e\[[0-9;]*[@-~]/n, '').match?(/[^\s]/n)

    def decode(bytes)
      utf8 = bytes.dup.force_encoding(Encoding::UTF_8)
      return utf8 if utf8.valid_encoding?

      bytes.dup.force_encoding(Encoding::IBM437).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    end
  end
end
