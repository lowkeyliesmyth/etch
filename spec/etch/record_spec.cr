require "../spec_helper"

private def record(
  level : Etch::Level = Etch::Level::Info,
  msg = "cookies",
  bound_fields : Etch::Fields = Etch::Fields.new,
  call_fields : Etch::Fields = Etch::Fields.new,
  timestamp : Time? = nil,
  file : String = "src/app.cr",
  line : Int32 = 42,
  *,
  report_timestamp : Bool = false,
  time_function : Etch::TimeFunction = ->(time : Time) { time },
  report_caller : Bool = false,
  caller_formatter : Etch::CallerFormatter? = nil,
  prefix : String = "",
) : Etch::Record
  Etch::Record.new(
    level,
    msg,
    bound_fields,
    call_fields,
    timestamp,
    file,
    line,
    report_timestamp: report_timestamp,
    time_function: time_function,
    report_caller: report_caller,
    caller_formatter: caller_formatter,
    prefix: prefix,
  )
end

# Helper class.
# Count how many times to_s is called to confirm exact once processing.
private class OneShotMessage
  getter calls = 0

  def to_s(io : IO) : Nil
    @calls += 1
    io << "normalized"
  end
end

describe Etch::Record do
  it "presents builtin entries and payload fields in structured order" do
    timestamp = Time.utc(2022, 1, 2, 3, 4, 5)
    bound = [{"batch", 2_i64.as(Etch::Value)}]
    call = [{"ready", true.as(Etch::Value)}]

    items = record(
      level: Etch::Level::Warn,
      msg: "no cookies for you",
      bound_fields: bound,
      call_fields: call,
      timestamp: timestamp,
      report_timestamp: true,
      report_caller: true,
      prefix: "baking",
    ).to_a

    items.should eq([
      Etch::Record::Timestamp.new(timestamp),
      Etch::Record::Severity.new(Etch::Level::Warn),
      Etch::Record::Caller.new("src/app.cr:42"),
      Etch::Record::Prefix.new("baking"),
      Etch::Record::Message.new("no cookies for you"),
      Etch::Record::Payload.new("batch", 2_i64),
      Etch::Record::Payload.new("ready", true),
    ] of Etch::Record::Item)
  end

  it "omits disabled or empty builtin items" do
    items = record(
      level: Etch::Level::None,
      msg: nil,
      report_timestamp: false,
      report_caller: false,
      prefix: "",
    ).to_a

    items.should be_empty
  end

  it "preserves whitespace only messages" do
    record(msg: " ").to_a.should eq([
      Etch::Record::Severity.new(Etch::Level::Info),
      Etch::Record::Message.new(" "),
    ] of Etch::Record::Item)
  end

  it "preserves duped and reserved payload names as payload entries" do
    fields = [
      {Etch::TIMESTAMP_KEY, "payload time".as(Etch::Value)},
      {Etch::LEVEL_KEY, "payload level".as(Etch::Value)},
      {Etch::CALLER_KEY, "payload caller".as(Etch::Value)},
      {Etch::PREFIX_KEY, "payload prefix".as(Etch::Value)},
      {Etch::MESSAGE_KEY, "first".as(Etch::Value)},
      {Etch::MESSAGE_KEY, "second".as(Etch::Value)},
    ]

    payload = record(msg: "", call_fields: fields).to_a.select(Etch::Record::Payload)

    payload.should eq([
      Etch::Record::Payload.new("time", "payload time"),
      Etch::Record::Payload.new("level", "payload level"),
      Etch::Record::Payload.new("caller", "payload caller"),
      Etch::Record::Payload.new("prefix", "payload prefix"),
      Etch::Record::Payload.new("msg", "first"),
      Etch::Record::Payload.new("msg", "second"),
    ])
  end

  it "snapshots bound and callsite payloads " do
    bound = [{"bound", 1_i64.as(Etch::Value)}]
    call = [{"call", 2_i64.as(Etch::Value)}]
    captured = record(bound_fields: bound, call_fields: call)

    bound << {"later-bound", 3_i64.as(Etch::Value)}
    call.clear

    captured.to_a.select(Etch::Record::Payload).should eq([
      Etch::Record::Payload.new("bound", 1_i64),
      Etch::Record::Payload.new("call", 2_i64),
    ])
  end

  it "transforms the timestamp and formats the caller exactly once" do
    timestamp_calls = 0
    caller_calls = 0
    timestamp = Time.utc(2022, 1, 2, 3, 4, 5)

    captured = record(
      timestamp: timestamp,
      report_timestamp: true,
      time_function: ->(time : Time) {
        timestamp_calls += 1
        time + 1.hour
      },
      report_caller: true,
      caller_formatter: Etch::CallerFormatter.new do |file, line, function|
        caller_calls += 1
        function.should be_empty
        "#{file}@#{line}"
      end,
    )

    captured.to_a
    captured.to_a

    timestamp_calls.should eq(1)
    caller_calls.should eq(1)
    captured.to_a.should contain(
      Etch::Record::Timestamp.new(timestamp + 1.hour)
    )
    captured.to_a.should contain(
      Etch::Record::Caller.new("src/app.cr@42")
    )
  end
  # This test verifies that the message object is converted to a string
  # ("normalized") at most once, even if the record is iterated multiple times.
  #
  # OneShotMessage is a helper class (defined above) that counts how many times
  # its `to_s` is called. If the record memoizes the message properly, the
  # counter should stay at 1 despite `to_a` being called repeatedly.
  it "normalizes the message exactly once" do
    message = OneShotMessage.new

    # The record should call `to_s` lazily when the record is initially materialized.
    captured = record(msg: message)

    captured.to_a
    captured.to_a

    # The counter should still be 1, proving the message was normalized only once and reused on any subsequent iterations.
    message.calls.should eq(1)

    captured.to_a.should contain(Etch::Record::Message.new("normalized"))
  end

  it "propagates timestamp transformation failures" do
    expect_raises(Exception, "timestamp failed") do
      record(
        report_timestamp: true,
        time_function: ->(_time : Time) { raise "timestamp failed" },
      )
    end
  end

  it "propagates caller formatting failures" do
    formatter = Etch::CallerFormatter.new do |_file, _line, _function|
      raise "caller failed"
    end

    expect_raises(Exception, "caller failed") do
      record(report_caller: true, caller_formatter: formatter)
    end
  end
end
