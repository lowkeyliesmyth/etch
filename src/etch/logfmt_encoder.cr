# TLDR; What functionality is in here?

require "./level"
require "./time"
require "./value"

module Etch
  # Encodes k-v pairs as logmt onto an IO.
  #
  # Tokens are written raw when every rune is safe, otherwise are quoted and escaped.
  #
  # One encoder spans a single record through until `#end_record` releases it, tracking if a separating space is needed.
  struct LogfmtEncoder
    # Written bare for a nil value.
    NULL = "null"

    def initialize(@io : IO)
      @needs_separator = false
    end

    # Writes one *key*-*value* pair, with a prepending space added to every pair after the first one.
    #
    # Empty pairs are dropped.
    def encode(key : String, value : Value) : Nil
      safe_key = filter_key(key)
      return if safe_key.empty?

      @io << ' ' if @needs_separator
      @io << safe_key << '='
      write_value(value)
      @needs_separator = true
    end

    # Closes the record with a newline and gets the encoder ready for the next one.
    def end_record : Nil
      @io << '\n'
      @needs_separator = false
    end

    # Drops every rune a logfmt record is unable to hold.
    private def filter_key(key : String) : String
      return key unless key.each_char.any? { |chr| unsafe?(chr) }
      String.build do |io|
        key.each_char do |chr|
          io << chr unless unsafe?(chr)
        end
      end
    end

    # Writes *value* to its logfmt form.
    private def write_value(value : Value) : Nil
      case value
      in Nil       then @io << NULL
      in Bool      then @io << value
      in Int64     then @io << value
      in Float64   then @io << value
      in String    then write_string(value)
      in Time      then write_string(value.to_s(TimeFormat::RFC3339_NANO))
      in Exception then write_string(value.message.to_s)
      in Level     then write_string(value.to_s)
      end
    end

    # Writes *text* to io.
    # Text is bare if every rune is safe for logfmt, otherwise is escaped.
    private def write_string(text : String) : Nil
      if text == NULL || text.each_char.any? { |chr| unsafe?(chr) }
        write_quoted(text)
      else
        @io << text
      end
    end

    # Writes *text* to io wrapped in quotes, escaping as required to be logfmt-safe.
    #
    # Note that the escape range is different than `Etch::Escape`.
    private def write_quoted(text : String) : Nil
      @io << '"'
      text.each_char do |chr|
        case chr
        when Char::REPLACEMENT then @io << "\\ufffd"
        when '\\', '"'         then @io << '\\' << chr
        when '\n'              then @io << "\\n"
        when '\r'              then @io << "\\r"
        when '\t'              then @io << "\\t"
        when '\u{7f}'          then @io << "\\u007f"
          # This always catches me up. Handle any other unescaped control characters below space. Basically "When `chr` is less than codepoint 0x20 (the space char)"
        when .< ' ' then @io << "\\u00" << chr.ord.to_s(16).rjust(2, '0')
        else             @io << chr
        end
      end
      @io << '"'
    end

    # Whether *chr* is unsafe and needs to be quoted.
    private def unsafe?(chr : Char) : Bool
      case chr
      when .<= ' '           then true
      when '=', '"'          then true
      when '\u{7f}'          then true
      when Char::REPLACEMENT then true
      else                        false
      end
    end
  end
end
