require "socket"

module SpinelBundlerAudit
  # One finding: an insecure source URI, or a locked gem an advisory covers.
  class Result
    attr_reader :source, :gem, :advisory

    def self.insecure_source(uri)
      new(uri, nil, nil)
    end

    def self.unpatched_gem(gem, advisory)
      new(nil, gem, advisory)
    end

    def initialize(source, gem, advisory)
      @source = source
      @gem = gem
      @advisory = advisory
    end

    def insecure_source?
      !@source.nil?
    end
  end

  class Report
    attr_reader :results, :created_at

    def initialize(results)
      @results = results
      @created_at = Time.now
    end

    def vulnerable?
      !@results.empty?
    end
  end

  class Scanner
    def initialize(lockfile, database, ignore)
      @lockfile = lockfile
      @database = database
      @ignore = ignore
    end

    def report
      Report.new(insecure_sources + unpatched_gems)
    end

    def insecure_sources
      found = []
      @lockfile.sources.each do |source|
        if source.git?
          uri = source.remotes.first
          found << Result.insecure_source(uri) if uri && uri.match?(/^(git|http):/) && !internal_source?(uri)
        elsif source.rubygems?
          source.remotes.each do |uri|
            found << Result.insecure_source(uri) if uri.start_with?("http://") && !internal_source?(uri)
          end
        end
      end
      found
    end

    def unpatched_gems
      found = []
      @lockfile.gems.each do |gem|
        @database.advisories_for(gem.name).each do |advisory|
          next unless advisory.vulnerable?(gem.version)
          next if advisory.identifiers.any? { |id| @ignore.include?(id) }

          found << Result.unpatched_gem(gem, advisory)
        end
      end
      found
    end

    private

    # A host counts as internal when every address it resolves to sits in a
    # private subnet (and, as in bundler-audit, when it resolves to none).
    def internal_source?(uri)
      host = uri[%r{\A[a-z][a-z0-9+.-]*://(?:[^@/]*@)?(\[[^\]]+\]|[^:/]+)}i, 1]
      return false if host.nil?

      addresses(host.delete("[]")).all? { |ip| Scanner.internal_ip?(ip) }
    end

    # bundler-audit's private subnets: 10.0.0.0/8, 172.16.0.0/12,
    # 192.168.0.0/16, 127.0.0.0/8, fc00::/7 and ::1/128. Checked by hand
    # because IPAddr's IPv6 masks need integers wider than 64 bits.
    def self.internal_ip?(ip)
      if (octets = ip.match(/\A(\d+)\.(\d+)\.(\d+)\.(\d+)\z/))
        a = octets[1].to_i
        b = octets[2].to_i
        a == 10 || a == 127 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168)
      else
        groups = ipv6_groups(ip)
        return false if groups.nil?

        (groups[0] & 0xfe00) == 0xfc00 || groups == [0, 0, 0, 0, 0, 0, 0, 1]
      end
    end

    # The eight 16-bit groups of an IPv6 address, or nil.
    def self.ipv6_groups(ip)
      address = ip.split("%").first.to_s
      return nil unless address.match?(/\A[0-9a-fA-F:]+\z/) && address.count(":") >= 2

      head, tail = address.split("::", 2)
      head_groups = head.to_s.split(":").map { |group| group.to_i(16) }
      tail_groups = tail.to_s.split(":").map { |group| group.to_i(16) }
      return nil if tail.nil? && head_groups.size != 8

      head_groups + Array.new(8 - head_groups.size - tail_groups.size, 0) + tail_groups
    end

    def addresses(host)
      Socket.getaddrinfo(host, nil).map { |entry| entry[3] }.uniq
    rescue SocketError
      []
    end
  end
end
