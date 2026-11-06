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
    boot do
      cls
      print 'MARGITTAI WORKS — Neumatronic system firmware', delay: 0.3
      print 'ROM v7.7   (c) 1977-2026   Budapest', newline: 2, delay: 0.3

      # First architecture: the digital, von Neumann side.
      print 'FIRST ARCHITECTURE   (digital)',                           delay: 0.25
      print '  Core unit ................ Neumann core, dual bus',      delay: 0.2
      memtest 16_384, step: 4096, delay: 0.05, label: '  Base memory ............. '
      print '', delay: 0.2

      # Second architecture: the ACP, hung off the ADI-76 bus.
      print 'SECOND ARCHITECTURE  (analog — ACP)',                      delay: 0.3
      print '  ADI-76 bus ............... OK',                          delay: 0.25
      print '  Lapis-ACP card ........... warming up',                  delay: 0.45
      print '  Sonus resonance .......... stable',                      delay: 0.3
      print '  Vox speech module ........ ready',                       delay: 0.25
      print '  Netz link ................ terminal mode', newline: 2, delay: 0.4

      print 'Personal Tape: PERSONA//GUEST', delay: 0.3
      print 'Local authentication cache loaded  (BVK: disconnected)', newline: 2, delay: 0.5

      print 'Loading SERMO...', newline: 2, delay: 0.8

      cls
      big_banner 'SERMO', font: 'standard'
      print 'SERMO — "the Word"   dual-architecture operating system',   delay: 0.1
      print 'Margittai Works / Neumatronic · Solus line · 1977-2026',    delay: 0.1
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
      io.puts 'SERMO — "the Word"'
      io.puts 'Dual-architecture operating system · Solus line'
      io.puts 'Margittai Works / Neumatronic · Budapest · 1977-2026'
    end

    command 'cls', 'clear', help: 'Clear the screen' do |_args, io|
      io.cls
    end

    command 'date', help: 'Show the current date' do |_args, io|
      io.puts Time.now.strftime('Current date: %Y-%m-%d')
    end

    command 'time', help: 'Show the current time' do |_args, io|
      io.puts Time.now.strftime('Current time: %H:%M:%S')
    end

    command 'say', 'echo', help: 'Speak a message (Vox)' do |args, io|
      io.puts(args.empty? ? 'The Vox module is ready.  (SAY <text>)' : args)
    end

    command 'mem', help: 'Memory and ACP status' do |_args, io|
      io.puts 'FIRST ARCHITECTURE   (digital):'
      io.puts '       655 360 bytes base memory, all free'
      io.puts '    15 728 640 bytes extended memory'
      io.puts 'SECOND ARCHITECTURE  (ACP):'
      io.puts '    Lapis resonance cache ............ 98% warm'
      io.puts '    Sonus quartz ..................... stable'
    end

    command 'dir', 'cat', help: 'Catalog of the Personal Tape' do |_args, io|
      io.puts ' Volume C: is the Personal Tape'
      io.puts ' Contents of C:\\'
      io.puts ''
      io.puts 'SERMO    SYS        54 645  1977-2026'
      io.puts 'LAPIS    ACP        12 080  1977-2026   (ACP image)'
      io.puts 'VOX      SYS           512  1977-2026'
      io.puts 'PERSONA  TAP         8 192  today        (personal tape)'
      io.puts 'NETZ     LOG           256  today'
      io.puts '        5 entries       75 685 bytes'
      io.puts '                   503 312 384 bytes free'
    end

    command 'adi', help: 'ADI-76 bus diagnostics' do |_args, io|
      io.puts 'ADI-76 bus — diagnostics'
      io.puts '  Bridge .............. active'
      io.puts '  Lapis-ACP ........... connected, warm'
      io.puts '  Sonus resonance ..... stable'
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
