module SpinelBundlerAudit
  class LockedGem
    attr_reader :name, :version, :platform

    def initialize(name, version, platform)
      @name = name
      @version = version
      @platform = platform
    end

    def full_name
      if platform.nil? || platform == "ruby"
        "#{name}-#{version.normalized}"
      else
        "#{name}-#{version.normalized}-#{platform}"
      end
    end
  end

  class Source
    attr_reader :kind, :remotes

    def initialize(kind)
      @kind = kind
      @remotes = []
    end

    def rubygems?
      kind == "GEM"
    end

    def git?
      kind == "GIT"
    end

    # Each remote goes first, as Bundler adds them: a source lists its
    # remotes in the reverse of the lockfile's order.
    def add_remote(uri)
      uri = "#{uri}/" if rubygems? && !uri.end_with?("/")
      @remotes.unshift(uri) unless @remotes.include?(uri)
    end
  end

  # Reads what an audit needs from a Gemfile.lock: each source with its
  # remotes, and every gem locked under a source's "specs:". Gems are
  # sorted by full name, as Bundler's LockfileParser leaves them.
  class Lockfile
    SOURCES = ["GIT", "GEM", "PATH", "PLUGIN SOURCE"].freeze
    SPEC = /\A {4}(?! )(.*?)(?:\s\(([^-]*)(?:-(.*))?\))?(!)?(?:\s([^\s]+))?\z/
    REMOTE = /\A  remote: (.+)\z/

    attr_reader :gems, :sources

    def self.read(path)
      new(File.read(path))
    end

    def initialize(text)
      @sources = []
      by_full_name = {}
      source = nil
      in_specs = false
      text.each_line do |raw|
        line = raw.chomp
        if line.match?(/\A\S/)
          source = SOURCES.include?(line) ? Source.new(line) : nil
          @sources << source if source
          in_specs = false
        elsif source.nil?
          next
        elsif line == "  specs:"
          in_specs = true
        elsif (match = REMOTE.match(line))
          source.add_remote(match[1])
        elsif in_specs && (match = SPEC.match(line)) && match[2]
          gem = LockedGem.new(match[1], GemVersion.new(match[2]), match[3])
          by_full_name[gem.full_name] = gem
        end
      end
      @gems = []
      by_full_name.each_value { |gem| @gems << gem }
      @gems = @gems.sort_by { |gem| gem.full_name }
    end
  end
end
