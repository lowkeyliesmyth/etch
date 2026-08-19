require "log"
require "./logger"

module Etch
  # Converts stdlib `Log` entries into Etch compatible events via the rendering pipeline.
  #
  # Entry-specific source data and context metadata are applied without modifying the single mutable `Logger` the backend owns.
  #
  # Etch has a smaller level set than stdlib, so stdlib levels are autoconverted to be Etch compatible.
  class Backend < ::Log::Backend
    @logger : Logger

    # Builds a backend with the same config accepted by stdlib `Logger.new`.
    #
    # *dispatch_mode* controls stdlib delivery and defaults to async mode.
    # Note that *report_caller* must remain set to false and is rejected, because a `Log::Entry` doesn't have a valid line+file caller location.
    def initialize(
      output : IO = STDERR,
      *,
      dispatch_mode : ::Log::DispatchMode = ::Log::DispatchMode::Async,
      level : Level = Level::Info,
      prefix : String = "",
      time_format : String = TimeFormat::DEFAULT,
      time_function : TimeFunction = ->(time : Time) { time },
      report_timestamp : Bool = false,
      report_caller : Bool = false,
      caller_formatter : CallerFormatter? = nil,
      formatter : Formatter = Formatter::Text,
      fields : Fields = Fields.new,
      styles : Styles = Styles.default,
      env : Foundation::Env = Foundation::LiveEnv.new,
      renderer : Sheen::Renderer? = nil,
    )
      if report_caller
        raise ArgumentError.new(
          "Log::Entry has no caller location. Reporting callers is not supported."
        )
      end

      super(dispatch_mode)
      @logger = Logger.new(
        output: output,
        level: level,
        prefix: prefix,
        time_format: time_format,
        time_function: time_function,
        report_timestamp: report_timestamp,
        report_caller: report_caller,
        caller_formatter: caller_formatter,
        formatter: formatter,
        fields: fields,
        styles: styles,
        env: env,
        renderer: renderer,
      )
    end

    # Translates *entry* into an Etch compatible form and passes it through the logger.
    #
    # Original *entry* timestamps are preserved even when stdlib dispatch is set to async.
    def write(entry : ::Log::Entry) : Nil
      fields = metadata_fields(entry.data)
      fields.concat(metadata_fields(entry.context))

      if exception = entry.exception
        fields << {"exception", exception.as(Value)}
      end

      logger = entry.source.empty? ? @logger : @logger.with_prefix(entry.source)
      logger.emit(
        level_for(entry.severity),
        entry.message,
        fields,
        timestamp: entry.timestamp,
      )
    end

    # Unwraps and converts stdtlib *metadata* into Etch compatible fields
    private def metadata_fields(metadata : ::Log::Metadata) : Fields
      Etch.coerce_fields(
        metadata.map { |k, v| {k.to_s, v.raw} }
      )
    end

    # Maps stdlib's larger *severity* count into Etch's smaller level set.
    private def level_for(severity : ::Log::Severity) : Level
      case severity
      in ::Log::Severity::Trace
        Level::Debug
      in ::Log::Severity::Debug
        Level::Debug
      in ::Log::Severity::Info
        Level::Info
      in ::Log::Severity::Notice
        Level::Warn
      in ::Log::Severity::Warn
        Level::Warn
      in ::Log::Severity::Error
        Level::Error
      in ::Log::Severity::Fatal
        Level::Fatal
      in ::Log::Severity::None
        Level::None
      end
    end
  end
end
