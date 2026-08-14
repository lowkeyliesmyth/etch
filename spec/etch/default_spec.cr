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
            Etch.info "fiber-#{index}"
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

  it "writes package level info through the default logger" do
    io = IO::Memory.new
    Etch.default = Etch::Logger.new(io)

    Etch.info "package", batch: 2

    io.to_s.should eq("INFO package batch=2\n")
  end

  it "routes package level logging calls through a temp fiber-level logger override" do
    package = IO::Memory.new
    override = IO::Memory.new
    Etch.default = Etch::Logger.new(package)

    Etch.info "before"
    Etch.with_logger(Etch::Logger.new(override)) do
      Etch.info "inside"
    end
    Etch.info "after"

    package.to_s.lines.should eq(["INFO before", "INFO after"])
    override.to_s.lines.should eq(["INFO inside"])
  end

  it "builds field and prefix children from the current fiber logger" do
    package = IO::Memory.new
    override = IO::Memory.new
    Etch.default = Etch::Logger.new(package)

    Etch.with_logger(Etch::Logger.new(override)) do
      Etch.with(batch: 2).info "named"
      Etch.with({"runtime" => 3}).info "runtime"
      Etch.with_prefix("oven").info "prefixed"
    end

    package.to_s.should be_empty
    override.to_s.lines.should eq([
      "INFO named batch=2",
      "INFO runtime runtime=3",
      "INFO oven: prefixed",
    ])
  end

  it "supports every package level logging invocation variant" do
    io = IO::Memory.new
    Etch.default = Etch::Logger.new(io, level: :debug)

    Etch.debug "debug", n: 1
    Etch.info "info", {"n" => 2}
    Etch.warn(flag: true) { "warn" }
    Etch.warn("warn again", flag: false)
    Etch.error "error"
    Etch.print "plain"
    expect_raises(Etch::FatalError) { Etch.fatal "fatal" }

    io.to_s.lines.should eq([
      "DEBU debug n=1",
      "INFO info n=2",
      "WARN warn flag=true",
      "WARN warn again flag=false",
      "ERRO error",
      "plain",
      "FATA fatal",
    ])
  end

  it "supports every package level formatted variant" do
    io = IO::Memory.new
    Etch.default = Etch::Logger.new(io, level: :debug)

    Etch.debugf "%s", "debugf"
    Etch.infof "%s", "infof"
    Etch.warnf "%s", "warnf"
    Etch.errorf "%s", "errorf"
    Etch.printf "%s", "printf"
    expect_raises(Etch::FatalError) { Etch.fatalf "%s", "fatalf" }

    io.to_s.lines.should eq([
      "DEBU debugf",
      "INFO infof",
      "WARN warnf",
      "ERRO errorf",
      "printf",
      "FATA fatalf",
    ])
  end

  it "supports explicit levels with named, runtime defined, and formatted values" do
    io = IO::Memory.new
    Etch.default = Etch::Logger.new(io)

    Etch.log :warn, "named", a: 1
    Etch.log :error, "runtime", {"b" => 2}
    Etch.logf :info, "%s %d", "formatted", 3

    io.to_s.lines.should eq([
      "WARN named a=1",
      "ERRO runtime b=2",
      "INFO formatted 3",
    ])
  end

  it "does not evaluate a filtered package-level block" do
    io = IO::Memory.new
    Etch.default = Etch::Logger.new(io, level: :info)
    evaluated = false

    Etch.debug do
      evaluated = true
      "hidden"
    end

    evaluated.should be_false
    io.to_s.should be_empty
  end

  it "forwards caller info through the package-level wrapper" do
    io = IO::Memory.new
    Etch.default = Etch::Logger.new(io, report_caller: true)

    Etch.info "site", __file: "outer.cr", __line: 7

    io.to_s.should eq("INFO <outer.cr:7> site\n")
  end

  it "routes config setters through the current fiber logger" do
    package_output = IO::Memory.new
    redirected = IO::Memory.new
    package = Etch::Logger.new(package_output)
    target = Etch::Logger.new(IO::Memory.new)
    styles = Etch::Styles.default
    input_time = Time.utc(2020, 1, 1)
    static_time = Time.utc(2020, 5, 5)
    time_function = ->(_time : Time) { static_time }
    Etch.default = package

    Etch.with_logger(target) do
      Etch.level = :debug
      Etch.prefix = "oven"
      Etch.formatter = :logfmt
      Etch.report_timestamp = true
      Etch.report_caller = true
      Etch.time_format = "%H:%M"
      Etch.time_function = time_function
      Etch.output = redirected
      Etch.styles = styles
    end

    target.level.should eq(Etch::Level::Debug)
    target.prefix.should eq("oven")
    target.formatter.should eq(Etch::Formatter::Logfmt)
    target.report_timestamp?.should be_true
    target.time_format.should eq("%H:%M")
    target.time_function.call(input_time).should eq(static_time)
    target.output.should be(redirected)
    target.styles.should be(styles)
    package.level.should eq(Etch::Level::Info)
    package.output.should be(package_output)
  end
end
