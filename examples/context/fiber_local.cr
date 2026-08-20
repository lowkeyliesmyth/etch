require "../examples"

module Examples::Context::FiberLocal
  # Exhibits isolated logger overrides across concurrent fibers.
  def self.run(io : IO) : Nil
    done = Channel(Nil).new

    {"oven", "mixer"}.each_with_index do |component, idx|
      spawn do
        logger = Etch::Logger.new(io).with(
          component: component,
          fiber: idx,
        )

        Etch.with_logger(logger) do
          Etch.info "Started"
          Fiber.yield
          Etch.info "Finished"
        end

        done.send(nil)
      end
    end

    2.times { done.receive }
  end
end

Examples.register("context/fiber_local") do |io|
  Examples::Context::FiberLocal.run(io)
end
