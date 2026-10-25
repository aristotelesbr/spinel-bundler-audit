require "spinel_bundler_audit"

CASES = File.expand_path("fixtures/version_cases.txt", __dir__)
ORDER = { "<" => -1, "=" => 0, ">" => 1 }.freeze

def version(text)
  SpinelBundlerAudit::GemVersion.new(text)
end

count = 0
File.read(CASES).each_line do |raw|
  line = raw.chomp
  next if line.empty? || line.start_with?("#")

  left, op, right = line.split(" ")
  got = version(left) <=> version(right)
  raise "#{line}: got #{got}" unless got == ORDER[op]

  count += 1
end

puts "release #{version("1.0.rc1").release}"
puts "bump #{version("2.1.3").bump}"
puts "normalized #{version("4.0.0-beta.2").normalized}"
puts "#{count} version cases"
