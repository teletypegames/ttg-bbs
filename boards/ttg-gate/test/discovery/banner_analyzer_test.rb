# frozen_string_literal: true

require_relative 'test_helper'

module Discovery
  class BannerAnalyzerTest < Minitest::Test
    include TestHelper

    def encoding(bytes) = BannerAnalyzer.encoding(bytes.pack('C*'))

    def test_ansi_wins
      assert_equal 'ansi', BannerAnalyzer.encoding("\e[2J\e[1;33mWelcome\r\n".b)
      assert_equal 'ansi', BannerAnalyzer.encoding("\x93\e[0mmixed".b)
    end

    def test_petscii
      assert_equal 'petscii', encoding([0x93, 0x0E, 0x05] + 'WELCOME'.bytes)
      assert_equal 'petscii', encoding([0x8E] + 'hi'.bytes)
      assert_equal 'petscii', encoding('HELLO'.bytes + [0x1C, 0x0D])
      assert_equal 'petscii', encoding('HELLO'.bytes + [0x9E, 0x0D])
    end

    def test_utf8_text_is_not_petscii
      assert_equal 'unknown', BannerAnalyzer.encoding('Üdvözöljük, ½ BBS'.b)
    end

    def test_escape_without_bracket_rules_out_petscii
      assert_equal 'unknown', encoding([0x1B, 0x63, 0x05] + 'x'.bytes)
    end

    def test_atascii
      assert_equal 'atascii', encoding([0x7D] + 'READY'.bytes + [0x9B])
      assert_equal 'atascii', encoding('WELCOME'.bytes + [0x9B])
      assert_equal 'ascii', BannerAnalyzer.encoding("int main() { return 0; }\r\n".b)
    end

    def test_ascii_and_unknown
      assert_equal 'ascii', BannerAnalyzer.encoding("Login: \r\n\tpress ENTER\a".b)
      assert_equal 'unknown', encoding([0xB0, 0xB1, 0xB2] + ' CP437 art'.bytes)
      assert_equal 'unknown', BannerAnalyzer.encoding(''.b)
    end

    def test_form_feed_and_other_plain_text_controls_are_ascii
      assert_equal 'ascii', BannerAnalyzer.encoding("\f\r\npress del/backspace:".b)
      assert_equal 'ascii', BannerAnalyzer.encoding("Welcome\a\b\v\fBBS\r\n\x1A\x1A".b)
      assert_equal 'unknown', BannerAnalyzer.encoding("Welcome\x1Ain the middle".b)
      assert_equal 'petscii', encoding([0x0C, 0x93, 0x05] + 'HELLO'.bytes)
      assert_equal 'ansi', BannerAnalyzer.encoding("\f\e[2JHello".b)
      assert_equal 'atascii', encoding([0x0C] + 'READY'.bytes + [0x9B])
    end

    def test_text_folds_petscii_capitals_and_drops_escapes
      assert_equal ' Synchronet BBS ', BannerAnalyzer.text("\e[1;36mSynchronet\e[0m BBS\r\n".b)
      petscii = [0x93, 0x0E] + 'WELCOME TO '.bytes.map { |c| c.between?(0x41, 0x5A) ? c + 0x80 : c } + 'color 64'.bytes
      assert_equal ' WELCOME TO color 64', BannerAnalyzer.text(petscii.pack('C*'))
      assert_equal ' ', BannerAnalyzer.text([0xC1].pack('C*'), petscii: false)
    end

    def test_digest
      assert_equal 16, BannerAnalyzer.digest('x').size
      assert_nil BannerAnalyzer.digest('')
    end

    SAMPLES = {
      'synchronet' => 'Synchronet BBS for Linux  Version 3.22  Copyright 2026 Rob Swindell',
      'mystic'     => 'Mystic BBS Version 1.12 A48 Copyright (C) 1997-2021',
      'enigma'     => 'ENiGMA½ BBS v0.0.13-beta',
      'wwiv'       => 'WWIV 5.7 - The BBS software',
      'renegade'   => 'Renegade BBS v1.30/DOS',
      'wildcat'    => 'Wildcat! Interactive Net Server',
      'iniquity'   => 'iNiQUiTY BBS Version 3',
      'telegard'   => 'Telegard 3.09.g2-sp4',
      'color64'    => 'WELCOME TO A COLOR 64 BBS',
      'imagebbs'   => 'Image BBS v3.0 for the C64',
      'cnet'       => 'C-Net 128 v6',
      'cbase'      => 'Powered by C*Base 3.2',
      'maximus'    => 'Maximus 3.01',
      'pcboard'    => 'PCBoard (R) v15.4',
      'searchlight' => 'Searchlight BBS 6.0',
      'talisman'   => 'Talisman BBS v0.50',
      'magicka'    => 'Magicka BBS 0.15',
      'citadel'    => 'Citadel/UX 9.01',
      'spitfire'   => 'Spitfire BBS v3.7',
      'wildfire'   => 'Wildfire BBS 1.0',
      'x84'        => 'x/84 bbs',
      'rubbs'      => 'running on rubbs 0.29',
      'ftn-mailer' => "**EMSI_REQA77E\r\x11\r"
    }.freeze

    def test_every_signature_has_a_sample_and_matches_it_first
      assert_equal config.signatures.map(&:id).sort, SAMPLES.keys.sort
      SAMPLES.each do |id, banner|
        text = BannerAnalyzer.text(banner.b)
        assert_equal id, BannerAnalyzer.software(text, config.signatures)&.id, banner
      end
    end

    def test_no_signature_in_plain_words
      ['Welcome! Login:', 'An image of the net', 'Press ENTER for the menu', 'The renegades meet here'].each do |banner|
        assert_nil BannerAnalyzer.software(BannerAnalyzer.text(banner.b), config.signatures), banner
      end
    end
  end
end
