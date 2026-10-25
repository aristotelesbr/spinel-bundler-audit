# Runs bundler-audit 0.9.3 and spinel-bundler-audit on the same cases and
# compares stdout, stderr and exit status.
#
#   oracle/run.sh                              # the built binary
#   SPINEL_BUNDLER_AUDIT=path ruby oracle/compare.rb   # another build
#   ORACLE_NO_TTY=1 oracle/run.sh              # skip the cases run through script(1)
#
# Needs bundle-audit 0.9.3 on PATH. Writes its fixtures under tmp/cases.
require "open3"
require "fileutils"

ROOT = File.expand_path("..", __dir__)
DB = ENV.fetch("ORACLE_DB", File.join(ROOT, "tmp/ruby-advisory-db"))
CASES = File.join(ROOT, "tmp/cases")
IMPL = if (impl = ENV["SPINEL_BUNDLER_AUDIT"])
         [File.expand_path(impl, ROOT)]
       else
         [File.join(ROOT, "build/bin/spinel-bundler-audit")]
       end
ENV["BUNDLER_AUDIT_DB"] = DB
ENV["XDG_CACHE_HOME"] = File.join(ROOT, "tmp/cache")

# Fields that legitimately differ: the tool's name and version, timestamps.
def normalize(text)
  text.gsub("bundle-audit", "spinel-bundler-audit")
      .gsub(/"version":"[^"]*","created_at":"[^"]*"/, '"version":V,"created_at":T')
      .gsub(/"version": "[^"]*",\r?\n  "created_at": "[^"]*"/, '"version": V, "created_at": T')
      .gsub(/<testsuites id="\d+"/, '<testsuites id="T"')
end

def run(command, dir, tty)
  command = ["script", "-q", "/dev/null", *command] if tty
  out, err, status = Open3.capture3(*command, chdir: dir, stdin_data: "")
  out = normalize(out)
  err = normalize(err)
  if tty
    # script(1) sometimes doubles the CR of a line it relays; that is the terminal, not the tool.
    out = out.gsub("\r\r\n", "\r\n")
    err = err.gsub("\r\r\n", "\r\n")
  end
  [out, err, status.exitstatus]
end

$failures = []
$count = 0

# compare: :exact, or :status when bundle-audit crashes with a backtrace and
# only the exit status and the message are comparable.
def check(name, args, dir: CASES, tty: false, compare: :exact, message: nil, files: [])
  $count += 1
  ref = run(["bundle-audit", *args], dir, tty)
  ref_files = files.map { |f| File.exist?(f) ? normalize(File.read(f)) : nil }
  files.each { |f| FileUtils.rm_f(f) }
  ours = run([*IMPL, *args], dir, tty)
  our_files = files.map { |f| File.exist?(f) ? normalize(File.read(f)) : nil }
  ok = if compare == :exact
         ref == ours && ref_files == our_files
       else
         ref[2] == ours[2] && (message.nil? || (ref[1].include?(message) && (ours[1] + ours[0]).include?(message)))
       end
  return if ok

  $failures << name
  warn "DIFF #{name}: #{args.join(' ')}"
  warn "  bundle-audit exit=#{ref[2]} spinel-bundler-audit exit=#{ours[2]}"
  [[ref[0], ours[0], "stdout"], [ref[1], ours[1], "stderr"]].each do |a, b, label|
    next if a == b

    a_lines = a.lines
    b_lines = b.lines
    first = (0...[a_lines.size, b_lines.size].max).find { |i| a_lines[i] != b_lines[i] }
    warn "  #{label} line #{first + 1}:\n    < #{a_lines[first].inspect}\n    > #{b_lines[first].inspect}"
  end
end

# Options follow optparse here, a documented difference from bundler-audit.
def check_own(name, args, stdout:, stderr:, status:)
  $count += 1
  out, err, code = run([*IMPL, *args], CASES, false)
  return if out.include?(stdout) && err.include?(stderr) && code == status

  $failures << name
  warn "DIFF #{name}: #{args.join(' ')}\n  got exit=#{code} stdout=#{out[0, 200].inspect} stderr=#{err[0, 200].inspect}"
end

def lockfile(name, body)
  File.write(File.join(CASES, name), body)
  name
end

def gem_lock(specs, remote: "https://rubygems.org/", extra: "")
  "GEM\n  remote: #{remote}\n  specs:\n#{specs.map { |s| "    #{s}\n" }.join}#{extra}\nPLATFORMS\n  ruby\n\nDEPENDENCIES\n\nBUNDLED WITH\n   2.6.2\n"
end

FileUtils.rm_rf(CASES)
FileUtils.mkdir_p(CASES)
File.write(File.join(CASES, "Gemfile"), "")

# 1. Version boundaries: every gem in the database at versions on and
# around each boundary its advisories mention, text format.
candidates = {}
Dir.children(File.join(DB, "gems")).sort.each do |name|
  versions = Dir.glob("#{DB}/gems/#{name}/*.yml").flat_map { |f| File.read(f).scan(/[0-9]+(?:\.[0-9a-zA-Z]+)+/) }.uniq
  extra = versions.flat_map do |v|
    parts = v.split(".")
    up = parts.dup
    up[-1] = (up[-1].to_i + 1).to_s if up[-1].match?(/\A\d+\z/)
    down = parts.dup
    down[-1] = (down[-1].to_i - 1).to_s if down[-1].match?(/\A\d+\z/) && down[-1].to_i > 0
    [up.join("."), down.join("."), "#{v}.rc1", "#{v}.0"]
  end
  candidates[name] = (["0.1", "999.0"] + versions + extra).uniq.reject { |v| v.match?(/\A\d{4}\.\d{1,2}\.\d{1,2}\z/) }
end
rounds = candidates.values.map(&:size).max
boundary_locks = (0...rounds).map do |k|
  specs = candidates.filter_map { |name, list| "#{name} (#{list[k]})" if list[k] }
  lockfile(format("boundary-%03d.lock", k), gem_lock(specs))
end
boundary_locks.each { |lock| check("boundary #{lock}", ["check", "-G", lock]) }
sample = boundary_locks.each_slice(40).map(&:first)

# 2. Formats and options on a sample of those lockfiles.
sample.each do |lock|
  check("json #{lock}", ["check", "-G", lock, "-F", "json"])
  check("junit #{lock}", ["check", "-G", lock, "-F", "junit"])
  check("verbose #{lock}", ["check", "-G", lock, "--verbose"])
  check("quiet #{lock}", ["check", "-G", lock, "-q"])
  check("quiet verbose #{lock}", ["check", "-G", lock, "-q", "-v"])
  check("quiet json #{lock}", ["check", "-G", lock, "-q", "-F", "json"])
  out = File.join(CASES, "report.out")
  check("output #{lock}", ["check", "-G", lock, "-o", out], files: [out])
  check("output json #{lock}", ["check", "-G", lock, "-F", "json", "-o", out], files: [out])
end

# 3. Terminal output: colors and pretty JSON.
small = lockfile("small.lock", gem_lock(["rack (2.2.3)", "rexml (3.2.4)", "nokogiri (1.10.0)"], remote: "http://rubygems.org/"))
clean = lockfile("clean.lock", gem_lock(["zzz-nothing (1.0)"]))
unless ENV["ORACLE_NO_TTY"]
  check("tty text", ["check", "-G", small], tty: true)
  check("tty verbose", ["check", "-G", small, "-v"], tty: true)
  check("tty json", ["check", "-G", small, "-F", "json"], tty: true)
  check("tty junit", ["check", "-G", small, "-F", "junit"], tty: true)
  check("tty clean", ["check", "-G", clean], tty: true)
end
check("clean", ["check", "-G", clean])
check("clean quiet", ["check", "-G", clean, "-q"])

# 4. Ignore lists, from the command line and from the config file.
check("ignore one", ["check", "-G", small, "-i", "CVE-2022-30122"])
check("ignore many", ["check", "-G", small, "-i", "CVE-2022-30122", "CVE-2022-30123", "GHSA-hxqx-xwvh-44m2"])
check("ignore attached", ["check", "-G", small, "--ignore=CVE-2022-30122", "CVE-2022-30123"])
check("ignore swallows dir", ["check", "-G", small, "-i", "CVE-2022-30122", "."])
configs = {
  "config-ok.yml" => "---\nignore:\n  - CVE-2022-30122\n  - GHSA-wq4h-7r42-5hrr\n",
  "config-other-keys.yml" => "foo: bar\nignore: [CVE-2022-30123]\n",
  "config-empty-ignore.yml" => "ignore: []\n"
}
configs.each do |file, body|
  File.write(File.join(CASES, file), body)
  check(file, ["check", "-G", small, "-c", file])
  check("#{file} overridden by -i", ["check", "-G", small, "-c", file, "-i", "CVE-2024-25126"])
end
broken = {
  "config-not-hash.yml" => ["- a\n- b\n", "is not a Hash"],
  "config-scalar.yml" => ["hello\n", "is not a Hash"],
  "config-empty.yml" => ["", "is not YAML"],
  "config-ignore-string.yml" => ["ignore: CVE-1\n", "but is not an Array"],
  "config-ignore-nested.yml" => ["ignore:\n  - [a, b]\n", "contains a non-String"]
}
broken.each do |file, (body, message)|
  File.write(File.join(CASES, file), body)
  check(file, ["check", "-G", small, "-c", file], compare: :status, message: message)
end
FileUtils.mkdir_p(File.join(CASES, "dotfile"))
File.write(File.join(CASES, "dotfile/Gemfile"), "")
File.write(File.join(CASES, "dotfile/Gemfile.lock"), gem_lock(["rack (2.2.3)"]))
File.write(File.join(CASES, "dotfile/.bundler-audit.yml"), "ignore:\n  - CVE-2022-30122\n")
check("default dotfile", ["check", "dotfile"])
check("dotfile from inside", ["check"], dir: File.join(CASES, "dotfile"))

# 5. Lockfile shapes: sources, platforms, pins, checksums, duplicates.
shapes = {
  "two-public-remotes.lock" => "GEM\n  remote: http://index.rubygems.org/\n  remote: http://rubygems.org/\n  specs:\n    rack (2.2.3)\n\nPLATFORMS\n  ruby\n",
  "two-remotes.lock" => "GEM\n  remote: http://a.example.com/\n  remote: http://rubygems.org\n  specs:\n    rack (2.2.3)\n\nPLATFORMS\n  ruby\n",
  "git-sources.lock" => "GIT\n  remote: git://github.com/x/y.git\n  revision: abc\n  specs:\n    y (0.1.0)\n\nGIT\n  remote: http://github.com/x/z.git\n  revision: def\n  specs:\n    z (0.2.0)\n\nGIT\n  remote: https://github.com/x/w.git\n  revision: 123\n  specs:\n    w (0.3.0)\n\nGEM\n  remote: https://rubygems.org/\n  specs:\n    rack (2.0.1)\n\nPLATFORMS\n  ruby\n",
  "internal.lock" => "GEM\n  remote: http://localhost:9292/\n  remote: http://10.1.2.3/\n  remote: http://192.168.0.10:8080/\n  remote: http://127.0.0.1/\n  specs:\n    rack (2.2.3)\n\nGIT\n  remote: http://localhost/x/y.git\n  revision: abc\n  specs:\n    y (0.1.0)\n\nPLATFORMS\n  ruby\n",
  "path-source.lock" => "PATH\n  remote: engines/blog\n  specs:\n    blog (0.1.0)\n      rails (>= 7.0)\n\nGEM\n  remote: https://rubygems.org/\n  specs:\n    nokogiri (1.10.0)\n    nokogiri (1.10.0-x86_64-linux)\n    nokogiri (1.10.0-arm64-darwin)\n    rack (2.2.3)\n      webrick (>= 1.0)\n    rack (2.2.3)\n    webrick (1.7.0)\n\nPLATFORMS\n  ruby\n",
  "checksums.lock" => "GEM\n  remote: https://rubygems.org/\n  specs:\n    actionpack (7.0.0)\n    rack (2.2.3)\n\nPLATFORMS\n  ruby\n\nDEPENDENCIES\n  rack!\n\nCHECKSUMS\n  actionpack (7.0.0) sha256=0000000000000000000000000000000000000000000000000000000000000000\n  rack (2.2.3) sha256=0000000000000000000000000000000000000000000000000000000000000000\n\nBUNDLED WITH\n   2.6.2\n",
  "prerelease.lock" => gem_lock(["rails (7.1.0.rc1)", "actionpack (7.1.0.beta1)", "rack (3.0.0.beta1)", "nokogiri (1.16.0.rc1)"]),
  "unsorted.lock" => gem_lock(["zeitwerk (2.0.0)", "rack (2.0.0)", "actionpack (5.0.0)", "Rack (1.0.0)", "rack-cors (0.1.0)"])
}
FileUtils.mkdir_p(File.join(CASES, "engines/blog"))
File.write(File.join(CASES, "engines/blog/blog.gemspec"), "Gem::Specification.new { |s| s.name = 'blog'; s.version = '0.1.0'; s.summary = 'x'; s.authors = ['x'] }\n")
shapes.each do |file, body|
  lockfile(file, body)
  check(file, ["check", "-G", file])
  check("#{file} json", ["check", "-G", file, "-F", "json"])
end

# 6. Command line: defaults, prefixes, errors.
FileUtils.mkdir_p(File.join(CASES, "app"))
File.write(File.join(CASES, "app/Gemfile"), "")
File.write(File.join(CASES, "app/Gemfile.lock"), gem_lock(["rack (2.2.3)"]))
check("no command", [], dir: File.join(CASES, "app"))
check("options only", ["-q"], dir: File.join(CASES, "app"))
check("prefix che", ["che", "app"])
check("dir argument", ["check", "app"])
check("missing dir", ["check", "/nonexistent-dir"])
check("missing dir quiet", ["check", "/nonexistent-dir", "-q"])
check_own("unknown option is an error", ["check", "--bogus"], stdout: "", stderr: "invalid option: --bogus", status: 1)
check("missing lockfile", ["check", "-G", "nope.lock"])
check("missing lockfile quiet", ["check", "-G", "nope.lock", "-q"])
check("unknown format", ["check", "-F", "xml"])
check("format before db", ["check", "-F", "xml", "-D", "/nonexistent-db"])
check("extra arguments", ["check", ".", "extra"])
check("unknown command", ["bogus"])
check_own("attached short value", ["check", "-Gsmall.lock"], stdout: "Vulnerabilities found!", stderr: "", status: 1)
check("no-quiet then quiet", ["check", "-G", small, "--no-quiet", "-q"])
check("database option", ["check", "-G", small, "-D", DB])
check("stats", ["stats"])
check("stats path", ["stats", DB])

# 7. Database maintenance on throwaway copies, so nothing touches the
# network: a git checkout whose origin is a local mirror, and a copy that
# is not a git checkout.
work = File.join(CASES, "db")
mirror = File.join(work, "mirror.git")
FileUtils.mkdir_p(work)
system("git", "clone", "--quiet", "--bare", DB, mirror, exception: true)
prepare = lambda do |name|
  path = File.join(work, name)
  FileUtils.rm_rf(path)
  system("git", "clone", "--quiet", mirror, path, exception: true)
  system("git", "-C", path, "reset", "--quiet", "--hard", "HEAD~3", exception: true)
  path
end
plain = File.join(work, "plain")
FileUtils.rm_rf(plain)
FileUtils.cp_r(DB, plain)
FileUtils.rm_rf(File.join(plain, ".git"))
File.utime(Time.at(1_700_000_000), Time.at(1_700_000_000), plain)

[["update", false], ["update quiet", true]].each do |name, quiet|
  $count += 1
  results = [["bundle-audit"], IMPL].map do |tool|
    path = prepare.call("checkout")
    out = run([*tool, "update", path, *(quiet ? ["-q"] : [])], CASES, false)
    out + [`git -C #{path} rev-parse HEAD`]
  end
  next if results[0] == results[1]

  $failures << name
  warn "DIFF #{name}:\n  < #{results[0].inspect[0, 400]}\n  > #{results[1].inspect[0, 400]}"
end
check("update not git", ["update", plain])
check("stats not git", ["stats", plain])
check("download existing", ["download", DB])
[["check --update", false], ["check --update quiet", true]].each do |name, quiet|
  $count += 1
  results = [["bundle-audit"], IMPL].map do |tool|
    path = prepare.call("checkout")
    out = run([*tool, "check", "-G", small, "-D", path, "--update", *(quiet ? ["-q"] : [])], CASES, false)
    out + [`git -C #{path} rev-parse HEAD`]
  end
  next if results[0] == results[1]

  $failures << name
  warn "DIFF #{name}:\n  < #{results[0].inspect[0, 400]}\n  > #{results[1].inspect[0, 400]}"
end

# 8. Real lockfiles: the open-source apps of oracle/APPS, as
# oracle/fetch-apps.sh downloads them.
File.readlines(File.join(ROOT, "oracle/APPS")).each do |line|
  name = line.split.first
  app = File.join(ROOT, "tmp/apps", name)
  next unless File.directory?(app)

  check("app #{name}", ["check"], dir: app)
  check("app #{name} verbose", ["check", "-v"], dir: app)
  check("app #{name} json", ["check", "-F", "json"], dir: app)
end

puts "#{$count - $failures.size}/#{$count} cases identical"
puts "failing (first 20): #{$failures.first(20).join(", ")}" unless $failures.empty?
exit($failures.empty? ? 0 : 1)
