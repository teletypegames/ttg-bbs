# frozen_string_literal: true

module Discovery
  # The telnet side of a probe, with fixed answers (TTG_DISCOVERY.md §5.1):
  # DO TTYPE gets WILL TTYPE and the terminal type ANSI, DO NAWS gets WILL
  # NAWS and 80×25, any other DO gets WONT and any WILL gets DONT; WONT and
  # DONT get nothing (we never turned anything on). Every option the board
  # asks for or offers is kept as "DO TTYPE", "WILL ECHO", ….
  class TelnetNegotiator
    IAC  = 255
    DONT = 254
    DO   = 253
    WONT = 252
    WILL = 251
    SB   = 250
    SE   = 240
    TTYPE = 24
    NAWS  = 31
    TTYPE_SEND = 1
    TTYPE_IS   = 0
    TERMINAL = 'ANSI'
    COLUMNS  = 80
    ROWS     = 25
    VERBS = { DO => 'DO', DONT => 'DONT', WILL => 'WILL', WONT => 'WONT' }.freeze
    NAMES = { 0 => 'BINARY', 1 => 'ECHO', 3 => 'SGA', 5 => 'STATUS', 6 => 'TM', 24 => 'TTYPE', 31 => 'NAWS',
              32 => 'TSPEED', 33 => 'LFLOW', 34 => 'LINEMODE', 35 => 'XDISPLOC', 36 => 'ENVIRON',
              39 => 'NEW-ENVIRON', 42 => 'CHARSET', 44 => 'COM-PORT', 46 => 'STARTTLS', 69 => 'MSDP',
              70 => 'MSSP', 85 => 'COMPRESS', 86 => 'COMPRESS2', 201 => 'GMCP' }.freeze

    attr_reader :options

    def initialize
      @state    = :data
      @verb     = nil
      @sub      = +''.b
      @options  = []
      @answered = {}
    end

    # Feeds +bytes+ from the board; returns [data, reply]: the bytes that are
    # not telnet commands, and the bytes to send back.
    def feed(bytes)
      data  = +''.b
      reply = +''.b
      bytes.to_s.each_byte do |c|
        case @state
        when :data
          if c == IAC then @state = :iac
          else data << c
          end
        when :iac then iac(c, data)
        when :option then option(c, reply)
        when :sb then @sub << c if (@state = c == IAC ? :sb_iac : :sb) == :sb
        when :sb_iac then sb_iac(c, reply)
        end
      end
      [data, reply]
    end

    def self.name(code) = NAMES.fetch(code, code.to_s)

    private

    def iac(c, data)
      @state = :data
      case c
      when IAC then data << IAC
      when DO, DONT, WILL, WONT then @verb = c
                                     @state = :option
      when SB then @sub = +''.b
                   @state = :sb
      end
    end

    def option(c, reply)
      @state = :data
      label = "#{VERBS[@verb]} #{self.class.name(c)}"
      @options << label unless @options.include?(label)
      return if @answered[[@verb, c]]

      @answered[[@verb, c]] = true
      case @verb
      when DO then do_option(c, reply)
      when WILL then reply << [IAC, DONT, c].pack('C*')
      end
    end

    def do_option(c, reply)
      reply << case c
               when TTYPE then [IAC, WILL, TTYPE].pack('C*')
               when NAWS then [IAC, WILL, NAWS, IAC, SB, NAWS, 0, COLUMNS, 0, ROWS, IAC, SE].pack('C*')
               else [IAC, WONT, c].pack('C*')
               end
    end

    def sb_iac(c, reply)
      if c == SE
        @state = :data
        reply << [IAC, SB, TTYPE, TTYPE_IS].pack('C*') << TERMINAL << [IAC, SE].pack('C*') if @sub.bytes.first(2) == [TTYPE,
                                                                                                                      TTYPE_SEND]
      else
        @sub << c if c == IAC
        @state = :sb
      end
    end
  end
end
