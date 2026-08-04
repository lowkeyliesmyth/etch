module Etch
  # The set of types a field value is allowed to hold.
  alias Value = Nil | Bool | Int64 | Float64 | String | Time | Exception

  # An ordered list of k-v pairs. Order is significant and duplicate keys are allowed.
  alias Fields = Array(Tuple(String, Value))

  # Narrows *value* into a `Value` type.
  #
  # Ints and floats widen to 64bit, every unrecognized type degrades to its `#to_s`.
  def self.coerce_value(value) : Value
    case value
    when Value then value
    when Int   then value.to_i64
    when Float then value.to_f64
    else            value.to_s
    end
  end
end
