# frozen_string_literal: true

module TTG
  # The Teletype Games logo (TTG over TELETYPE GAMES, green, white and
  # grey) as two BBS::Art drawings made from the same pixels, the logo
  # halved to 66 × 46: for a modern terminal 66 × 23 half blocks in 256
  # colours (<tt>logo/modern.yml</tt>), for a C64 33 × 23 quarter blocks in
  # its own colours, a colour a cell (<tt>logo/c64.yml</tt>). And the
  # mark alone, without TELETYPE GAMES, at a third of the pixels (3 × 3
  # a dot, so the gaps between the letters stay): 44 × 13 half blocks
  # (<tt>logo/mini-modern.yml</tt>) and 22 × 13 quarter blocks
  # (<tt>logo/mini-c64.yml</tt>), over the profile.
  module Logo
    # The folder of the drawings.
    DIR = File.join(__dir__, 'logo')
    # The file of each face's drawing.
    FILES = { modern: 'modern.yml', petscii: 'c64.yml', mini_modern: 'mini-modern.yml', mini_petscii: 'mini-c64.yml' }.freeze

    # The drawing for +face+, +:modern+ or +:petscii+ (or the small mark,
    # +:mini_modern+, +:mini_petscii+): a BBS::Art, loaded once. Raises
    # KeyError for another.
    def self.art(face)
      @arts ||= {}
      @arts[face] ||= BBS::Art.load(File.join(DIR, FILES.fetch(face)))
    end

    # The logo as a BBS::Splash, for BBS::Terminal.flow: centred, PRESS ANY
    # KEY TO CONTINUE under it.
    def self.splash = @splash ||= BBS::Splash.new(modern: art(:modern), petscii: art(:petscii))

    # The look of the caller's profile (BBS::Auth::Profile): the small mark
    # over PROFILE, centred.
    def self.profile
      @profile ||= BBS::Auth::Profile::Look.new(modern: art(:mini_modern), petscii: art(:mini_petscii))
    end
  end
end
