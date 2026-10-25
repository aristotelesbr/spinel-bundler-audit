require "spinel_bundler_audit"

CASES = File.expand_path("fixtures/ip_cases.txt", __dir__)

count = 0
File.read(CASES).each_line do |raw|
  line = raw.chomp
  next if line.empty? || line.start_with?("#")

  ip, expected = line.split(" | ")
  got = SpinelBundlerAudit::Scanner.internal_ip?(ip)
  raise "#{line}: got #{got}" unless got.to_s == expected

  count += 1
end

puts "#{count} address cases"
