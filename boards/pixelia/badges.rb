# frozen_string_literal: true

# The badges of Pixelia BBS (TTG::Badges): the gallery and the shared
# canvas. GalleryService reports :piece, CanvasService :paint.
Rubbs.badges :pixelia do
  event :piece, pack: 'the pack', ref: 'the file'
  event :paint

  badge :painter do
    title  'Painter'
    hint   'Paint on the shared canvas of Pixelia BBS on different days: 1, 7.'
    emblem '▒', :purple
    on(:paint).distinct(:date).tiers bronze: 1, silver: 7
  end

  badge :art_lover do
    title  'Art Lover'
    hint   'Look at the art of ten different packs.'
    emblem '░', :yellow
    on(:piece).distinct(:pack).reaches 10
  end
end
