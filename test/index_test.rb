require "spinel_bundler_audit"
require "tmpdir"
require "fileutils"

COMMIT_A = "a" * 40
COMMIT_B = "b" * 40

ADVISORIES = {
  "rack/CVE-2022-30122.yml" => <<~YAML,
    ---
    gem: rack
    cve: 2022-30122
    ghsa: hxqx-xwvh-44m2
    url: https://example.com/rack
    title: "Denial of Service in multipart parsing"
    date: 2022-06-27
    description: |
      Tabs\there, a backslash \\ and an accent: é.

      Second paragraph.
    cvss_v3: 7.5
    unaffected_versions:
      - "< 1.2"
    patched_versions:
      - "~> 2.0.9, >= 2.0.9.1"
      - ">= 2.2.3.1"
  YAML
  "rack/OSVDB-1.yml" => <<~YAML,
    ---
    gem: rack
    osvdb: 12345
    url: https://example.com/osvdb
    title: Old advisory
    date: 2011-1-5
    description: No patch.
    cvss_v2: 4.3
  YAML
  "nokogiri/GHSA-1.yml" => <<~YAML
    ---
    gem: nokogiri
    ghsa: xxxx-yyyy-zzzz
    url: https://example.com/nokogiri
    title: Prerelease range
    date: 2023-01-01
    description: Range with a prerelease.
    patched_versions:
      - ">= 4.0.0-beta.2"
  YAML
}.freeze

def same(label, expected, actual)
  raise "#{label}: #{expected.inspect} != #{actual.inspect}" unless expected == actual
end

def compare(from_yaml, from_index)
  same("path", from_yaml.path, from_index.path)
  same("id", from_yaml.id, from_index.id)
  SpinelBundlerAudit::Advisory::TEXT_FIELDS.each do |field|
    same(field, from_yaml.texts[field], from_index.texts[field])
  end
  SpinelBundlerAudit::Advisory::JSON_FIELDS.each do |field|
    same("json #{field}", from_yaml.json(field), from_index.json(field))
  end
  same("unaffected", from_yaml.unaffected_texts, from_index.unaffected_texts)
  same("patched", from_yaml.patched_texts, from_index.patched_texts)
  same("criticality", from_yaml.criticality, from_index.criticality)
end

Dir.mktmpdir do |tmp|
  ENV["XDG_CACHE_HOME"] = File.join(tmp, "cache")
  db = File.join(tmp, "db")
  ADVISORIES.each do |name, yaml|
    FileUtils.mkdir_p(File.join(db, "gems", File.dirname(name)))
    File.write(File.join(db, "gems", name), yaml)
  end

  puts "no git checkout: #{SpinelBundlerAudit::Index.build(db).nil?}"

  FileUtils.mkdir_p(File.join(db, ".git"))
  File.write(File.join(db, ".git", "HEAD"), "#{COMMIT_A}\n")
  puts "built: #{!SpinelBundlerAudit::Index.build(db).nil?}"

  index = SpinelBundlerAudit::Index.load(db)
  ["rack", "nokogiri"].each do |gem|
    yaml = Dir.glob(File.join(db, "gems", gem, "*.yml")).sort.map { |file| SpinelBundlerAudit::Advisory.load(file) }
    indexed = index.advisories_for(gem)
    same("#{gem} count", yaml.size, indexed.size)
    yaml.zip(indexed).each { |a, b| compare(a, b) }
    puts "#{gem}: #{indexed.size} advisories identical to YAML"
  end
  # An entry decodes the fields only a report shows on first use, whether
  # a JSON report or a text one asks first.
  yaml = SpinelBundlerAudit::Advisory.load(File.join(db, "gems", "rack", "CVE-2022-30122.yml"))
  json_first = index.advisories_for("rack").first
  same("json first", yaml.json("description"), json_first.json("description"))
  compare(yaml, json_first)
  puts "json read first: identical"
  puts "unknown gem: #{index.advisories_for('rails').nil?}"
  puts "case: #{index.directory_like('RACK')}"

  File.write(File.join(db, ".git", "HEAD"), "#{COMMIT_B}\n")
  puts "stale after commit change: #{SpinelBundlerAudit::Index.load(db).nil?}"

  File.write(File.join(db, ".git", "HEAD"), "ref: refs/heads/main\n")
  File.write(File.join(db, ".git", "packed-refs"), "# pack-refs\n#{COMMIT_A} refs/heads/main\n")
  puts "packed ref: #{SpinelBundlerAudit::Index.revision(db) == COMMIT_A}"
end
