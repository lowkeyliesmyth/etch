require "../spec_helper"

private def backend_entry(
  severity : Log::Severity,
  message : String,
  *,
  source : String = "",
  data : Log::Metadata = Log::Metadata.empty,
  exception : Exception? = nil,
  timestamp : Time = Time.utc,
) : Log::Entry
  Log::Entry.new(
    source,
    severity,
    message,
    data,
    exception,
    timestamp: timestamp,
  )
end

describe Etch::Backend do
  it "rejects caller reporting because stdlib log entries don't have an actual caller location" do
    expect_raises(ArgumentError) do
      Etch::Backend.new(
        IO::Memory.new,
        dispatch_mode: :direct,
        report_caller: true,
      )
    end
  end

  it "maps the larger stdlib severity onto Etch levels" do
    io = IO::Memory.new
    backend = Etch::Backend.new(
      io,
      dispatch_mode: :direct,
      level: :debug,
      formatter: :logfmt,
    )

    [
      {Log::Severity::Trace, "trace"},
      {Log::Severity::Debug, "debug"},
      {Log::Severity::Info, "info"},
      {Log::Severity::Notice, "notice"},
      {Log::Severity::Warn, "warn"},
      {Log::Severity::Error, "error"},
      {Log::Severity::Fatal, "fatal"},
      {Log::Severity::None, "none"},
    ].each do |severity, message|
      backend.write(backend_entry(severity, message))
    end

    io.to_s.lines.should eq([
      "level=debug msg=trace",
      "level=debug msg=debug",
      "level=info msg=info",
      "level=warn msg=notice",
      "level=warn msg=warn",
      "level=error msg=error",
      "level=fatal msg=fatal",
      "msg=none",
    ])
  end

  it "uses the configured prefix for root entries and source for named entries" do
    io = IO::Memory.new
    backend = Etch::Backend.new(
      io,
      dispatch_mode: :direct,
      formatter: :logfmt,
      prefix: "application",
    )

    backend.write(backend_entry(:info, "root"))
    backend.write(backend_entry(:info, "query", source: "db.query"))

    io.to_s.lines.should eq([
      "level=info prefix=application msg=root",
      "level=info prefix=db.query msg=query",
    ])
  end

  it "appends entry data before ambient context" do
    io = IO::Memory.new
    backend = Etch::Backend.new(
      io,
      dispatch_mode: :direct,
      formatter: :logfmt,
    )

    Log.with_context(scope: "ambient") do
      backend.write(
        backend_entry(
          :info,
          "fields",
          data: Log::Metadata.build({event: 42})
        )
      )
    end

    io.to_s.should eq(
      "level=info msg=fields event=42 scope=ambient\n"
    )
  end

  it "coerces nested metadata into its string representation" do
    io = IO::Memory.new
    backend = Etch::Backend.new(
      io,
      dispatch_mode: :direct,
      formatter: :json,
    )

    backend.write(
      backend_entry(
        :info,
        "nested",
        data: Log::Metadata.build({
          nested: {"count" => 2},
        }),
      )
    )

    record = JSON.parse(io.to_s)
    record["nested"].as_s.should eq("{\"count\" => 2}")
  end

  it "renders exceptions through Etch's regular field path" do
    io = IO::Memory.new
    backend = Etch::Backend.new(
      io,
      dispatch_mode: :direct,
      formatter: :json,
    )

    backend.write(
      backend_entry(
        :error,
        "failed",
        exception: ArgumentError.new("bruh its broke"),
      )
    )

    record = JSON.parse(io.to_s)
    record["level"].as_s.should eq("error")
    record["exception"].as_s.should eq("bruh its broke")
  end

  it "renders the entry timestamp of the event, not the time of the write" do
    io = IO::Memory.new
    backend = Etch::Backend.new(
      io,
      dispatch_mode: :direct,
      report_timestamp: true,
    )
    timestamp = Time.utc(2025, 1, 2, 3, 4, 5)

    backend.write(
      backend_entry(
        :info,
        "backdated",
        timestamp: timestamp
      )
    )
    io.to_s.should eq(
      "2025/01/02 03:04:05 INFO backdated\n"
    )
  end

  it "emits fatal entries without raising a FatalError" do
    io = IO::Memory.new
    backend = Etch::Backend.new(
      io,
      dispatch_mode: :direct,
      formatter: :logfmt,
    )

    backend.write(backend_entry(:fatal, "shutdown"))
    io.to_s.should eq("level=fatal msg=shutdown\n")
  end

  it "routes stdlib Log calls through the default async dispatcher" do
    io = IO::Memory.new
    backend = Etch::Backend.new(io, formatter: :json)

    begin
      backend.dispatcher.should be_a(Log::AsyncDispatcher)

      Log.setup do |config|
        config.bind "*", :info, backend
      end

      Log.with_context(scope: "integration") do
        Log.info &.emit("routed", event: 42)
      end
    ensure
      Log.setup(:none)
      backend.close
    end

    record = JSON.parse(io.to_s)
    record.as_h.size.should eq(4)
    record["level"].as_s.should eq("info")
    record["msg"].as_s.should eq("routed")
    record["event"].as_i64.should eq(42)
    record["scope"].as_s.should eq("integration")
  end

  it "respects stdlib source filters before an entry reaches Etch" do
    io = IO::Memory.new
    backend = Etch::Backend.new(
      io,
      dispatch_mode: :direct,
      formatter: :logfmt,
    )

    builder = Log::Builder.new
    filtered_evaluated = false

    begin
      Log.setup(builder: builder) do |config|
        config.bind "allowed.*", :info, backend
      end

      builder.for("blocked").info do
        filtered_evaluated = true
        "hidden"
      end
      builder.for("allowed.worker").info { "visible" }
    ensure
      builder.close
    end

    filtered_evaluated.should be_false
    io.to_s.should eq(
      "level=info prefix=allowed.worker msg=visible\n"
    )
  end

  it "respects changes to a stdlib logger's source level" do
    io = IO::Memory.new
    backend = Etch::Backend.new(
      io,
      dispatch_mode: :direct,
      formatter: :logfmt,
    )
    builder = Log::Builder.new

    begin
      Log.setup(builder: builder) do |config|
        config.bind "*", :info, backend
      end

      log = builder.for("component")
      log.level = :debug
      log.debug { "visible" }
    ensure
      builder.close
    end

    io.to_s.should eq(
      "level=debug prefix=component msg=visible\n"
    )
  end

  it "Backend data and context fields with reserved names remain as payload" do
    stamp = Time.utc(2022, 1, 2, 3, 4, 5)
    io = IO::Memory.new
    backend = Etch::Backend.new(
      io,
      dispatch_mode: :direct,
      formatter: :logfmt,
      report_timestamp: true,
      prefix: "configured-prefix",
    )

    Log.with_context(
      time: "context-time",
      level: "context-level",
      caller: "context-caller",
      prefix: "context-prefix",
      msg: "context-message",
    ) do
      backend.write(
        backend_entry(
          :warn,
          "builtin-message",
          source: "builtin-source",
          timestamp: stamp,
          data: Log::Metadata.build({
            time:   "data-time",
            level:  "data-level",
            caller: "data-caller",
            prefix: "data-prefix",
            msg:    "data-message",
          }),
        )
      )
    end

    io.to_s.should eq(
      %(time="2022/01/02 03:04:05" level=warn prefix=builtin-source) +
      %( msg=builtin-message time=data-time level=data-level) +
      %( caller=data-caller prefix=data-prefix msg=data-message) +
      %( time=context-time level=context-level caller=context-caller) +
      %( prefix=context-prefix msg=context-message\n)
    )
  end

  it "renders shared semantic config equivalently to a direct logger" do
    direct_io = IO::Memory.new
    backend_io = IO::Memory.new
    timestamp = Time.utc(2022, 1, 2, 3, 4)
    time_function = ->(time : Time) { time + 1.hour }

    styles = Etch::Styles.default
    styles.levels[Etch::Level::Warn] =
      Sheen::Style.new.string("NOTE")

    bound_fields = [
      {"root", 1_i64.as(Etch::Value)},
    ]
    call_fields = [
      {"call", 2_i64.as(Etch::Value)},
    ]

    direct = Etch::Logger.new(
      direct_io,
      level: :debug,
      prefix: "app",
      time_format: Etch::TimeFormat::KITCHEN,
      time_function: time_function,
      report_timestamp: true,
      fields: bound_fields,
      styles: styles,
    )

    backend = Etch::Backend.new(
      backend_io,
      dispatch_mode: :direct,
      level: :debug,
      prefix: "app",
      time_format: Etch::TimeFormat::KITCHEN,
      time_function: time_function,
      report_timestamp: true,
      fields: bound_fields,
      styles: styles,
    )

    direct.emit(
      Etch::Level::Warn,
      "same",
      call_fields,
      timestamp: timestamp,
    )

    backend.write(
      backend_entry(
        :warn,
        "same",
        data: Log::Metadata.build({call: 2}),
        timestamp: timestamp
      )
    )

    direct_io.to_s.should eq(
      "04:04AM NOTE app: same root=1 call=2\n"
    )
    backend_io.to_s.should eq(direct_io.to_s)
  end

  it "applies config setters through its Logger" do
    io = IO::Memory.new
    backend = Etch::Backend.new(
      io,
      dispatch_mode: :direct,
      level: :error,
      formatter: :json,
    )

    styles = Etch::Styles.default
    styles.levels[Etch::Level::Debug] =
      Sheen::Style.new.string("BKND")

    backend.level = :debug
    backend.formatter = :text
    backend.styles = styles

    backend.write(backend_entry(:debug, "configured"))
    io.to_s.should eq("BKND configured\n")
  end
end
