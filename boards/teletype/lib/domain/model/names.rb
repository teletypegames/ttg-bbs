# frozen_string_literal: true

# How the board compares callers' names. A name is one account in any
# case (its key), and two names that look the same on a screen share a
# skeleton: "Tasi" and "Tаsi" with a Cyrillic а, or "TASl" with an l (a
# caller types the case of the name they show, so I, i, l and 1 are one).
module Names
  # Letters of other scripts that a terminal draws like a Latin one, and
  # the digits that pass for letters.
  LOOK_ALIKES = {
    'а' => 'a',
    'в' => 'b',
    'е' => 'e',
    'ё' => 'e',
    'к' => 'k',
    'м' => 'm',
    'н' => 'h',
    'о' => 'o',
    'р' => 'p',
    'с' => 'c',
    'т' => 't',
    'у' => 'y',
    'х' => 'x',
    'ѕ' => 's',
    'і' => 'l',
    'ї' => 'l',
    'ј' => 'j',
    'һ' => 'h',
    'ԁ' => 'd',
    'ԛ' => 'q',
    'ԝ' => 'w',
    'ӏ' => 'l',
    'ү' => 'y',
    'ɡ' => 'g',
    'α' => 'a',
    'β' => 'b',
    'ε' => 'e',
    'ζ' => 'z',
    'η' => 'n',
    'ι' => 'l',
    'κ' => 'k',
    'μ' => 'm',
    'ν' => 'v',
    'ο' => 'o',
    'ρ' => 'p',
    'τ' => 't',
    'υ' => 'u',
    'χ' => 'x',
    'ϲ' => 'c',
    'ı' => 'l',
    '0' => 'o',
    '1' => 'l',
    '|' => 'l',
    'i' => 'l'
  }.freeze
  LOOK_ALIKE = Regexp.union(LOOK_ALIKES.keys)

  module_function

  # The account a name belongs to, whatever its case.
  def key(name) = name.to_s.strip.downcase

  # What +name+ looks like: NFKC, case folded, the look-alikes mapped to
  # the Latin letter they pass for.
  def skeleton(name)
    name.to_s.unicode_normalize(:nfkc).downcase(:fold).gsub(LOOK_ALIKE, LOOK_ALIKES)
  end
end
