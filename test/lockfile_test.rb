require "spinel_bundler_audit"

LOCKFILES = File.expand_path("fixtures/lockfiles", __dir__)

# A PATH source, which the oracle cannot check: Bundler resolves PATH
# sources against a real Gemfile.
PATH_LOCK = <<~LOCK
  PATH
    remote: engines/blog
    specs:
      blog (0.1.0)
        rails (>= 7.0)

  GEM
    remote: https://rubygems.org/
    specs:
      rack (2.2.3)

  PLATFORMS
    ruby
LOCK

def describe(name, lockfile)
  puts "== #{name}"
  lockfile.sources.each { |source| puts "source #{source.kind} #{source.remotes.join(' ')}" }
  lockfile.gems.each { |gem| puts "gem #{gem.full_name}" }
end

Dir.glob(File.join(LOCKFILES, "*.lock")).sort.each do |path|
  describe(File.basename(path), SpinelBundlerAudit::Lockfile.read(path))
end
describe("path (inline)", SpinelBundlerAudit::Lockfile.new(PATH_LOCK))
