require "../spec_helper"

describe Etch::Options do
  it "gives log-compatible defaults" do
    opt = Etch::Options.new
    opt.level.should eq(Etch::Level::Info)
    opt.formatter.should eq(Etch::Formatter::Text)
    opt.time_format.should eq(Etch::TimeFormat::DEFAULT)
    opt.report_timestamp?.should be_false
    opt.report_caller?.should be_false
    opt.prefix.should eq("")
    opt.caller_offset.should eq(0)
    opt.caller_formatter.should be_nil
    opt.fields.should be_empty
  end

  it "time_function mutator does not modify the time by default" do
    opt = Etch::Options.new
    t = Time.utc(2025, 7, 5)
    opt.time_function.call(t).should eq(t)
  end

  it "accepts overrides" do
    opt = Etch::Options.new(level: :debug, prefix: "x", report_timestamp: true)
    opt.level.should eq(Etch::Level::Debug)
    opt.prefix.should eq("x")
    opt.report_timestamp?.should be_true
  end
end

describe "Etch caller formatters" do
  it "SHORT keeps the last two path segments and line number" do
    Etch::SHORT_CALLER_FORMATTER.call("a/b/c/logger.cr", 42, "").should eq("c/logger.cr:42")
  end

  it "SHORT still works with an already short path" do
    Etch::SHORT_CALLER_FORMATTER.call("logger.cr", 42, "").should eq("logger.cr:42")
  end

  it "LONG keeps the full path plus line number" do
    Etch::LONG_CALLER_FORMATTER.call("/a/b/c/d/logger.cr", 42, "").should eq("/a/b/c/d/logger.cr:42")
  end
end
