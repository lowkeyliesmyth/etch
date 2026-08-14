require "../spec_helper"

describe Etch do
  around_each do |example|
    previous = Etch.default
    begin
      example.run
    ensure
      Etch.default = previous
    end
  end

  it "lazily constructs a default logger with timestamps enabled" do
    logger = Etch.default
    logger.output.should be(STDERR)
    logger.report_timestamp?.should be_true
    Etch.default.should be(logger)
  end

  it "allows a custom logger to replace the package default" do
    custom = Etch::Logger.new(IO::Memory.new)
    Etch.default = custom
    Etch.default.should be(custom)
  end

  it "uses the package logger when the current fiber doesn't have an override" do
    package = Etch::Logger.new(IO::Memory.new)
    override = Etch::Logger.new(IO::Memory.new)
    Etch.default = package

    result = Etch.with_logger(override) do
      Etch.current_logger.should be override
      Etch.from_fiber.should be(override)
      "the block result"
    end

    result.should eq("the block result")
    Etch.current_logger.should be(package)
  end

  it "restores nested overrides when an exception unwinds the inner block" do
    package = Etch::Logger.new(IO::Memory.new)
    outer = Etch::Logger.new(IO::Memory.new)
    inner = Etch::Logger.new(IO::Memory.new)
    Etch.default = package

    Etch.with_logger(outer) do
      expect_raises(ArgumentError, "inner failure") do
        Etch.with_logger(inner) do
          Etch.current_logger.should be(inner)
          raise ArgumentError.new("inner failure")
        end
      end

      Etch.current_logger.should be(outer)
    end

    Etch.current_logger.should be(package)
  end

  it "does not propagate into fibers spawned inside the block" do
    override = Etch::Logger.new(IO::Memory.new)
    seen = Channel(Etch::Logger).new

    Etch.with_logger(override) do
      spawn { seen.send(Etch.current_logger) }
      seen.receive.should be(Etch.default)
    end
  end

  it "keeps concurrent fibers isolated" do
    first = IO::Memory.new
    second = IO::Memory.new
    done = Channel(Nil).new

    {first, second}.each_with_index do |io, index|
      spawn do
        Etch.with_logger(Etch::Logger.new(io)) do
          5.times do
            Etch.current_logger.info "fiber-#{index}"
            Fiber.yield
          end
        end
        done.send(nil)
      end
    end
    2.times { done.receive }

    first.to_s.lines.should eq(Array.new(5, "INFO fiber-0"))
    second.to_s.lines.should eq(Array.new(5, "INFO fiber-1"))
  end
end
