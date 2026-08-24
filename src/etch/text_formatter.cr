require "./formatter"
require "./level"
require "./styles"
require "./record"
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

    # Renders a *record* on a single line with a newline appended.
    def render(record : Record) : String
      String.build do |io|
        # track if any field has actually been written to the output io so far during the loop so we can correctly allocate the spacing.
        wrote = false
        # TODO: Can we improve the performance by avoiding allocating an extra array per Record?
        items = record.to_a
        items.each_with_index do |item, index|
          emitted = write_item(io, item, first: !wrote, more_items: index < items.size - 1)
          wrote ||= emitted
        end

        io << '\n'
      end
    end

    # Writes one semantic Record item, returning whether it emitted anything.
    #
    private def write_item(io : IO, item : Record::Item, first : Bool, more_items : Bool) : Bool
      case item
      in Record::Timestamp
        write_timestamp(io, item.value, first)
      in Record::Severity
        write_level(io, item.value, first)
      in Record::Caller
        write_caller(io, item.value, first)
      in Record::Prefix
        write_prefix(io, item.value, first)
      in Record::Message
        write_message(io, item.value, first)
      in Record::Payload
        write_field(io, item.key, item.value, first, more_items)
      end
    end

    # Writes the timestamp after formatting through the logger's `time_format`.
    private def write_timestamp(io : IO, time : Time, first : Bool) : Bool
      space(io, first)
      io << bind(@styles.timestamp).render(time.to_s(@time_format))
      true
    end

    # Writes the *level* label *io*.
    # *first* indicates if a separating space is needed.
    # Returns false and writes nothing when silenced or if *value* isn't a level.
    private def write_level(io : IO, level : Level, first : Bool) : Bool
      return false unless level_style = @styles.levels[level]?
      label = bind(level_style).to_s
      return false if label.empty?

      space(io, first)
      io << label
      true
    end

    # Writes the *caller* annotation to *io*, presented as `<file:line>`.
    # *first* indicates if a separating space is needed.
    private def write_caller(io : IO, caller : String, first : Bool) : Bool
      space(io, first)
      io << bind(@styles.caller).render("<#{caller}>")
      true
    end

    # Writes the *prefix* to *io*, always carrying a trailing colon.
    # *first* indicates if a separating space is needed.
    private def write_prefix(io : IO, prefix : String, first : Bool) : Bool
      space(io, first)
      io << bind(@styles.prefix).render("#{prefix}:")
      true
    end

    # Writes the log *message* to *io*.
    # *first* indicates if a separating space is needed.
    private def write_message(io : IO, message : String, first : Bool) : Bool
      space(io, first)
      io << bind(@styles.message).render(message)
      true
    end

    # Writes a user field *key*=*value to *io*. Empty keys are dropped and not rendered.
    #
    # Values are quoted, escaped, or indented as required to render safely.
    private def write_field(io : IO, key : String, value : Value, first : Bool, more_items : Bool) : Bool
      return false if key.empty?

      text = plain(value)
      raw = text.empty?
      text = %("") if raw

      styled_key = bind(@styles.keys[key]? || @styles.key).render(key)
      value_style = @styles.values[key]? || @styles.value
      separator = bind(@styles.separator)

      if text.includes?('\n')
        io << "\n  " << styled_key << separator.render(SEPARATOR) << '\n'
        write_indent(io, text, separator.render(INDENT_SEPARATOR), more_items, key)
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
    private def write_indent(io : IO, text : String, indent : String, more_items : Bool, key : String) : Nil
      value_style = bind(@styles.values[key]? || @styles.value)
      lines = text.split('\n')
      last = lines.size - 1
      lines.each_with_index do |line, index|
        if index == last
          next if line.empty?
          io << indent << value_style.render(Escape.escape(line))
          io << '\n' if more_items
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
