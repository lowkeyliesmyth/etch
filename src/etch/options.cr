require "./level"
require "./formatter"
require "./time"
require "./value"

module Etch
  # Applied to each log timestamp before formatting to allow customizing timestamp transformation.
  # eg `->(t : Time) { t.to_utc }` to force UTC
  alias TimeFunction = Proc(Time, Time)

  # Formats a caller annotation from the captured `(file, line, function)`
  # Function name is always ""
  alias CallerFormatter = Proc(String, Int32, String, String)

  # Returns the last two path segments of *file* joined to *line*. eg "etch/logger.cr:42")
  SHORT_CALLER_FORMATTER = CallerFormatter.new do |file, line, _fn|
    segments = file.split('/')
    short = segments.size <= 2 ? file : segments.last(2).join('/')
    "#{short}:#{line}"
  end
  # Returns the entire path of *file* joined to *line*.
  LONG_CALLER_FORMATTER = CallerFormatter.new do |file, line, _fn|
    "#{file}:#{line}"
  end

  # Construction time config for a `Logger`. Every field is defaultable.
  struct Options
    property time_function : TimeFunction
    property time_format : String
    property level : Level
    property prefix : String
    property? report_timestamp : Bool
    property? report_caller : Bool
    property caller_formatter : CallerFormatter?
    property fields : Fields
    property formatter : Formatter

    def initialize(
      @time_function : TimeFunction = ->(t : Time) { t },
      @time_format : String = TimeFormat::DEFAULT,
      @level : Level = Level::Info,
      @prefix : String = "",
      @report_timestamp : Bool = false,
      @report_caller : Bool = false,
      @caller_formatter : CallerFormatter? = nil,
      @fields : Fields = Fields.new,
      @formatter : Formatter = Formatter::Text,
    )
    end
  end
end
