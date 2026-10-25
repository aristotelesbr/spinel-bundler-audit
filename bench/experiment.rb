# Compares bundler-audit 0.9.3 with a spinel-bundler-audit release binary,
# as bench/README.md describes:
#
#   ruby bench/experiment.rb                 # every step, results in tmp/bench/<date>-<machine>/
#   ruby bench/experiment.rb prepare         # download the release binary, record the machine
#   ruby bench/experiment.rb equivalence     # same output before any timing
#   ruby bench/experiment.rb measure         # hyperfine: time, peak memory, instructions
#   ruby bench/experiment.rb check           # every run exited as expected
#   ruby bench/experiment.rb analyze [DIR]   # RESULTS.md from the raw files (also a committed DIR)
#   ruby bench/experiment.rb tokens          # optional: output tokens (needs Python's tiktoken)
#
# Needs bundler-audit 0.9.3, hyperfine 2.0 or newer, and tmp/ prepared by
# oracle/run.sh (the advisory database at oracle/DB_REVISION, the generated
# lockfiles and the apps in oracle/APPS). VERSION picks the release (default
# 0.1.0), BINARY a local executable instead, OUT the results directory,
# ROUNDS and RUNS the repetitions (default 3 and 50).
require "digest"
require "fileutils"
require "json"
require "open3"
require "socket"

ROOT = File.expand_path("..", __dir__)
DB = File.join(ROOT, "tmp/ruby-advisory-db")
CASES_DIR = File.join(ROOT, "tmp/cases")
APPS = File.join(ROOT, "tmp/apps")
VERSION = ENV.fetch("VERSION", "0.1.0")
ROUNDS = Integer(ENV.fetch("ROUNDS", "3"))
RUNS = ENV.fetch("RUNS", "50")

# name, directory, arguments after "check"
CASES = [
  ["clean", CASES_DIR, %w[-G clean.lock]],
  ["mastodon", File.join(APPS, "mastodon"), []],
  ["discourse", File.join(APPS, "discourse"), []],
  ["forem", File.join(APPS, "forem"), []],
  ["synthetic", CASES_DIR, %w[-G boundary-000.lock]],
  ["forem-json", File.join(APPS, "forem"), %w[-F json]]
].freeze
FIRST_RUN = "first-run"
TOOLS = ["bundler-audit", "spinel-bundler-audit"].freeze

def platform
  case [RbConfig::CONFIG["host_os"], RbConfig::CONFIG["host_cpu"]]
  in [/darwin/, "arm64" | "aarch64"] then "macos-arm64"
  in [/linux/, "x86_64"] then "linux-x86_64"
  in [/linux/, "aarch64" | "arm64"] then "linux-arm64"
  else abort "no release binary for #{RbConfig::CONFIG['host_os']} #{RbConfig::CONFIG['host_cpu']}"
  end
end

def out_dir
  ENV.fetch("OUT") do
    host = Socket.gethostname.split(".").first.downcase.gsub(/[^a-z0-9-]/, "-")
    File.join(ROOT, "tmp/bench", "#{Time.now.strftime('%Y-%m-%d')}-#{host}")
  end
end

OUT = out_dir
BIN = ENV.fetch("BINARY") { File.join(OUT, "bin/spinel-bundler-audit") }
CACHE = File.join(OUT, "cache")
ENV["BUNDLER_AUDIT_DB"] = DB
ENV["XDG_CACHE_HOME"] = CACHE

def bundler_audit(args) = ["bundle-audit", "check", "--no-update", *args]
def spinel_bundler_audit(args) = [BIN, "check", *args]

def run!(*command, chdir: ROOT)
  output, status = Open3.capture2e(*command, chdir: chdir)
  abort "failed: #{command.join(' ')}\n#{output}" unless status.success?
  output
end

def load_average = `uptime`[/load averages?: (.*)/, 1].to_s.strip

def write(name, text)
  FileUtils.mkdir_p(OUT)
  File.write(File.join(OUT, name), text)
  puts "-> #{File.join(OUT, name).delete_prefix("#{ROOT}/")}"
end

def build_index
  system(BIN, "check", "-G", "clean.lock", chdir: CASES_DIR, out: File::NULL)
end

def prepare
  abort "run oracle/run.sh first: it prepares tmp/" unless File.exist?(File.join(CASES_DIR, "boundary-000.lock"))
  unless ENV["BINARY"]
    package = "spinel-bundler-audit-#{VERSION}-#{platform}"
    url = "https://github.com/aristotelesbr/spinel-bundler-audit/releases/download/v#{VERSION}"
    dir = File.dirname(BIN)
    FileUtils.mkdir_p(dir)
    run!("curl", "-fsSLO", "#{url}/#{package}.tar.gz", chdir: dir)
    run!("curl", "-fsSLO", "#{url}/SHA256SUMS", chdir: dir)
    expected = File.readlines(File.join(dir, "SHA256SUMS")).find { _1.include?("#{package}.tar.gz") }&.split&.first
    abort "#{package}.tar.gz does not match SHA256SUMS" unless expected == Digest::SHA256.file(File.join(dir, "#{package}.tar.gz")).hexdigest
    run!("tar", "xzf", "#{package}.tar.gz", chdir: dir)
    FileUtils.cp(File.join(dir, package, "spinel-bundler-audit"), BIN)
  end
  build_index
  inputs = CASES.to_h do |name, dir, args|
    lockfile = File.join(dir, args[args.index("-G") + 1]) if args.include?("-G")
    lockfile ||= File.join(dir, "Gemfile.lock")
    [name, Digest::SHA256.file(lockfile).hexdigest]
  end
  machine = if RbConfig::CONFIG["host_os"].include?("darwin")
              { cpu: `sysctl -n machdep.cpu.brand_string`.strip, memory_gib: `sysctl -n hw.memsize`.to_i / 1024**3,
                cores: `sysctl -n hw.ncpu`.to_i, os: "macOS #{`sw_vers -productVersion`.strip}" }
            else
              { cpu: File.read("/proc/cpuinfo")[/model name\s*:\s*(.*)/, 1], cores: `nproc`.to_i,
                os: File.read("/etc/os-release")[/PRETTY_NAME="(.*)"/, 1] }
            end
  write("environment.json", JSON.pretty_generate(
    date: Time.now.to_s, **machine, platform: platform, ruby: `ruby -v`.strip,
    bundler_audit: `bundle-audit version`.strip, spinel_bundler_audit: `#{BIN} version`.strip,
    binary_sha256: Digest::SHA256.file(BIN).hexdigest, hyperfine: `hyperfine --version`.strip,
    ruby_advisory_db: `git -C #{DB} rev-parse HEAD`.strip, advisories: Dir.glob(File.join(DB, "gems/*/*.yml")).size,
    apps: File.readlines(File.join(ROOT, "oracle/APPS")).to_h { |line| line.split.then { [_1, "#{_2}@#{_3}"] } },
    lockfile_sha256: inputs, load_average: load_average
  ))
end

# The output both tools are expected to share; the tool's name and version
# and the json timestamp are the only fields allowed to differ.
def normalized(command, dir)
  out, err, status = Open3.capture3(*command, chdir: dir)
  [out, err].map do |text|
    text.gsub("bundle-audit", "spinel-bundler-audit")
        .gsub(/"version":"[^"]*","created_at":"[^"]*"/, '"version":V,"created_at":T')
  end + [status.exitstatus]
end

def equivalence
  rows = CASES.map do |name, dir, args|
    a = normalized(bundler_audit(args), dir)
    b = normalized(spinel_bundler_audit(args), dir)
    puts "#{name}: #{a == b ? 'identical' : 'DIFFERENT'} (exit #{a[2]} / #{b[2]})"
    { case: name, identical: a == b, exit_status: a[2], stdout_bytes: a[0].bytesize }
  end
  write("equivalence.json", JSON.pretty_generate(rows))
  abort "outputs differ: timings would compare different work" unless rows.all? { _1[:identical] }
end

def hyperfine(dir, commands, file, extra = [])
  command = ["hyperfine", "-N", "-i", "--warmup", "5", "--runs", RUNS, "--export-json", file, *extra]
  commands.each { |label, argv| command += ["-n", label, argv.join(" ")] }
  system(*command, chdir: dir, exception: true)
end

def measure
  raw = File.join(OUT, "raw")
  FileUtils.mkdir_p(raw)
  loads = []
  (1..ROUNDS).each do |round|
    loads << { round: round, before: load_average }
    CASES.each do |name, dir, args|
      pair = [["bundler-audit", bundler_audit(args)], ["spinel-bundler-audit", spinel_bundler_audit(args)]]
      # Alternate which tool runs first, so drift does not favor either.
      pair.reverse! if round.even?
      puts "== #{name}, round #{round}"
      hyperfine(dir, pair, File.join(raw, "#{name}-r#{round}.json"))
    end
    puts "== #{FIRST_RUN}, round #{round}"
    hyperfine(File.join(APPS, "mastodon"), [["spinel-bundler-audit", spinel_bundler_audit([])]],
              File.join(raw, "#{FIRST_RUN}-r#{round}.json"), ["--prepare", "rm -rf #{CACHE}/spinel-bundler-audit"])
    build_index
    loads.last[:after] = load_average
  end
  write("load.json", JSON.pretty_generate(loads))
end

# hyperfine 2.0 records the command line, not the -n label.
def tool(command) = command.start_with?("bundle-audit") ? "bundler-audit" : "spinel-bundler-audit"

def runs(dir)
  data = Hash.new { |h, k| h[k] = Hash.new { |hh, kk| hh[kk] = [] } }
  Dir.glob(File.join(dir, "raw", "*.json")).sort.each do |file|
    name, round = File.basename(file, ".json").match(/\A(.+)-r(\d+)\z/).captures
    JSON.parse(File.read(file))["results"].each do |result|
      result["measurements"].each do |m|
        data[name][tool(result["command"])] << {
          round: round.to_i, exit_code: m["exit_code"],
          time: m["time_wall_clock"]["value"], memory: m["memory_peak_resident"]["value"],
          instructions: m.dig("instructions", "value")
        }
      end
    end
  end
  data
end

def check(dir = OUT)
  expected = JSON.parse(File.read(File.join(dir, "equivalence.json"))).to_h { [_1["case"], _1["exit_status"]] }
  expected[FIRST_RUN] = expected["mastodon"]
  ok = true
  runs(dir).each do |name, by_tool|
    by_tool.each do |t, rows|
      codes = rows.map { _1[:exit_code] }.tally
      good = codes.keys == [expected[name]]
      ok &&= good
      puts "#{good ? 'ok' : 'UNEXPECTED'}  #{name} #{t}: #{rows.size} runs, exit codes #{codes}"
    end
  end
  abort "some runs exited unexpectedly" unless ok
end

def median(xs)
  s = xs.sort
  s.size.odd? ? s[s.size / 2] : (s[s.size / 2 - 1] + s[s.size / 2]) / 2.0
end

def quartiles(xs) = xs.sort.then { |s| [s[(s.size * 0.25).floor], s[(s.size * 0.75).floor]] }

# 95% confidence interval of median(a) / median(b), by bootstrap.
def ratio_interval(a, b, samples = 10_000, rng = Random.new(42))
  ratios = Array.new(samples) do
    median(Array.new(a.size) { a[rng.rand(a.size)] }) / median(Array.new(b.size) { b[rng.rand(b.size)] })
  end.sort
  [ratios[(samples * 0.025).floor], ratios[(samples * 0.975).floor]]
end

def ms(seconds) = format("%.1f", seconds * 1000)
def mib(bytes) = format("%.1f", bytes / 1024.0 / 1024)

def analyze(dir = OUT)
  env = JSON.parse(File.read(File.join(dir, "environment.json")))
  loads = JSON.parse(File.read(File.join(dir, "load.json")))
  data = runs(dir)
  missing = CASES.map(&:first).reject { |name| TOOLS.all? { data[name][_1].any? } }
  abort "missing measurements: #{missing.join(', ')}" unless missing.empty?

  md = +"# Results: #{File.basename(dir)}\n\nMethod: [bench/README.md](../../README.md).\n\n## Machine\n\n| Item | Value |\n|---|---|\n"
  env.each { |k, v| md << "| #{k} | #{v.is_a?(Hash) ? v.map { "#{_1} #{_2}" }.join(', ') : v} |\n" }
  md << "\nLoad average before → after each round: #{loads.map { "#{_1['round']}: #{_1['before']} → #{_1['after']}" }.join('; ')}\n"
  md << "\n## Time\n\nMedian wall time (interquartile range) over all rounds; the ratio's 95% confidence interval is a bootstrap of the medians.\n\n"
  md << "| Case | bundler-audit | spinel-bundler-audit | ratio | 95% CI | per-round medians |\n|---|---:|---:|---:|---|---|\n"
  CASES.each do |name, _, _|
    a = data[name]["bundler-audit"]
    b = data[name]["spinel-bundler-audit"]
    ta = a.map { _1[:time] }
    tb = b.map { _1[:time] }
    low, high = ratio_interval(ta, tb)
    rounds = a.map { _1[:round] }.uniq.sort.map do |r|
      "#{r}: #{ms(median(a.select { _1[:round] == r }.map { _1[:time] }))} / #{ms(median(b.select { _1[:round] == r }.map { _1[:time] }))}"
    end.join("; ")
    md << "| #{name} | #{ms(median(ta))} ms (#{quartiles(ta).map { ms(_1) }.join('–')}) | #{ms(median(tb))} ms (#{quartiles(tb).map { ms(_1) }.join('–')}) " \
          "| #{format('%.1f', median(ta) / median(tb))}x | #{format('%.1f', low)}–#{format('%.1f', high)}x | #{rounds} |\n"
  end
  first = data[FIRST_RUN]["spinel-bundler-audit"].map { _1[:time] }
  md << "\n**#{FIRST_RUN}:** spinel-bundler-audit on mastodon with the index removed before every run: #{ms(median(first))} ms (#{quartiles(first).map { ms(_1) }.join('–')}).\n" if first.any?
  md << "\n## Peak memory and instructions (medians)\n\n| Case | bundler-audit | spinel-bundler-audit | instructions, bundler-audit | instructions, spinel-bundler-audit |\n|---|---:|---:|---:|---:|\n"
  CASES.each do |name, _, _|
    a = data[name]["bundler-audit"]
    b = data[name]["spinel-bundler-audit"]
    instr = [a, b].map { |rows| rows.first[:instructions] ? format("%.0f M", median(rows.map { _1[:instructions] }) / 1e6) : "n/a" }
    md << "| #{name} | #{mib(median(a.map { _1[:memory] }))} MiB | #{mib(median(b.map { _1[:memory] }))} MiB | #{instr[0]} | #{instr[1]} |\n"
  end
  File.write(File.join(dir, "RESULTS.md"), md)
  puts "-> #{File.join(dir, 'RESULTS.md').delete_prefix("#{ROOT}/")}"
end

def tokens
  count = lambda do |text|
    out, status = Open3.capture2(ENV.fetch("PYTHON", "python3"), "-c",
                                 "import sys, tiktoken; print(len(tiktoken.get_encoding('o200k_base').encode(sys.stdin.read())))",
                                 stdin_data: text)
    abort "tokens needs Python with tiktoken (pip install tiktoken)" unless status.success?
    out.to_i
  end
  rows = CASES.flat_map do |name, dir, args|
    [["bundler-audit", bundler_audit(args)], ["spinel-bundler-audit", spinel_bundler_audit(args)]].map do |t, command|
      out, err, = Open3.capture3(*command, chdir: dir)
      { case: name, tool: t, bytes: (out + err).bytesize, tokens_o200k: count.call(out + err) }.tap { puts "#{name} #{t}: #{_1[:tokens_o200k]} tokens" }
    end
  end
  write("tokens.json", JSON.pretty_generate(rows))
end

case ARGV.first
when nil
  prepare
  equivalence
  measure
  check
  analyze
when "prepare" then prepare
when "equivalence" then equivalence
when "measure" then measure
when "check" then check(ARGV[1] ? File.expand_path(ARGV[1]) : OUT)
when "analyze" then analyze(ARGV[1] ? File.expand_path(ARGV[1]) : OUT)
when "tokens" then tokens
else abort File.read(__FILE__).lines.drop(1).take_while { _1.start_with?("#") }.join.gsub(/^# ?/, "")
end
