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
    it "parses every user-facing level" do
      Etch::Level.parse?("debug").should eq(Etch::Level::Debug)
      Etch::Level.parse?("info").should eq(Etch::Level::Info)
      Etch::Level.parse?("warn").should eq(Etch::Level::Warn)
      Etch::Level.parse?("error").should eq(Etch::Level::Error)
      Etch::Level.parse?("fatal").should eq(Etch::Level::Fatal)
    end

    it "parses levels as case insensitive" do
      Etch::Level.parse?("DEBUG").should eq(Etch::Level::Debug)
      Etch::Level.parse?("FaTaL").should eq(Etch::Level::Fatal)
    end

    it "returns nil for unknown input" do
      Etch::Level.parse?("superdebug").should be_nil
    end

    it "does not parse the internal none sentinel" do
      Etch::Level.parse?("none").should be_nil
    end
  end

  describe "#to_s" do
    it "returns normalized lower level name" do
      Etch::Level::Debug.to_s.should eq("debug")
      Etch::Level::Info.to_s.should eq("info")
      Etch::Level::Warn.to_s.should eq("warn")
      Etch::Level::Error.to_s.should eq("error")
      Etch::Level::Fatal.to_s.should eq("fatal")
    end

    it "gives consistent output for both the no-arg and IO overloads" do
      Etch::Level.each do |level|
        String.build do |io|
          level.to_s(io)
        end.should eq(level.to_s)
      end
    end

    it "renders the internal None sentinel as its fallthrough max int value on io" do
      io = IO::Memory.new
      Etch::Level::None.to_s(io)
      io.to_s.should eq(Int32::MAX.to_s)
    end

    it "renders the internal None sentinel as its fallthrough max int value on no-arg" do
      Etch::Level::None.to_s.should eq(Int32::MAX.to_s)
    end
  end
end
