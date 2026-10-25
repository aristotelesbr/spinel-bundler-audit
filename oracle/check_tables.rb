# Checks the expected answers in test/fixtures against the real libraries,
# so no expectation in the unit tests is made up. Runs under CRuby:
#
#   ruby oracle/check_tables.rb
require "bundler"
require "ipaddr"
require "json"
require_relative "../test/fixtures/json_sample"

$LOAD_PATH.unshift(File.expand_path("..", __dir__))
require "spinel_bundler_audit"

FIXTURES = File.expand_path("../test/fixtures", __dir__)
ORDER = { "<" => -1, "=" => 0, ">" => 1 }.freeze
SUBNETS = %w[10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 fc00::/7 127.0.0.0/8 ::1/128]
          .map { |subnet| IPAddr.new(subnet) }

$failures = 0
$checked = 0

def rows(name)
  File.read(File.join(FIXTURES, name)).each_line.map(&:chomp)
      .reject { |line| line.empty? || line.start_with?("#") }
end

def expect(label, expected, actual)
  $checked += 1
  return if expected == actual

  $failures += 1
  warn "#{label}: table says #{expected.inspect}, real library says #{actual.inspect}"
end

rows("version_cases.txt").each do |line|
  left, op, right = line.split(" ")
  expect(line, ORDER.fetch(op), Gem::Version.new(left) <=> Gem::Version.new(right))
end

rows("requirement_cases.txt").each do |line|
  requirement, version, satisfied = line.split(" | ")
  actual = Gem::Requirement.new(*requirement.split(", ")).satisfied_by?(Gem::Version.new(version))
  expect(line, satisfied, actual.to_s)
end

rows("requirement_text_cases.txt").each do |line|
  written, printed = line.split(" | ")
  expect(line, printed, Gem::Requirement.new(*written.split(", ")).to_s)
end

rows("ip_cases.txt").each do |line|
  ip, internal = line.split(" | ")
  expect(line, internal, SUBNETS.any? { |subnet| subnet.include?(ip) }.to_s)
end

expect("release of 1.0.rc1", "1.0", Gem::Version.new("1.0.rc1").release.to_s)
expect("bump of 2.1.3", "2.2", Gem::Version.new("2.1.3").bump.to_s)
expect("spelling of 4.0.0-beta.2", "4.0.0.pre.beta.2", Gem::Version.new("4.0.0-beta.2").to_s)

Dir.glob(File.join(FIXTURES, "lockfiles", "*.lock")).sort.each do |path|
  name = File.basename(path)
  bundler = Bundler::LockfileParser.new(File.read(path))
  ours = SpinelBundlerAudit::Lockfile.read(path)
  expect("#{name} gems", bundler.specs.map(&:full_name), ours.gems.map(&:full_name))
  remotes = bundler.sources.flat_map do |source|
    source.respond_to?(:remotes) ? source.remotes.map(&:to_s) : [source.uri.to_s]
  end
  expect("#{name} remotes", remotes, ours.sources.flat_map(&:remotes))
end

data = { "text" => "quote\" back\\ nl\n tab\t ctl\u0001 é /", "empty" => [], "none" => {},
         "numbers" => [1, 2.5], "nested" => { "k" => nil, "list" => ["a", "b"] } }
expect("compact JSON", JSON.generate(data), json_sample(SpinelBundlerAudit::JsonWriter.new(false)))
expect("pretty JSON", JSON.pretty_generate(data), json_sample(SpinelBundlerAudit::JsonWriter.new(true)))

puts "#{$checked - $failures}/#{$checked} table rows match the real libraries"
exit($failures.zero? ? 0 : 1)
