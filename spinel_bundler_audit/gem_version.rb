module SpinelBundlerAudit
  # Orders versions the way Gem::Version does: numeric segments compare as
  # numbers, and a letter segment marks a prerelease that sorts below any
  # number. Segments stay Strings so every array holds a single type.
  class GemVersion
    attr_reader :text, :segments

    def initialize(text)
      @text = text.strip
      @segments = @text.gsub("-", ".pre.").scan(/[0-9]+|[a-z]+/i)
      @canonical = nil
    end

    def to_s
      @text
    end

    # How RubyGems spells it: a dash starts a prerelease.
    def normalized
      @text.gsub("-", ".pre.")
    end

    def prerelease?
      @segments.any? { |segment| !GemVersion.numeric?(segment) }
    end

    def release
      return self unless prerelease?

      GemVersion.new(GemVersion.numeric_prefix(@segments).join("."))
    end

    # The upper bound of "~> self": drop the last numeric segment and
    # increment the one before it ("~> 2.1.3" means "< 2.2").
    def bump
      numbers = GemVersion.numeric_prefix(@segments)
      numbers.pop if numbers.size > 1
      numbers[-1] = (numbers[-1].to_i + 1).to_s
      GemVersion.new(numbers.join("."))
    end

    def <=>(other)
      left = canonical
      right = other.canonical
      limit = left.size > right.size ? left.size : right.size
      i = 0
      while i < limit
        result = GemVersion.compare_segments(left[i] || "0", right[i] || "0")
        return result unless result == 0
        i += 1
      end
      0
    end

    def canonical
      @canonical ||= begin
        numbers = GemVersion.numeric_prefix(@segments)
        rest = @segments[numbers.size..] || []
        GemVersion.drop_trailing_zeros(numbers) + GemVersion.drop_trailing_zeros(rest)
      end
    end

    def self.numeric?(segment)
      segment.match?(/\A[0-9]+\z/)
    end

    def self.numeric_prefix(segments)
      prefix = []
      segments.each do |segment|
        break unless numeric?(segment)
        prefix << segment
      end
      prefix
    end

    def self.drop_trailing_zeros(segments)
      kept = segments.dup
      kept.pop while !kept.empty? && numeric?(kept[-1]) && kept[-1].to_i == 0
      kept
    end

    def self.compare_segments(left, right)
      left_number = numeric?(left)
      right_number = numeric?(right)
      if left_number && right_number
        left.to_i <=> right.to_i
      elsif left_number
        1
      elsif right_number
        -1
      else
        left <=> right
      end
    end
  end
end
