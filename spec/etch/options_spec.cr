require "../spec_helper"

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
