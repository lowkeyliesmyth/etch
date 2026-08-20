require "../examples"

module Examples::Backend::StdlibLog
  # Routes filtered stdlib Log sources through Etch's rendering pipeline
  def self.run(io : IO) : Nil
    backend = Etch::Backend.new(io, dispatch_mode: :direct)
    builder = Log::Builder.new

    begin
      Log.setup(builder: builder) do |config|
        config.bind "bakery.*", :info, backend
      end

      builder.for("bakery.oven").info do |entry|
        entry.emit("Heating oven", temperature: 375)
      end

      builder.for("database").info do
        "Filtered before it reaches Etch"
      end
    ensure
      builder.close
    end
  end
end

Examples.register("backend/stdlib_log") do |io|
  Examples::Backend::StdlibLog.run(io)
end
