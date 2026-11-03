# frozen_string_literal: true

module UI
  module Modern
    # A list of episodes, of a series or of this day: the codes and titles on
    # the left, the picked one's card on the right; Enter reads its Memory
    # Alpha article.
    module EpisodesWindow
      extend BBS::Part

      window :episodes, :master_detail do
        empty 'No episodes in the catalog.'
        title      { caption }
        list_width { [40, cols * 2 / 5].max }
        items      { entries }
        label      { |(e, s)| years ? "#{e.year} #{s.abbreviation} #{e.label}" : e.label }
        detail     { |(e, s), width| [bright(e.title), '', *card(Card.episode(e, s), width)] }
        meta       { 'Enter reads its Memory Alpha article' }
        on_pick    { |(e, _s)| read_episode(e) }
        action('Read') { |(e, _s)| read_episode(e) }
      end
    end
  end
end
