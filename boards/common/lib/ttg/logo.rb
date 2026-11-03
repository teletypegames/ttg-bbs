# frozen_string_literal: true

module TTG
  # The Teletype Games logo (TTG over TELETYPE GAMES, green, white and
  # grey) as two BBS::Art drawings made from the same pixels, the logo
  # halved to 66 × 46: for a modern terminal 66 × 23 half blocks in 256
  # colours (<tt>logo/modern.yml</tt>), for a C64 33 × 23 quarter blocks in
  # its own colours, a colour a cell (<tt>logo/c64.yml</tt>).
  module Logo
    # The folder of the drawings.
    DIR = File.join(__dir__, 'logo')
    # The file of each face's drawing.
    FILES = { modern: 'modern.yml', petscii: 'c64.yml' }.freeze

    # The drawing for +face+, +:modern+ or +:petscii+: a BBS::Art, loaded
    # once. Raises KeyError for another face.
    def self.art(face)
      @arts ||= {}
      @arts[face] ||= BBS::Art.load(File.join(DIR, FILES.fetch(face)))
    end

    # The logo as a BBS::Splash, for BBS::Terminal.flow: centred, PRESS ANY
    # KEY TO CONTINUE under it.
    def self.splash = @splash ||= BBS::Splash.new(modern: art(:modern), petscii: art(:petscii))
  end
end
