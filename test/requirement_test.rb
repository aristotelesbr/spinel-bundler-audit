require "spinel_bundler_audit"

FIXTURES = File.expand_path("fixtures", __dir__)

def rows(name)
  File.read(File.join(FIXTURES, name)).each_line.map(&:chomp)
      .reject { |line| line.empty? || line.start_with?("#") }
end

satisfied = 0
rows("requirement_cases.txt").each do |line|
  requirement, version, expected = line.split(" | ")
  got = SpinelBundlerAudit::Requirement.new(requirement)
          .satisfied_by?(SpinelBundlerAudit::GemVersion.new(version))
  raise "#{line}: got #{got}" unless got.to_s == expected

  satisfied += 1
end

printed = 0
rows("requirement_text_cases.txt").each do |line|
  written, expected = line.split(" | ")
  got = SpinelBundlerAudit::Requirement.new(written).to_s
  raise "#{line}: got #{got.inspect}" unless got == expected

  printed += 1
end

puts "#{satisfied} range cases"
puts "#{printed} spelling cases"
