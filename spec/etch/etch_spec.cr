require "../spec_helper"

describe "Etch.status" do
  it "returns 0 when the block completes" do
    Etch.status { 1 + 1 }.should eq(0)
  end

  it "returns 1 after receiving and emitting a fatal record" do
    io = IO::Memory.new
    log = Etch::Logger.new(io)
    Etch.status { log.fatal "oven on fire!" }.should eq(1)
    io.to_s.should eq("FATA oven on fire!\n")
  end

  it "propagates other non-fatal exceptions too" do
    expect_raises(ArgumentError) { Etch.status { raise ArgumentError.new("other") } }
  end
end

describe "Etch.run" do
  it "returns normally when the block completes" do
    ran = false
    Etch.run { ran = true }
    ran.should be_true
  end

  it "propagastes other non-fatal exceptions too" do
    expect_raises(ArgumentError) { Etch.run { raise ArgumentError.new("other") } }
  end
end
