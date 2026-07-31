require "../spec_helper"

describe Etch::Formatter do
  it "defaults to Text as the first and default entry" do
  end

  it "defines three discrete formatter output options" do
    Etch::Formatter.names.should eq(%w[Text JSON Logfmt])
    Etch::Formatter.values.size.should eq(3)
  end

  it "defines output key names as constants" do
    Etch::TIMESTAMP_KEY.should eq("time")
    Etch::MESSAGE_KEY.should eq("msg")
    Etch::LEVEL_KEY.should eq("level")
    Etch::CALLER_KEY.should eq("caller")
    Etch::PREFIX_KEY.should eq("prefix")
  end
end
