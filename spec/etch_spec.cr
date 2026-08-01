require "./spec_helper"

describe Etch::FatalError do
  it "carries an optional message and fields" do
    err = Etch::FatalError.new("boom", [{"k", "v"}])
    err.message.should eq("boom")
    err.fields.should eq([{"k", "v"}])
  end

  it "defaults to no message and empty fields" do
    err = Etch::FatalError.new
    err.message.should be_nil
    err.fields.should be_empty
  end
end
