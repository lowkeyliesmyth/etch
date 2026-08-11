require "../spec_helper"

# Test helper
# Builds a formatter bound to *time_format* timestamp key formatting.
private def json_formatter(time_format : String = Etch::TimeFormat::DEFAULT) : Etch::JSONFormatter
  Etch::JSONFormatter.new(time_format)
end

describe Etch::JSONFormatter do
  describe "#render" do
    it "renders reserved keys in order, without applying any bracketing formatting" do
      kvs = [
        {Etch::LEVEL_KEY, Etch::Level::Info},
        {Etch::CALLER_KEY, "etch/logger.cr:42"},
        {Etch::PREFIX_KEY, "baking"},
        {Etch::MESSAGE_KEY, "cookies"},
        {"batch", 2_i64},
      ] of Tuple(String, Etch::Value)
      json_formatter.render(kvs).should eq(%({"level":"info","caller":"etch/logger.cr:42","prefix":"baking","msg":"cookies","batch":2}\n))
    end

    it "formats the timestamp through time_format" do
      stamp = Time.local(2022, 1, 2, 3, 4, 5,
        nanosecond: 123456789,
        location: Time::Location.fixed("here", -7 * 3600))
      kvs = [{Etch::TIMESTAMP_KEY, stamp}] of Tuple(String, Etch::Value)
      json_formatter.render(kvs).should eq(%({"time":"2022/01/02 03:04:05"}\n))
    end

    it "formats a Time field value as RFC3339 nano, preserving offset" do
      stamp = Time.local(2022, 1, 2, 3, 4, 5,
        nanosecond: 123456789,
        location: Time::Location.fixed("here", -7 * 3600))
      kvs = [{"seen", stamp}] of Tuple(String, Etch::Value)
      json_formatter.render(kvs).should eq(%({"seen":"2022-01-02T03:04:05.123456789-07:00"}\n))
    end

    it "coerces every value kind to its appropriate JSON form" do
      kvs = [
        {"nil", nil},
        {"bool", true},
        {"int", 42_i64},
        {"float", 1.5},
        {"str", "text"},
        {"err", Exception.new("boom")},
        {"lvl", Etch::Level::Warn},
      ] of Tuple(String, Etch::Value)
      json_formatter.render(kvs).should eq(
        %({"nil":null,"bool":true,"int":42,"float":1.5,"str":"text","err":"boom","lvl":"warn"}\n)
      )
    end

    it "falls back to invalid value for JSON-invalid floats" do
      kvs = [
        {"nan", Float64::NAN},
        {"inf", Float64::INFINITY},
      ] of Tuple(String, Etch::Value)
      json_formatter.render(kvs).should eq(%({"nan":"invalid value","inf":"invalid value"}\n))
    end

    it "skips a reserved key carrying the wrong value type" do
      kvs = [
        {Etch::TIMESTAMP_KEY, "not a time"},
        {Etch::MESSAGE_KEY, "still here though"},
      ] of Tuple(String, Etch::Value)
      json_formatter.render(kvs).should eq(%({"msg":"still here though"}\n))
    end

    it "preserves duplicate keys in order" do
      kvs = [{"k", "first"}, {"k", "second"}] of Tuple(String, Etch::Value)
      json_formatter.render(kvs).should eq(%({"k":"first","k":"second"}\n))
    end

    it "renders an empty record as an empty object" do
      json_formatter.render(Etch::Fields.new).should eq("{}\n")
    end
  end
end
