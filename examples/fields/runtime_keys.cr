require "../examples"

module Examples::Fields::RuntimeKeys
  # Exercises runtime string keys passed through the Fields overload.
  def self.run(io : IO) : Nil
    logger = Etch::Logger.new(io)
    ingredients = {
      "flour_cups"    => 3,
      "sugar_cups"    => 5,
      "butter_sticks" => 2,
    }

    logger.info "Measured ingredients", ingredients
  end
end

Examples.register("fields/runtime_keys") do |io|
  Examples::Fields::RuntimeKeys.run(io)
end
