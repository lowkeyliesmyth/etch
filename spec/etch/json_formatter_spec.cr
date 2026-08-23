require "../spec_helper"

# Test helper
# Builds a formatter bound to *time_format* timestamp key formatting.
private def json_formatter(time_format : String = Etch::TimeFormat::DEFAULT) : Etch::JSONFormatter
  Etch::JSONFormatter.new(time_format)
end

# Test record fixture helper
private def json_record(
  level : Etch::Level = Etch::Level::None,
  msg = "",
  fields : Etch::Fields = Etch::Fields.new,
  timestamp : Time? = nil,
  *,
  report_timestamp : Bool = false,
  report_caller : Bool = false,
  file : String = "etch/logger.cr",
  line : Int32 = 42,
  prefix : String = "",
) : Etch::Record
  Etch::Record.new(
    level,
    msg,
    Etch::Fields.new,
    fields,
    timestamp,
    file,
    line,
    report_timestamp: report_timestamp,
    time_function: ->(time : Time) { time },
    report_caller: report_caller,
    caller_formatter: nil,
    prefix: prefix,
  )
end

describe Etch::JSONFormatter do
  describe "#render" do
    it "renders reserved keys in order, without applying any bracketing formatting" do
      record = json_record(
        level: Etch::Level::Info,
        report_caller: true,
        prefix: "baking",
        msg: "cookies",
        fields: [{"batch", 2_i64}]
      )
      json_formatter.render(record).should eq(%({"level":"info","caller":"etch/logger.cr:42","prefix":"baking","msg":"cookies","batch":2}\n))
    end

    it "formats the timestamp through time_format" do
      stamp = Time.local(2022, 1, 2, 3, 4, 5,
        nanosecond: 123456789,
        location: Time::Location.fixed("here", -7 * 3600))
      record = json_record(
        report_timestamp: true,
        timestamp: stamp,
      )
      json_formatter.render(record).should eq(%({"time":"2022/01/02 03:04:05"}\n))
    end

    it "formats a Time field value as RFC3339 nano, preserving offset" do
      stamp = Time.local(2022, 1, 2, 3, 4, 5,
        nanosecond: 123456789,
        location: Time::Location.fixed("here", -7 * 3600))
      record = json_record(
        fields: [{"seen", stamp}]
      )
      json_formatter.render(record).should eq(%({"seen":"2022-01-02T03:04:05.123456789-07:00"}\n))
    end

    it "coerces every value kind to its appropriate JSON form" do
      record = json_record(
        fields: [
          {"nil", nil},
          {"bool", true},
          {"int", 42_i64},
          {"float", 1.5},
          {"str", "text"},
          {"err", Exception.new("boom")},
          {"lvl", Etch::Level::Warn},
        ]
      )
      json_formatter.render(record).should eq(
        %({"nil":null,"bool":true,"int":42,"float":1.5,"str":"text","err":"boom","lvl":"warn"}\n)
      )
    end

    it "falls back to invalid value for JSON-invalid floats" do
      record = json_record(
        fields: [
          {"nan", Float64::NAN},
          {"inf", Float64::INFINITY},
        ]
      )
      json_formatter.render(record).should eq(%({"nan":"invalid value","inf":"invalid value"}\n))
    end

    it "preserves duplicate keys in order" do
      record = json_record(
        fields: [{"k", "first"}, {"k", "second"}]
      )
      json_formatter.render(record).should eq(%({"k":"first","k":"second"}\n))
    end

    it "renders an empty record as an empty object" do
      json_formatter.render(json_record).should eq("{}\n")
    end
  end
end
