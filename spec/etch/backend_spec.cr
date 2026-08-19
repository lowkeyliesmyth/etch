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
end
