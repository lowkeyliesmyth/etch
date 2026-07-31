require "../spec_helper"

describe Etch::TimeFormat do
  # avoid system-tzdata in order to make every directive deterministic
  location = Time::Location.fixed("here", -7 * 3600)
  time = Time.local(2019, 7, 5, 13, 4, 5, location: location)

  it "DEFAULT matches log's layout" do
    time.to_s(Etch::TimeFormat::DEFAULT).should eq("2019/07/05 13:04:05")
  end

  it "KITCHEN renders a 12hour clock with uppercase suffix" do
    time.to_s(Etch::TimeFormat::KITCHEN).should eq("01:04PM")
  end

  it "RFC3339 includes timezone offset" do
    time.to_s(Etch::TimeFormat::RFC3339).should eq("2019-07-05T13:04:05-07:00")
  end

  it "RFC3399_NANO contains a fixed nine digits of fractional seconds" do
    time.to_s(Etch::TimeFormat::RFC3399_NANO).should eq("2019-07-05T13:04:05.000000000-07:00")
  end

  it "STAMP renders short month, blank-padded day, and time" do
    time.to_s(Etch::TimeFormat::STAMP).should eq("Jul  5 13:04:05")
  end
end
