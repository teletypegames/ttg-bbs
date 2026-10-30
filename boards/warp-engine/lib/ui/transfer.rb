# frozen_string_literal: true

module UI
  # The download protocols of both faces, and what to tell the caller
  # before and after a transfer. The caller's terminal must receive with
  # the same protocol: XMODEM carries no file name, so the terminal asks
  # for one.
  module Transfer
    PROTOCOLS = { zmodem: 'ZMODEM', xmodem_1k: 'XMODEM-1K', xmodem: 'XMODEM' }.freeze

    def self.label(protocol) = PROTOCOLS.fetch(protocol)

    # Sends +data+ as +title+'s file over +session+ by +protocol+; :ok,
    # :cancelled, :timeout or :hangup.
    def self.send_file(session, protocol, title, data)
      case protocol
      when :zmodem    then BBS::Zmodem.send_files(session, [[title.file, data]])
      when :xmodem_1k then BBS::Xmodem.send_file(session, data, one_k: true)
      else BBS::Xmodem.send_file(session, data)
      end
    end

    def self.start(protocol, title)
      if protocol == :zmodem
        "Sending #{title.file} (#{title.size} bytes) by ZMODEM. Most terminals start the download by themselves; " \
          'Esc gives up.'
      else
        "Start an #{label(protocol)} download in your terminal now and save it as #{title.disk_name}. " \
          'The board waits a minute for it; Esc or RUN/STOP gives up.'
      end
    end

    # What a fetch that gave no bytes means, for the caller.
    def self.refusal(reason, title)
      case reason
      when :too_big then "#{title.file} is too big for a download on this line."
      when :changed then "#{title.file} has just been updated on the archive. Read the shelf again and pick it anew."
      else 'The archive did not answer. Try again later.'
      end
    end

    def self.result(result, protocol, title)
      case result
      when :ok
        if protocol == :zmodem
          "#{title.file} went over, byte for byte."
        else
          "#{title.file} went over. #{label(protocol)} fills its last block up, so the file can be longer by up to " \
            "#{protocol == :xmodem_1k ? 1023 : 127} bytes; a Commodore loads it all the same."
        end
      when :cancelled then 'The download was cancelled.'
      when :timeout then "Your terminal did not take the file by #{label(protocol)} in time."
      else 'The line dropped.'
      end
    end
  end
end
