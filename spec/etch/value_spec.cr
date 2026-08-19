require "../spec_helper"

describe Etch do
  describe ".coerce_value" do
    it "passes union members through unchanged" do
      Etch.coerce_value("s").should eq("s")
      Etch.coerce_value(true).should be_true
      Etch.coerce_value(nil).should be_nil
      Etch.coerce_value(2_i64).should eq(2_i64)
      Etch.coerce_value(2.1_f64).should eq(2.1_f64)

      time = Time.utc(2025, 7, 5)
      Etch.coerce_value(time).should eq(time)
      Etch.coerce_value(Exception.new("oops")).should be_a(Exception)
    end

    it "expands ints and floats to 64bit" do
      Etch.coerce_value(2).should eq(2_i64)
      Etch.coerce_value(2_i32).should be_a(Int64)
      Etch.coerce_value(3.1).should eq(3.1_f64)
      Etch.coerce_value(3.1_f32).should be_a(Float64)
    end

    it "downgrades unrecognized types to string equivalents" do
      Etch.coerce_value({1, 2}).should eq("{1, 2}")
      Etch.coerce_value([1, 2]).should eq("[1, 2]")
      Etch.coerce_value({"a" => 1, "b" => 2}).should eq("{\"a\" => 1, \"b\" => 2}")
    end
  end

  describe ".coerce_fields" do
    it "widens values while preserving order and dupe keys" do
      input = [
        {"a", 1},
        {"active", true},
        {"a", 3.5_f32},
      ]

      Etch.coerce_fields(input).should eq([
        {"a", 1_i64},
        {"active", true},
        {"a", 3.5_f64},
      ] of Tuple(String, Etch::Value))
    end

    it "accepts an empty runtime collection type" do
      fields = [] of Tuple(String, Etch::Value)

      Etch.coerce_fields(fields).should be_empty
    end

    it "degrades unsupported value types to their string representations" do
      fields = [{"nested", {"a" => 1}}]

      Etch.coerce_fields(fields).should eq([{"nested", "{\"a\" => 1}"}])
    end
  end
end

describe Etch::Fields do
  it "preserves insertion order and allows dupe keys" do
    fields = Etch::Fields.new
    fields << {"a", 1_i64}
    fields << {"b", "two"}
    fields << {"a", 3_i64}

    fields.map(&.first).should eq(%w[a b a])
    fields.first.should eq({"a", 1})
    fields.last.should eq({"a", 3})
  end
end
