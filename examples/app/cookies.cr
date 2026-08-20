require "../examples"

module Examples::App::Cookies
  # Logs oven startup while presering the helper caller's location.
  def self.start_oven(
    temperature : Int32,
    __file : String = __FILE__,
    __line : Int32 = __LINE__,
  ) : Nil
    Etch.debug(
      "Starting oven",
      temperature: temperature,
      __file: __file,
      __line: __line,
    )
  end

  # Exercises the main logging workflow
  def self.run(io : IO) : Nil
    logger = Etch::Logger.new(
      io,
      level: :debug,
      time_format: Etch::TimeFormat::KITCHEN,
      report_timestamp: true,
      report_caller: true,
    )

    ingredients = [
      "1 cup of butter",
      "2 cups of chocolate",
      "3 cups of flour",
      "5 cups of sugar",
      "1 pinch of salt",
    ].join("\n")
    temperature = 375

    Etch.with_logger(logger) do
      start_oven(temperature)

      Etch.debug "Mixing ingredients", ingredients: ingredients
      Etch.warn "That's a log of sugar bro", amount: 5
      Etch.info "Baking cookies", duration: 10, unit: "minutes"
      Etch.info "Increasing temp", amount: 300, unit: "Fahrenheit"

      temperature += 300
      Etch.error "Oven is too hot!", temperature: temperature

      begin
        Etch.fatal "The kitchen is on fire"
      rescue Etch::FatalError
        # Fatal rescues locally so the complete example registry can complete
      end
    end
  end
end

Examples.register("app/cookies") do |io|
  Examples::App::Cookies.run(io)
end
