require "../spec_helper"

describe Etch::Logger do
  it "ships with log-compatible defaults" do
    io = IO::Memory.new
    log = Etch::Logger.new(io)
    log.level.should eq(Etch::Level::Info)
    log.formatter.should eq(Etch::Formatter::Text)
    log.time_format.should eq(Etch::TimeFormat::DEFAULT)
    log.report_timestamp?.should be_false
    log.report_caller?.should be_false
    log.caller_formatter.should be_nil
    log.prefix.should eq("")
    log.fields.should be_empty
  end

  it "accepts symbol shorthand for enum options" do
    io = IO::Memory.new
    log = Etch::Logger.new(io, level: :debug, formatter: :logfmt)
    log.level.should eq(Etch::Level::Debug)
    log.formatter.should eq(Etch::Formatter::Logfmt)
  end

  describe "setters" do
    it "mutates config properties in place" do
      io = IO::Memory.new
      log = Etch::Logger.new(io)
      log.level = :warn
      log.prefix = "oven"
      log.report_caller = true
      log.level.should eq(Etch::Level::Warn)
      log.prefix.should eq("oven")
      log.report_caller?.should be_true
    end

    it "swaps output IO" do
      io = IO::Memory.new
      # Initialize with io as a positional parameter
      log = Etch::Logger.new(io)
      second = IO::Memory.new
      # Update output io through property generated setter method
      log.output = second
      log.info "routed"
      second.to_s.should eq("INFO routed\n")
      io.to_s.should be_empty
    end
  end

  describe "level methods" do
    it "renders the four character level label" do
      io = IO::Memory.new
      log = Etch::Logger.new(io, level: :debug)
      log.debug "d"
      log.info "i"
      log.warn "w"
      log.error "e"
      io.to_s.should eq("DEBU d\nINFO i\nWARN w\nERRO e\n")
    end

    it "suppresses records below the configured allowed levels" do
      io = IO::Memory.new
      log = Etch::Logger.new(io, level: :warn)
      log.debug "negative"
      log.info "negative"
      log.warn "affirmative ghost rider"
      io.to_s.should eq("WARN affirmative ghost rider\n")
    end

    it "renders callsite fields after the main message" do
      io = IO::Memory.new
      log = Etch::Logger.new(io)
      log.error "Oops", err: "kitchen on fire"
      io.to_s.should eq(%(ERRO Oops err="kitchen on fire"\n))
    end

    it "allows user-provided fieldnames that conflict with caller metadata reporting to be passed as-is" do
      io = IO::Memory.new
      log = Etch::Logger.new(io)
      log.info "payload", file: "payload.json", line: 42
      io.to_s.should eq("INFO payload file=payload.json line=42\n")
    end
  end

  describe "block form" do
    it "evaluates and emits the block's value when that level is configured as allowed" do
      io = IO::Memory.new
      log = Etch::Logger.new(io, level: :debug)
      log.debug { "lazy #{1 + 1}" }
      io.to_s.should eq("DEBU lazy 2\n")
    end

    it "does not evaluate the block when the log level is filtered" do
      io = IO::Memory.new
      log = Etch::Logger.new(io, level: :error)
      evaluated = false
      log.debug do
        evaluated = true
        "never"
      end
      evaluated.should be_false
      io.to_s.should be_empty
    end

    it "accepts fields alongside the block" do
      io = IO::Memory.new
      log = Etch::Logger.new(io, level: :debug)
      log.debug(batch: 2) { "lazy #{1 + 1}" }
      io.to_s.should eq("DEBU lazy 2 batch=2\n")
    end
  end

  describe "formatted variants" do
    it "renders through sprintf" do
      io = IO::Memory.new
      log = Etch::Logger.new(io)
      log.infof "%s has %d items", "cart", 3
      io.to_s.should eq("INFO cart has 3 items\n")
    end

    it "respects level filtering" do
      io = IO::Memory.new
      log = Etch::Logger.new(io, level: :error)
      log.infof "%s", "negative"
      io.to_s.should be_empty
    end
  end

  describe "#log" do
    it "supports explicit levels" do
      io = IO::Memory.new
      log = Etch::Logger.new(io)
      log.log(:warn, "explicit", k: "v")
      io.to_s.should eq("WARN explicit k=v\n")
    end
  end

  describe "#fatal" do
    it "emits the record and then raises FatalError" do
      io = IO::Memory.new
      log = Etch::Logger.new(io)
      error = expect_raises(Etch::FatalError, "oven on fire") do
        log.fatal "oven on fire", temp: 9001
      end
      io.to_s.should eq("FATA oven on fire temp=9001\n")
      error.fields.should eq([{"temp", 9001_i64}])
    end

    it "still raises when the level filters out fatal records" do
      io = IO::Memory.new
      log = Etch::Logger.new(io, level: :none)
      expect_raises(Etch::FatalError) { log.fatal "quiet but fatal. silent but deadly." }
      io.to_s.should be_empty
    end
  end

  describe "#emit" do
    it "stamps with the injected timestamp instead of the local system clock" do
      frozen = Time.utc(2021, 7, 5, 13, 4, 5)
      io = IO::Memory.new
      log = Etch::Logger.new(io, report_timestamp: true)
      log.emit(Etch::Level::Info, "backdated", timestamp: frozen)
      io.to_s.should eq("2021/07/05 13:04:05 INFO backdated\n")
    end

    it "applies time_function to consistently mutate an injected timestamp" do
      taken = Time.utc(2021, 7, 5, 13, 4, 5)
      io = IO::Memory.new
      log = Etch::Logger.new(io, report_timestamp: true, time_function: ->(t : Time) { t + 1.hour })
      log.emit(Etch::Level::Info, "shifted", timestamp: taken)
      io.to_s.should eq("2021/07/05 14:04:05 INFO shifted\n")
    end

    it "reports a fatal record without raising" do
      io = IO::Memory.new
      log = Etch::Logger.new(io)
      log.emit(Etch::Level::Fatal, "reported but not raised")
      io.to_s.should eq("FATA reported but not raised\n")
    end

    it "respects level filtering" do
      io = IO::Memory.new
      log = Etch::Logger.new(io, level: :error)
      log.emit(Etch::Level::Info, "negative")
      io.to_s.should be_empty
    end
  end

  describe "empty messages" do
    it "omits the message key when the message is empty" do
      io = IO::Memory.new
      log = Etch::Logger.new(io)
      log.info ""
      io.to_s.should eq("INFO\n")
    end

    it "omits the message key when the message is nil" do
      io = IO::Memory.new
      log = Etch::Logger.new(io)
      log.info nil, batch: 2
      io.to_s.should eq("INFO batch=2\n")
    end

    it "keeps a whitespace only message" do
      io = IO::Memory.new
      log = Etch::Logger.new(io)
      log.info " "
      # We expect this to be two spaces: a " " separator and the actual " " message content
      io.to_s.should eq("INFO#{" " * 2}\n")
    end
  end

  describe "timestamp and prefix" do
    it "renders the timestamp first and prefix before the message" do
      frozen = Time.local(2021, 7, 5, 13, 4, 5, location: Time::Location.fixed("here", -7 * 3600))
      io = IO::Memory.new
      log = Etch::Logger.new(io,
        report_timestamp: true,
        time_function: ->(_t : Time) { frozen },
        prefix: "baking",
      )
      log.info "cookies"
      io.to_s.should eq("2021/07/05 13:04:05 INFO baking: cookies\n")
    end
  end

  describe "caller reporting" do
    it "renders the short callsite by default" do
      io = IO::Memory.new
      log = Etch::Logger.new(io, report_caller: true)
      log.info "here"
      io.to_s.should match(/\AINFO <etch\/logger_spec\.cr:\d+> here\n\z/)
    end

    it "honors a non-default caller formatter" do
      io = IO::Memory.new
      log = Etch::Logger.new(io, report_caller: true, caller_formatter: Etch::LONG_CALLER_FORMATTER)
      log.info "here"
      io.to_s.should match(/\AINFO <\/.+logger_spec\.cr:\d+> here\n\z/)
    end

    it "reports the outer site when a wrapper forwards file and line" do
      io = IO::Memory.new
      log = Etch::Logger.new(io, report_caller: true)
      log.info "wrapped", __file: "outer.cr", __line: 7
      io.to_s.should eq("INFO <outer.cr:7> wrapped\n")
    end

    it "places the caller after the level and before the prefix" do
      io = IO::Memory.new
      log = Etch::Logger.new(io, report_caller: true, prefix: "baking")
      log.info "here", __file: "outer.cr", __line: 7
      io.to_s.should eq("INFO <outer.cr:7> baking: here\n")
    end

    it "supports invoking a custom caller formatter" do
      io = IO::Memory.new
      seen = [] of Tuple(String, Int32, String)
      formatter = Etch::CallerFormatter.new do |file, line, function|
        seen << {file, line, function}
        "#{file}@#{line}"
      end
      log = Etch::Logger.new(io, report_caller: true, caller_formatter: formatter)
      log.info "here", __file: "outer.cr", __line: 7
      seen.should eq([{"outer.cr", 7, ""}])
      io.to_s.should eq("INFO <outer.cr@7> here\n")
    end
  end

  describe "coercing values" do
    it "preserves numeric and bool types without stringifying" do
      io = IO::Memory.new
      log = Etch::Logger.new(io)
      child = log.with(n: 42, f: 3.5, b: true, s: "x")
      child.fields.should eq([
        {"n", 42_i64}, {"f", 3.5}, {"b", true}, {"s", "x"},
      ] of Tuple(String, Etch::Value))
    end
  end

  describe "#with" do
    it "appends fields to a new logger, leaving the parent unmodified" do
      io = IO::Memory.new
      log = Etch::Logger.new(io)
      child = log.with(batch: 2)
      child.info "derived"
      log.info "parent"
      log.fields.should be_empty
      io.to_s.should eq("INFO derived batch=2\nINFO parent\n")
    end

    it "accumulates across chained calls and keeps duped keys" do
      io = IO::Memory.new
      log = Etch::Logger.new(io)
      log.with(a: 1).with(a: 2).fields.should eq([
        {"a", 1_i64}, {"a", 2_i64},
      ] of Tuple(String, Etch::Value))
    end

    it "renders accumulated fields before callsite fields" do
      io = IO::Memory.new
      log = Etch::Logger.new(io)
      log.with(bound: 1).info "msg", call: 2
      io.to_s.should eq("INFO msg bound=1 call=2\n")
    end

    it "does modifies the child derived logger without mutating the parent's fields" do
      io = IO::Memory.new
      log = Etch::Logger.new(io, fields: [{"a", "1".as(Etch::Value)}])
      child = log.with(b: 2)
      child.fields << {"c", "3".as(Etch::Value)}
      log.fields.should eq([{"a", "1"}] of Tuple(String, Etch::Value))
    end
  end

  describe "#with_prefix" do
    it "returns a new logger with the given prefix" do
      io = IO::Memory.new
      log = Etch::Logger.new(io, prefix: "old")
      log.with_prefix("new").prefix.should eq("new")
      log.prefix.should eq("old")
    end

    it "preserves accumulated fields" do
      io = IO::Memory.new
      log = Etch::Logger.new(io, fields: [{"a", "1".as(Etch::Value)}])
      log.with_prefix("new").fields.should eq([{"a", "1"}] of Tuple(String, Etch::Value))
    end
  end

  describe "runtime keyed fields" do
    it "accepts a hash in place of double-splat fields" do
      io = IO::Memory.new
      log = Etch::Logger.new(io)
      log.info "payload", {"err" => "kitchen on fire", "batch" => 2}
      io.to_s.should eq(%(INFO payload err="kitchen on fire" batch=2\n))
    end

    it "matches the doublesplat form for similar input" do
      splat = IO::Memory.new
      runtime = IO::Memory.new
      Etch::Logger.new(splat).info "payload", err: "boom", n: 42
      Etch::Logger.new(runtime).info "payload", {"err" => "boom", "n" => 42}
      runtime.to_s.should eq(splat.to_s)
    end

    it "preserves order and dupe keys" do
      io = IO::Memory.new
      log = Etch::Logger.new(io)
      log.log(:info, "dupes", [{"k", "first"}, {"k", "second"}])
      io.to_s.should eq("INFO dupes k=first k=second\n")
    end

    it "appends to a sub-logger without modifying the parent" do
      io = IO::Memory.new
      parent = Etch::Logger.new(io)
      child = parent.with({"batch" => 2})
      child.fields.should eq([{"batch", 2_i64}] of Tuple(String, Etch::Value))
      parent.fields.should be_empty
    end

    it "emits no fields when receiving an empty input collection" do
      io = IO::Memory.new
      log = Etch::Logger.new(io)
      log.info "bare", {} of String => Etch::Value
      io.to_s.should eq("INFO bare\n")
    end
  end

  describe "concurrency safety" do
    it "avoids interleaving fragments of concurrent records" do
      io = IO::Memory.new
      log = Etch::Logger.new(io)
      done = Channel(Nil).new
      # 200.times { |i| spawn { log.info "record", seq: 1; done.send(nil) } }
      200.times do |i|
        spawn do
          log.info "record", seq: i
          done.send(nil)
        end
      end
      200.times do
        done.receive
      end

      lines = io.to_s.lines
      lines.size.should eq(200)
      lines.count(&.matches?(/\AINFO record seq=\d+\z/)).should eq(200)
    end
  end
end

describe "Etch.run" do
  it "returns normally when the block completes" do
    ran = false
    Etch.run { ran = true }
    ran.should be_true
  end

  it "propagates exceptions other than FatalError" do
    expect_raises(ArgumentError) { Etch.run { raise ArgumentError.new("other") } }
  end
end

describe "styles" do
  it "defaults to using Etch::Styles.default" do
    log = Etch::Logger.new(IO::Memory.new)
    log.styles.levels[Etch::Level::Info].value.should eq("INFO")
  end

  it "gives a child logger styles it can self-modify without modifying the parent" do
    parent = Etch::Logger.new(IO::Memory.new)
    child = parent.with(batch: 2)
    child.styles.levels[Etch::Level::Error] = Sheen::Style.new.string("BOOM")
    parent.styles.levels[Etch::Level::Error].value.should eq("ERROR")
  end
end

describe "renderer" do
  it "binds a renderer to the output during construction" do
    io = IO::Memory.new
    Etch::Logger.new(io).renderer.output.should be(io)
  end

  it "shares the renderer with children so a forced profile survives copying via #with" do
    log = Etch::Logger.new(IO::Memory.new)
    log.color_profile = Foundation::Profile::TrueColor
    child = log.with(batch: 2)
    child.color_profile.should eq(Foundation::Profile::TrueColor)
  end

  it "rebuilds the renderer when the output target changes" do
    log = Etch::Logger.new(IO::Memory.new)
    before = log.renderer
    second = IO::Memory.new
    log.output = second
    log.renderer.should_not be(before)
    log.renderer.output.should be(second)
    log.output.should be(second)
  end

  it "reads and forces the color profile through the bound renderer" do
    log = Etch::Logger.new(IO::Memory.new, env: Foundation::MockEnv.new)
    # Autodetected NoTTY from MockEnv
    log.color_profile.should eq(Foundation::Profile::NoTTY)
    log.color_profile = Foundation::Profile::ANSI256
    # Confirming that setting the color profile propagates through to the renderer
    log.renderer.color_profile.should eq(Foundation::Profile::ANSI256)
  end

  it "passes the injected env var through to profile detection" do
    forced = Etch::Logger.new(IO::Memory.new, env: Foundation::MockEnv.new({"FORCE_COLOR" => "1"}))
    forced.color_profile.should eq(Foundation::Profile::ANSI)

    disabled = Etch::Logger.new(IO::Memory.new, env: Foundation::MockEnv.new({"NO_COLOR" => "1"}))
    disabled.color_profile.should eq(Foundation::Profile::Ascii)
  end
end

describe "unleveled printing" do
  it "emits the message with no level label" do
    io = IO::Memory.new
    log = Etch::Logger.new(io)
    log.print "unleveled", batch: 2
    io.to_s.should eq("unleveled batch=2\n")
  end

  it "emits regardless of the configured level" do
    io = IO::Memory.new
    log = Etch::Logger.new(io, level: :fatal)
    log.print "still here bruh"
    io.to_s.should eq("still here bruh\n")
  end

  it "renders the block and sprintf versions too" do
    io = IO::Memory.new
    log = Etch::Logger.new(io)
    log.print { "lazy #{1 + 2}" }
    log.printf "%s has %d items", "cart", 3
    io.to_s.should eq("lazy 3\ncart has 3 items\n")
  end

  it "supports omitting the level key in JSON and logfmt too" do
    json = IO::Memory.new
    logfmt = IO::Memory.new
    Etch::Logger.new(json, formatter: :json).print "unleveled", batch: 2
    Etch::Logger.new(logfmt, formatter: :logfmt).print "unleveled", batch: 2

    json.to_s.should eq(%({"msg":"unleveled","batch":2}\n))
    logfmt.to_s.should eq("msg=unleveled batch=2\n")
  end
end

describe "formatter dispatch" do
  it "renders the same call in three different ways" do
    output_kinds = Etch::Formatter.values.map do |formatter|
      io = IO::Memory.new
      Etch::Logger.new(output: io, formatter: formatter).info "cookies", batch: 2
      io.to_s
    end

    output_kinds.should eq([
      "INFO cookies batch=2\n",
      %({"level":"info","msg":"cookies","batch":2}\n),
      "level=info msg=cookies batch=2\n",
    ])
  end

  it "supports live-swapping formatters on a logger" do
    io = IO::Memory.new
    log = Etch::Logger.new(io)
    log.info "first"
    log.formatter = :logfmt
    log.info "second"
    io.to_s.should eq("INFO first\nlevel=info msg=second\n")
  end

  it "keeps and applies the existing formatter into a sub-logger" do
    io = IO::Memory.new
    parent = Etch::Logger.new(io, formatter: :json)
    parent.with(batch: 2).info "child"
    io.to_s.should eq(%({"level":"info","msg":"child","batch":2}\n))
  end
end
