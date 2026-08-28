require "./level"
require "./formatter"
require "./time"
require "./value"
require "./styles"

module Etch
  # Applied to each log timestamp before formatting to allow customizing timestamp transformation.
  # eg `->(t : Time) { t.to_utc }` to force UTC
  alias TimeFunction = Proc(Time, Time)

  # Formats a caller annotation from the captured `(file, line, function)`.
  # Function name is always ""
  alias CallerFormatter = Proc(String, Int32, String, String)

  # Returns the last two path segments of *file* joined to *line*. eg "etch/logger.cr:42").
  SHORT_CALLER_FORMATTER = CallerFormatter.new do |file, line, _fn|
    segments = file.split('/')
    short = segments.size <= 2 ? file : segments.last(2).join('/')
    "#{short}:#{line}"
  end
  # Returns the entire path of *file* joined to *line*.
  LONG_CALLER_FORMATTER = CallerFormatter.new do |file, line, _fn|
    "#{file}:#{line}"
  end

  # Immutable options configuration for a `Logger`. Every field is defaultable but can only be set at construction time.
  private struct Options
    getter time_function : TimeFunction
    getter time_format : String
    getter level : Level
    getter prefix : String
    getter? report_timestamp : Bool
    getter? report_caller : Bool
    getter caller_formatter : CallerFormatter?
    getter fields : Fields
    getter formatter : Formatter
    getter styles : Styles

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
      @styles : Styles = Styles.default,
    )
    end

    # Options snapshotter takes a point in time snapshot of the current Logger's Options fields, so children receive a duplicate instead of mutating the original.
    def with(
      *,
      time_function : TimeFunction = @time_function,
      time_format : String = @time_format,
      level : Level = @level,
      prefix : String = @prefix,
      report_timestamp : Bool = @report_timestamp,
      report_caller : Bool = @report_caller,
      caller_formatter : CallerFormatter? = @caller_formatter,
      fields : Fields = @fields,
      formatter : Formatter = @formatter,
      styles : Styles = @styles,
    ) : self
      self.class.new(
        time_function: time_function,
        time_format: time_format,
        level: level,
        prefix: prefix,
        report_timestamp: report_timestamp,
        report_caller: report_caller,
        caller_formatter: caller_formatter,
        fields: fields,
        formatter: formatter,
        styles: styles,
      )
    end
  end
end
