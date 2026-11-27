# frozen_string_literal: true

require 'rubbs'
require 'time'
require_relative 'oracle'

module Sermo
  # SERMO — "the Word": the dual-architecture operating system of the
  # Neumatronic universe. Pretend you sat down at a Margittai personal machine,
  # watched its dual-architecture firmware come up, and landed at a
  # green-phosphor prompt. (Canon: Alternative History — Margittai writes Sermo
  # in 1977; "black screen, green phosphor letters, a single blinking input
  # line".)
  #
  # The world's central rule lives in one prompt: a *literal* command goes to
  # the digital side (first architecture, von Neumann) and is served by the
  # built-in commands; a *natural-language* request crosses the ADI-76 bus to
  # the Lapis-ACP (the second, analog-cognitive architecture) — handed off by
  # the `on_unknown` hook to Sermo::Oracle (the conversational core).
  #
  # This whole OS is data: to add another character-mode OS later (an earlier
  # Sermo line, a DOS/NT terminal, …), write a new Rubbs::Common::FakeOS.define block in
  # its own file — no engine changes needed.
  # Today's month and day in 1977, the year the machine lives in (a 29 February, which 1977
  # had not, is the 28th).
  def self.today(at = Time.now)
    day = at.month == 2 && at.day == 29 ? 28 : at.day
    format('1977-%<month>02d-%<day>02d', month: at.month, day: day)
  end

  OS = Rubbs::Common::FakeOS.define do
    name   'SERMO'
    prompt '> '

    # Classic black-and-green phosphor CRT — the canonical Solus/Sermo palette
    # (see OS_SCREENSHOTS "Solus"): phosphor green for text, a dimmer green for
    # the ACP's voice, a rare amber for warnings.
    colors text:   :green,                       # phosphor green
           bright: { fg: :green, bold: true },   # bright highlight green
           accent: { fg: :green, bold: true },   # banner
           error:  { fg: :yellow, bold: true },  # rare amber warning
           dim:    { fg: :green, faint: true },  # dim green — the ACP's voice
           prompt: { fg: :green, bold: true }

    # ── Dual-architecture power-on → SERMO load ─────────────────────────────────
    # A Kvartet of 1977 (the canon's first desk "dual machine"): a digital terminal and a Lapis
    # crystal board on the ADI-76 bus, the system on a cassette, the board's trained state on a
    # Lux plate. Nothing of later years: no Sonus, no Personal Tape, no disk drives, no megabytes.
    boot do
      cls
      print 'MARGITTAI INSTITUTE — Kvartet firmware', delay: 0.3
      print 'ROM 1.0   (c) 1977   Budapest', newline: 2, delay: 0.3

      # First architecture: the digital, von Neumann side.
      print 'FIRST ARCHITECTURE   (digital)',                           delay: 0.25
      print '  Core unit ................ Neumann core',                delay: 0.2
      memtest 32, step: 4, delay: 0.05, label: '  Core memory ............. '
      print '', delay: 0.2

      # Second architecture: the ACP, hung off the ADI-76 bus.
      print 'SECOND ARCHITECTURE  (analog — ACP)',                      delay: 0.3
      print '  ADI-76 bus ............... OK',                          delay: 0.25
      print '  Lapis board .............. warming up',                  delay: 0.45
      print '  Vox speech module ........ ready',                       delay: 0.25
      print '  Line ..................... remote terminal', newline: 2, delay: 0.4

      print 'Cassette: SERMO SYSTEM TAPE', delay: 0.3
      print 'Lux plate: LAPIS, trained state', newline: 2, delay: 0.5

      print 'Loading SERMO...', newline: 2, delay: 0.8

      cls
      big_banner 'SERMO', font: 'standard'
      print 'SERMO — "the Word"   dual-architecture operating system',   delay: 0.1
      print 'Margittai Institute · Kvartet · 1977',                      delay: 0.1
      print ''
    end

    # Runs once, after boot, before the first prompt.
    ready do
      puts 'Type a command — or just ask a question, and the machine answers.'
      puts 'A literal command goes to the digital side; a natural-language'
      puts 'request crosses the ADI-76 bus to the Lapis-ACP. HELP = command list.'
      puts ''
    end

    # ── Digital side: literal, built-in commands ────────────────────────────────
    command 'ver', help: 'Show the SERMO version' do |_args, io|
      io.puts 'SERMO — "the Word"   version 1.0'
      io.puts 'Dual-architecture operating system for the Kvartet'
      io.puts 'Margittai Institute · Budapest · 1977'
    end

    command 'cls', 'clear', help: 'Clear the screen' do |_args, io|
      io.cls
    end

    command 'date', help: 'Show the current date' do |_args, io|
      io.puts "Current date: #{Sermo.today}"
    end

    command 'time', help: 'Show the current time' do |_args, io|
      io.puts Time.now.strftime('Current time: %H:%M:%S')
    end

    command 'say', 'echo', help: 'Speak a message (Vox)' do |args, io|
      io.puts(args.empty? ? 'The Vox module is ready.  (SAY <text>)' : args)
    end

    command 'mem', help: 'Memory and ACP status' do |_args, io|
      io.puts 'FIRST ARCHITECTURE   (digital):'
      io.puts '    32 768 bytes core memory, 26 624 free'
      io.puts 'SECOND ARCHITECTURE  (ACP):'
      io.puts '    Lapis board ...................... warm'
      io.puts '    Lux plate ........................ read'
    end

    command 'dir', 'cat', help: 'Catalog of the cassette' do |_args, io|
      io.puts ' Cassette: SERMO SYSTEM TAPE, side A'
      io.puts ''
      io.puts 'SERMO    SYS     6 144  1977'
      io.puts 'VOX      SYS       512  1977'
      io.puts "GUEST    DAT       256  #{Sermo.today}"
      io.puts '        3 files   6 912 bytes, 23 K free on the side'
      io.puts ''
      io.puts ' The Lapis board reads its trained state from the Lux plate:'
      io.puts ' that is the Stone itself, not a file.'
    end

    command 'adi', help: 'ADI-76 bus diagnostics' do |_args, io|
      io.puts 'ADI-76 bus — diagnostics'
      io.puts '  Bridge .............. active'
      io.puts '  Lapis board ......... connected, warm'
      io.puts '  Throughput .......... nominal'
      io.puts ''
      io.puts 'Your natural-language questions reach the ACP over this bus.'
    end

    command 'vox', help: 'Vox speech module status' do |_args, io|
      io.puts 'Vox speech module: ready  (speech → text).'
      io.puts 'You can also just type your questions — Vox only converts voice input.'
    end

    command 'help', '?', help: 'Show this help' do |_args, io|
      io.puts 'Digital side — literal commands:'
      io.puts ''
      io.puts '  VER    DATE    TIME   SAY     MEM'
      io.puts '  DIR    ADI     VOX    CLS     EXIT'
      io.puts ''
      io.puts 'Anything else you type is treated as a natural-language request and'
      io.puts 'crosses the ADI-76 bus to the Lapis-ACP — just ask.'
    end

    command 'exit', 'quit', 'logoff', help: 'Hang up the line' do |_args, io|
      io.puts 'Hanging up the line. Goodbye, guest.'
      io.halt
    end

    # ── Analog side: everything else goes to the Lapis-ACP ──────────────────────
    # Anything that is not a literal command is a natural-language request: we
    # hand it over the ADI-76 bus to the Lapis-ACP's conversational core
    # (Sermo::Oracle). The reply is dim green, prefixed "ACP:" — exactly like
    # the canonical Solus screen. The reply is typed out as the ACP thinks it,
    # word-wrapped to the caller's terminal under the prefix.
    on_unknown do |input, io|
      io.newline
      out = Rubbs::Common::AI::Typewriter.new(io, prefix: 'ACP: ', style: :dim)
      Sermo::Oracle.answer(input, io.ctx) { |piece| out.write(piece) }
      out.finish
    end
  end
end
