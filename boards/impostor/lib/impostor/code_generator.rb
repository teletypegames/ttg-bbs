# frozen_string_literal: true

module Impostor
  module CodeGenerator
    SALT     = 27_471
    BASE36   = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    NAME_LEN = 3

    SALTS = [
      SALT % 36,
      (SALT / 36) % 36,
      (SALT / 1296) % 36
    ].freeze

    def self.decrypt(encrypted_text)
      t = encrypted_text.to_s.upcase
      return '???' if t.length != NAME_LEN * 2
      result = +''
      NAME_LEN.times do |i|
        pair = decode_pair(t[i * 2, 2])
        result << ((pair % 26) + 65).chr
      end
      result
    end

    def self.encrypt(text)
      result = +''
      NAME_LEN.times do |i|
        c = [(text.bytes[i] || 65) - 65, 0].max
        n = c + (SALTS[i] * 26)
        result << BASE36[(n / 36).floor] << BASE36[n % 36]
      end
      result
    end

    def self.decode_pair(s)
      d1 = BASE36.index(s[0].upcase)
      d2 = BASE36.index(s[1].upcase)
      return 0 if d1.nil? || d2.nil?
      (d1 * 36) + d2
    end
    private_class_method :decode_pair
  end
end
