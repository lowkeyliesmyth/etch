require "./formatter"
require "./level"
require "./styles"
require "./value"
require "./escape"

module Etch
  # Renders a log record's fields as one styled, human readable line.
  #
  # Is re-built on every render call so it always sees the logger's most current styles, renderer, and time format.
  struct TextFormatter
    # Sits between a field key and its value
    SEPARATOR = "="

    # Prefixes every line of a multiline field value
    INDENT_SEPARATOR = "  │ "

    # Stands in as a nil-field placeholder
    NIL_VALUE = "<nil>"

    def initialize(@styles : Styles, @renderer : Sheen::Renderer, @time_format : String)
    end

    # Renders *kvs* on a single line with a newline appended.
    def render(kvs : Fields) : String
      String.build do |io|
        # track if any field has actually been written to the output io so far during the loop so we can correctly allocate the spacing.
        wrote = false
        kvs.each_with_index do |(key, value), index|
          emitted = write_pair(io, key, value, first: !wrote, more_keys: index < kvs.size - 1)
          wrote ||= emitted
        end
        io << '\n'
      end
    end

    # Writes one *key*-*value* pair, returning whether it emitted anything.
    #
    # A  pair whose *value* is the wrong type for the reserved key is skipped.
    private def write_pair(io : IO, key : String, value : Value, first : Bool, more_keys : Bool) : Bool
      case key
      when TIMESTAMP_KEY then write_timestamp(io, value, first)
      when LEVEL_KEY     then write_level(io, value, first)
      when CALLER_KEY    then write_caller(io, value, first)
      when PREFIX_KEY    then write_prefix(io, value, first)
      when MESSAGE_KEY   then write_message(io, value, first)
      else                    write_field(io, key, value, first, more_keys)
      end
    end

    # Writes the timestamp after formatting through the logger's `time_format`.
    private def write_timestamp(io : IO, value : Value, first : Bool) : Bool
      return false unless time = value.as?(Time)
      space(io, first)
      io << bind(@styles.timestamp).render(time.to_s(@time_format))
      true
    end

    # Writes the level label *value* to *io*.
    # *first* indicates if a separating space is needed.
    # Returns false and writes nothing when silenced or if *value* isn't a level.
    private def write_level(io : IO, value : Value, first : Bool) : Bool
      return false unless level = value.as?(Level)
      return false unless level_style = @styles.levels[level]?
      label = bind(level_style).to_s
      return false if label.empty?
      space(io, first)
      io << label
      true
    end

    # Writes the caller annotation  *value* to *io*, presented as `<file:line>`.
    # *first* indicates if a separating space is needed.
    private def write_caller(io : IO, value : Value, first : Bool) : Bool
      return false unless caller = value.as?(String)
      space(io, first)
      io << bind(@styles.caller).render("<#{caller}>")
      true
    end

    # Writes the prefix *value* to *io*, always carrying a trailing colon.
    # *first* indicates if a separating space is needed.
    private def write_prefix(io : IO, value : Value, first : Bool) : Bool
      return false unless prefix = value.as?(String)
      space(io, first)
      io << bind(@styles.prefix).render("#{prefix}:")
      true
    end

    # Writes the log message *value* to *io*.
    # *first* indicates if a separating space is needed.
    private def write_message(io : IO, value : Value, first : Bool) : Bool
      return false if value.nil?
      space(io, first)
      io << bind(@styles.message).render(value.to_s)
      true
    end

    # Writes a user field *key*=*value to *io*. Empty keys are dropped and not rendered.
    #
    # Values are quoted, escaped, or indented as required to render safely.
    private def write_field(io : IO, key : String, value : Value, first : Bool, more_keys : Bool) : Bool
      return false if key.empty?

      text = plain(value)
      raw = text.empty?
      text = %("") if raw

      styled_key = bind(@styles.keys[key]? || @styles.key).render(key)
      value_style = @styles.values[key]? || @styles.value
      separator = bind(@styles.separator)

      if text.includes?('\n')
        io << "\n  " << styled_key << separator.render(SEPARATOR) << '\n'
        write_indent(io, text, separator.render(INDENT_SEPARATOR), more_keys, key)
      elsif !raw && Escape.needs_quoting?(text)
        space(io, first)
        io << styled_key << separator.render(SEPARATOR)
        io << bind(value_style).render(%("#{Escape.escape(text, escape_quotes: true)}"))
      else
        space(io, first)
        io << styled_key << separator.render(SEPARATOR) << bind(value_style).render(text)
      end
      true
    end

    # Writes a multiline *text* to *io*, prefixing every line with *indent*.
    #
    # Closes with a newline only when we know more kv pairs follow since `#render` closes out the final one.
    private def write_indent(io : IO, text : String, indent : String, more_keys : Bool, key : String) : Nil
      value_style = bind(@styles.values[key]? || @styles.value)
      lines = text.split('\n')
      last = lines.size - 1
      lines.each_with_index do |line, index|
        if index == last
          next if line.empty?
          io << indent << value_style.render(Escape.escape(line))
          io << '\n' if more_keys
        else
          io << indent << value_style.render(Escape.escape(line))
          io << '\n'
        end
      end
    end

    # The unstyled text form of a field *value*, before quoting or escaping.
    private def plain(value : Value) : String
      value.nil? ? NIL_VALUE : value.to_s
    end

    # Writes to *io* the separating space between pairs.
    private def space(io : IO, first : Bool) : Nil
      io << ' ' unless first
    end

    # Binds *style* to this formatter's renderer so colors resolve against the real output.
    private def bind(style : Sheen::Style) : Sheen::Style
      style.renderer(@renderer)
    end
  end
end
