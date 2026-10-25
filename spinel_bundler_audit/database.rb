module SpinelBundlerAudit
  # A checkout of github.com/rubysec/ruby-advisory-db, at the path and under
  # the environment variable bundler-audit uses, so both share one copy.
  class Database
    URL = "https://github.com/rubysec/ruby-advisory-db.git"

    class DownloadFailed < RuntimeError
    end

    class UpdateFailed < RuntimeError
    end

    def self.default_path
      ENV["BUNDLER_AUDIT_DB"] || File.expand_path(File.join(Dir.home, ".local", "share", "ruby-advisory-db"))
    end

    def self.exists?(path)
      File.directory?(path) && !(Dir.entries(path) - [".", ".."]).empty?
    end

    def self.download(path, quiet)
      ok = quiet ? system("git", "clone", "--quiet", URL, path) : system("git", "clone", URL, path)
      raise DownloadFailed, "failed to download #{URL} to #{path.inspect}" unless ok

      Index.build(path) unless ENV["SPINEL_BUNDLER_AUDIT_NO_INDEX"]
      new(path)
    end

    def self.git_installed?
      system("git --version > /dev/null 2>&1")
    end

    attr_reader :path

    def initialize(path)
      raise ArgumentError, "#{path.dump} is not a directory" unless File.directory?(path)

      @path = path
    end

    def git?
      File.directory?(File.join(@path, ".git"))
    end

    # true once pulled, nil when the database is not a git checkout.
    def update!(quiet)
      return nil unless git?

      ok = if quiet
             system("git", "-C", @path, "pull", "--quiet", "origin", "master")
           else
             system("git", "-C", @path, "pull", "origin", "master")
           end
      raise UpdateFailed, "failed to update #{@path.inspect}" unless ok

      Index.build(@path) unless ENV["SPINEL_BUNDLER_AUDIT_NO_INDEX"]
      true
    end

    def commit_id
      `git -C #{@path.inspect} rev-parse HEAD`.chomp if git?
    end

    def last_updated_at
      if git?
        `git -C #{@path.inspect} log --date=iso8601 --pretty=%cd -1`.strip
      else
        File.mtime(@path).to_s
      end
    end

    def size
      Dir.glob(File.join(@path, "gems", "*", "*.yml")).size
    end

    # From the index when the database has one for its commit (building it
    # on the first check after an update made elsewhere); from the YAML files
    # otherwise, and for a name the index has no directory for but the file
    # system finds (a case-insensitive match).
    def advisories_for(name)
      if (current = index)
        found = current.advisories_for(name)
        return found if found
        return [] unless File.directory?(File.join(@path, "gems", name))

        # The file system matched another case ("Rack" finding gems/rack):
        # use the directory as it is on disk, which is what Dir.glob gives.
        dir = current.directory_like(name)
        return current.advisories_for(dir) if dir
      end
      Dir.glob(File.join(@path, "gems", name, "*.yml")).sort.map { |file| Advisory.load(file) }
    end

    def index
      return @index if @index_read

      @index_read = true
      @index = ENV["SPINEL_BUNDLER_AUDIT_NO_INDEX"] ? nil : (Index.load(@path) || Index.build(@path))
    end
  end
end
