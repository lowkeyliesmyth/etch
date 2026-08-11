module Etch
  # Quoting and escaping rules for rendered field values.
  module Escape
    # Whether or not *value* contains an unfriendly character (eg whitespace, `=`, quotes, etc.) and has to be wrapped when rendered.
    def self.needs_quoting?(value : String) : Bool
      value.each_char do |chr|
        case chr
        when '"', '=', Char::REPLACEMENT
          return true
        else
          return true if chr.whitespace? || !chr.printable?
        end
      end
      false
    end

    # Rewrites unprintable *value* runes as escape sequences, optionally escaping doublequotes (*escape_quotes*).
    #
    # Returns *value* untouched if it doesn't actually need escaping.
    def self.escape(value : String, escape_quotes : Bool = false) : String
      return value unless needs_escaping?(value)
      String.build(value.bytesize) do |io|
        value.each_char do |chr|
          if escape_quotes && chr == '"'
            io << "\\\""
          elsif chr.printable?
            io << chr
          else
            io << sequence_for(chr)
          end
        end
      end
    end

    # Whether or not *value* holds something the escaper would rewrite.
    private def self.needs_escaping?(value : String) : Bool
      value.each_char.any? do |chr|
        !chr.printable? || chr == '"'
      end
    end

    # The escape sequence for a single unprintable *char*.
    private def self.sequence_for(chr : Char) : String
      case chr
      when '\a' then "\\a"
      when '\b' then "\\b"
      when '\f' then "\\f"
      when '\n' then "\\n"
      when '\r' then "\\r"
      when '\t' then "\\t"
      when '\v' then "\\v"
        # low control chars with a codepoint under 0x20 (space) get hex escape like `\xNN`
      when .< ' ' then "\\x#{hex(chr, 2)}"
        # chars that fit in the Basic Multilingual Plan at most )xFFF get hex escapes like `\uNNNN`
      when .<= '\uFFFF' then "\\u#{hex(chr, 4)}"
        # larger chars above 0xFFFF like emojis or extra-plane characters get hex escapes like `\UNNNNNNNN`
      else "\\U#{hex(chr, 8)}"
      end
    end

    # Lowercase, *width* zero-padded hex for *char*'s codepoint
    private def self.hex(chr : Char, width : Int32) : String
      chr.ord.to_s(16).rjust(width, '0')
    end
  end
end
