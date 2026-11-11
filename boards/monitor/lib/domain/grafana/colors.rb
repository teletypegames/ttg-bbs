# frozen_string_literal: true

module Grafana
  # Grafana's colours as RGB triples ([r, g, b], 0–255): its named colours
  # (+green+, +semi-dark-red+ …), <tt>#rrggbb</tt>, <tt>rgb(…)</tt>, and the
  # classic palette the series take in turn.
  module Colors
    # The named colours of Grafana's palette.
    NAMED = {
      'green'              => '73BF69',
      'dark-green'         => '37872D',
      'semi-dark-green'    => '56A64B',
      'light-green'        => '96D98D',
      'super-light-green'  => 'C8F2C2',
      'red'                => 'F2495C',
      'dark-red'           => 'C4162A',
      'semi-dark-red'      => 'E02F44',
      'light-red'          => 'FF7383',
      'super-light-red'    => 'FFA6B0',
      'orange'             => 'FF9830',
      'dark-orange'        => 'FA6400',
      'semi-dark-orange'   => 'FF780A',
      'light-orange'       => 'FFB357',
      'super-light-orange' => 'FFCB7D',
      'yellow'             => 'FADE2A',
      'dark-yellow'        => 'E0B400',
      'semi-dark-yellow'   => 'F2CC0C',
      'light-yellow'       => 'FFEE52',
      'super-light-yellow' => 'FFF899',
      'blue'               => '5794F2',
      'dark-blue'          => '1F60C4',
      'semi-dark-blue'     => '3274D9',
      'light-blue'         => '8AB8FF',
      'super-light-blue'   => 'C0D8FF',
      'purple'             => 'B877D9',
      'dark-purple'        => '8F3BB8',
      'semi-dark-purple'   => 'A352CC',
      'light-purple'       => 'CA95E5',
      'super-light-purple' => 'DEB6F2',
      'white'              => 'FFFFFF',
      'black'              => '000000',
      'gray'               => '808080',
      'grey'               => '808080'
    }.freeze
    # The colours series take in turn (palette-classic).
    CLASSIC = %w[
      7EB26D EAB839 6ED0E0 EF843C E24D42 1F78C1 BA43A9 705DA0 508642 CCA300 447EBC C15C17 890F02 0A437C 6D1F62 584477
    ].freeze

    module_function

    # The RGB triple of a Grafana colour +name+, or +nil+ (+text+,
    # +transparent+, or a colour it cannot read).
    def rgb(name)
      text = name.to_s.strip.downcase
      hex  = NAMED[text] || text[/\A#?(\h{6})\z/, 1] || short(text)
      return [hex[0, 2], hex[2, 2], hex[4, 2]].map { |part| part.to_i(16) } if hex

      numbers = text.match(/\Argba?\((\d+)\D+(\d+)\D+(\d+)/)
      numbers&.captures&.map(&:to_i)
    end

    # A three-digit #rgb as six digits.
    def short(text)
      digits = text[/\A#(\h{3})\z/, 1]
      digits&.chars&.map { |c| c * 2 }&.join
    end

    # The classic palette's colour +index+.
    def classic(index) = rgb(CLASSIC[index % CLASSIC.size])
  end
end
