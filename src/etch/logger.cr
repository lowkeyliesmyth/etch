require "./level"
require "./formatter"
require "./time"
require "./value"
require "./error"
require "./options"

module Etch
  # A mutable, structured logger with levels.
  #
  # Config properties mutate in place. `#with_` methods return new independent logger instances instead.
  #
  # Every level method captures the callsite through `__file` / `__line` default args.
  class Logger
    property output : IO
    property level : Level
    property prefix : String
    property time_format : String
    property time_function : TimeFunction
    property formatter : Formatter
    property caller_formatter : CallerFormatter?
    property? report_timestamp : Bool
    property? report_caller : Bool
    property fields : Fields

    # Build a logger with configurations mirroring `Options`. *output* defaults to `STDERR`.
    #
    # Enum properties accept symbol shorthand. eg `level: :debug`
    def initialize(
      @output : IO = STDERR,
      @level : Level = Level::Info,
      @prefix : String = "",
      @time_format : String = TimeFormat::DEFAULT,
      @time_function : TimeFunction = ->(t : Time) { t },
      @report_timestamp : Bool = false,
      @report_caller : Bool = false,
      @caller_formatter : CallerFormatter? = nil,
      @formatter : Formatter = Formatter::Text,
      @fields : Fields = Fields.new,
    )
      @mutex = Mutex.new
    end

    # Whether a record at *level* would be emitted.
    def enabled?(level : Level) : Bool
      level >= @level
    end

    # Returns a new, unique logger instance carrying this logger's configuration along with the given *kv* key-value fields appended.
    #
    # The original parent is not modified.
    def with(**kv) : Logger
      copy_with(prefix: @prefix, fields: @fields + to_fields(kv))
    end

    # Makes an independent logger copy with *prefix* populated, sharing all other config properties state.
    def with_prefix(prefix : String) : Logger
      copy_with(prefix: prefix, fields: @fields.dup)
    end

    # Emits a log event.
    #
    # Optionally accepts *timestamp* from caller. Default nil *timestamp* vends an event write timestamp of now.
    def emit(
      level : Level,
      msg,
      fields : Fields = Fields.new,
      *,
      timestamp : Time? = nil,
      file : String = __FILE__,
      line : Int32 = __LINE__,
    ) : Nil
      return unless enabled?(level)
      handle(level, msg, fields, timestamp, file, line)
    end

    # Emits *msg* at *level* with the given *kv* fields.
    #
    # Omits *msg* when *level* is filtered out by `#level`.
    def log(level : Level, msg, __file : String = __FILE__, __line : Int32 = __LINE__, **kv) : Nil
      return unless enabled?(level)
      emit(level, msg, to_fields(kv), file: __file, line: __line)
    end

    # Emits specifically formatted `sprintf(format, *args)` at *level*.
    #
    # Omits when *level* is filtered out by `#level`
    def logf(level : Level, format : String, *args, __file : String = __FILE__, __line : Int32 = __LINE__) : Nil
      return unless enabled?(level)
      emit(level, sprintf(format, *args), Fields.new, file: __file, line: __line)
    end

    # Generate the same group of methods for the four non-fatal standard levels.
    {% for name, level in {debug: "Debug", info: "Info", warn: "Warn", error: "Error"} %}
      # Emits *msg* at the {{name.id}} level with the given *kv* fields.
      def {{name.id}}(msg, __file : String = __FILE__, __line : Int32 = __LINE__, **kv) : Nil
        return unless enabled?(Level::{{level.id}})
        emit(Level::{{level.id}}, msg, to_fields(kv), file: __file, line: __line)
      end

      # Emits the blocks value at the {{name.id}} level with the given *kv* fields.
      #
      # Block is evaluated only when the level is enabled.
      def {{name.id}}(__file : String = __FILE__, __line : Int32 = __LINE__, **kv, &) : Nil
        return unless enabled?(Level::{{level.id}})
        emit(Level::{{level.id}}, yield, to_fields(kv), file: __file, line: __line)
      end

      # Emits specifically formatted `sprintf(format, *args)` at the {{name.id}} level
      def {{name.id}}f(format : String, *args, __file : String = __FILE__, __line : Int32 = __LINE__) : Nil
        return unless enabled?(Level::{{level.id}})
        emit(Level::{{level.id}}, sprintf(format, *args), Fields.new, file: __file, line: __line)
      end
    {% end %}

    # Emits a fatal level *msg*, then raises `FatalError`.
    def fatal(msg, __file : String = __FILE__, __line : Int32 = __LINE__, **kv) : NoReturn
      emit_fatal(msg, to_fields(kv), __file, __line)
    end

    # Emits the block's value at the fatal level, then raises `FatalError`.
    def fatal(__file : String = __FILE__, __line : Int32 = __LINE__, **kv, &) : NoReturn
      emit_fatal(yield, to_fields(kv), __file, __line)
    end

    # Emits specifically formatted `sprintf(format, *args)` at the fatal level, then raises `FatalError`.
    def fatalf(format : String, *args, __file : String = __FILE__, __line : Int32 = __LINE__) : Nil
      emit_fatal(sprintf(format, *args), Fields.new, __file, __line)
    end

    # Emits *msg* with no level label, ignoring any configured level.
    def print(msg, __file : String = __FILE__, __line : Int32 = __LINE__, **kv) : Nil
      emit(Level::None, msg, to_fields(kv), file: __file, line: __line)
    end

    # Emits the block's value with no level label, ignoring any configured level.
    def print(__file : String = __FILE__, __line : Int32 = __LINE__, **kv, &) : Nil
      emit(Level::None, yield, to_fields(kv), file: __file, line: __line)
    end

    # Emits specifically formatted `sprintf(format, *args)` with no level label, ignoring any configured level.
    def printf(format : String, *args, __file : String = __FILE__, __line : Int32 = __LINE__) : Nil
      emit(Level::None, sprintf(format, *args), Fields.new, file: __file, line: __line)
    end

    # Emits a fatal event only if fatal is enabled.
    #
    # Always raises.
    private def emit_fatal(msg, fields : Fields, file : String, line : Int32) : NoReturn
      emit(Level::Fatal, msg, fields, file: file, line: line) if enabled?(Level::Fatal)
      raise FatalError.new(msg.to_s, fields)
    end

    # Assembles the Logger k-v list in structured order, renders it, and writes it out in a concurrency-safe way.
    #
    # Stores raw `Time` and `Level` values for the formatter to appropriately.
    private def handle(level : Level, msg, call_fields : Fields, timestamp : Time?, file : String, line : Int32) : Nil
      kvs = Fields.new

      kvs << {TIMESTAMP_KEY, @time_function.call(timestamp || Time.local).as(Value)} if @report_timestamp
      kvs << {LEVEL_KEY, level.as(Value)} unless level.none?

      if @report_caller
        formatter = @caller_formatter || SHORT_CALLER_FORMATTER
        kvs << {CALLER_KEY, formatter.call(file, line, "").as(Value)}
      end

      kvs << {PREFIX_KEY, @prefix.as(Value)} unless @prefix.empty?
      kvs << {MESSAGE_KEY, msg.to_s.as(Value)} unless msg.to_s.empty?
      kvs.concat(@fields)
      kvs.concat(call_fields)

      line_out = render(kvs)
      @mutex.synchronize do
        @output << line_out
        @output.flush
      end
    end

    # Renders *kvs* as a single unstyled text line.
    #
    # TODO: Simple now. Fully featured implementation later.
    private def render(kvs : Fields) : String # ameba:disable Metrics/CyclomaticComplexity
      String.build do |io|
        rest = Fields.new
        leading = false

        kvs.each do |(key, value)|
          case key
          when TIMESTAMP_KEY
            io << ' ' if leading
            io << value.as(Time).to_s(@time_format)
            leading = true
          when CALLER_KEY
            io << ' ' if leading
            io << value
            leading = true
          when LEVEL_KEY
            io << ' ' if leading
            io << level_label(value.as(Level))
            leading = true
          when PREFIX_KEY
            io << ' ' if leading
            io << value << ':'
            leading = true
          when MESSAGE_KEY
            io << ' ' if leading
            io << value
            leading = true
          else
            rest << {key, value}
          end
        end
        rest.each { |(key, value)| io << ' ' << key << '=' << value }
        io << '\n'
      end
    end

    # Returns the log entry's 4-char uppercase level label (eg "INFO")
    private def level_label(level : Level) : String
      level.to_s.upcase[0, 4]
    end

    # Converts the callsite named-tuple *kv* into `Fields`. Each value is coerced into a valid Value type.
    private def to_fields(kv) : Fields
      fields = Fields.new(kv.size)
      kv.each do |key, value|
        fields << {key.to_s, Etch.coerce_value(value)}
      end
      fields
    end

    private def copy_with(prefix : String, fields : Fields) : Logger
      Logger.new(
        output: @output,
        level: @level,
        prefix: prefix,
        time_format: @time_format,
        time_function: @time_function,
        report_timestamp: @report_timestamp,
        report_caller: @report_caller,
        caller_formatter: @caller_formatter,
        formatter: @formatter,
        fields: fields,
      )
    end
  end
end
