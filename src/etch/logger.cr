require "./level"
require "./formatter"
require "./time"
require "./options"

module Etch
  # A mutable, structured logger with levels.
  #
  # Config properties mutate in place.
  # `#with_` methods return new independent logger instances instead.
  class Logger
    property output : IO
    property level : Level
    property prefix : String
    property time_format : String
    property time_function : TimeFunction
    property formatter : Formatter
    property caller_formatter : CallerFormatter?
    property caller_offset : Int32
    property? report_timestamp : Bool
    property? report_caller : Bool
    getter fields : Array(Tuple(String, String))

    # Build a logger with configurations mirroring `Options`. *output* defaults to `STDERR`.
    def initialize(
      @output : IO = STDERR,
      @level : Level = Level::Info,
      @prefix : String = "",
      @time_format : String = TimeFormat::DEFAULT,
      @time_function : TimeFunction = ->(t : Time) { t },
      @report_timestamp : Bool = false,
      @report_caller : Bool = false,
      @caller_formatter : CallerFormatter? = nil,
      @caller_offset : Int32 = 0,
      @formatter : Formatter = Formatter::Text,
      @fields : Array(Tuple(String, String)) = [] of Tuple(String, String),
    )
    end

    # Returns a new, unique logger instance carrying this logger's configuration along with the given *kv* key-value fields appended.
    #
    # The original parent is not modified.
    def with(**kv) : Logger
      appended = @fields.dup
      kv.each { |k, v| appended << {k.to_s, v.to_s} }
      copy_with(prefix: @prefix, fields: appended)
    end

    # Makes an independent logger copy with *prefix* populated, sharing all other config properties state.
    def with_prefix(prefix : String) : Logger
      copy_with(prefix: prefix, fields: @fields.dup)
    end

    private def copy_with(prefix : String, fields : Array(Tuple(String, String))) : Logger
      Logger.new(
        output: @output,
        level: @level,
        prefix: prefix,
        time_format: @time_format,
        time_function: @time_function,
        report_timestamp: @report_timestamp,
        report_caller: @report_caller,
        caller_formatter: @caller_formatter,
        caller_offset: @caller_offset,
        formatter: @formatter,
        fields: fields,
      )
    end
  end
end
