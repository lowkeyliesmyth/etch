require "../spec_helper"

describe Etch::Level do
  describe ".parse" do
    it "roundtrips every user-facing level" do
      Etch::Level.parse("debug").should eq(Etch::Level::Debug)
      Etch::Level.parse("info").should eq(Etch::Level::Info)
      Etch::Level.parse("warn").should eq(Etch::Level::Warn)
      Etch::Level.parse("error").should eq(Etch::Level::Error)
      Etch::Level.parse("fatal").should eq(Etch::Level::Fatal)
    end

    it "parses levels as case-insensitive" do
      Etch::Level.parse("INFO").should eq(Etch::Level::Info)
      Etch::Level.parse("WaRn").should eq(Etch::Level::Warn)
    end

    it "raises on unknown input" do
      expect_raises(Etch::InvalidLevelError, /invalid level/) do
        Etch::Level.parse("trace")
      end
    end

    it "does not parse the internal None sentinel" do
      expect_raises(Etch::InvalidLevelError) { Etch::Level.parse("none") }
    end
  end

  describe ".parse?" do
  end

  describe "#to_s" do
  end
end
