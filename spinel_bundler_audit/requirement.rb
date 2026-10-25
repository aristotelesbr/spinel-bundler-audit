module SpinelBundlerAudit
  # One advisory version range, such as "~> 5.2.4, >= 5.2.4.3": every
  # constraint in it must hold.
  class Requirement
    PATTERN = /\A\s*(=|!=|>=|<=|>|<|~>)?\s*([0-9]+(?:\.[0-9a-zA-Z]+)*(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)\s*\z/

    def initialize(text)
      @constraints = text.split(", ").uniq.map { |part| Constraint.parse(part) }
    end

    def to_s
      @constraints.map(&:to_s).join(", ")
    end

    def satisfied_by?(version)
      @constraints.all? { |constraint| constraint.satisfied_by?(version) }
    end
  end

  class Constraint
    attr_reader :operator, :version

    def self.parse(text)
      match = Requirement::PATTERN.match(text)
      raise ArgumentError, "Illformed requirement #{text.inspect}" unless match

      new(match[1] || "=", GemVersion.new(match[2]))
    end

    def initialize(operator, version)
      @operator = operator
      @version = version
    end

    def to_s
      "#{@operator} #{@version.normalized}"
    end

    def satisfied_by?(candidate)
      order = candidate <=> @version
      case @operator
      when "="  then order == 0
      when "!=" then order != 0
      when ">"  then order > 0
      when "<"  then order < 0
      when ">=" then order >= 0
      when "<=" then order <= 0
      else order >= 0 && (candidate.release <=> @version.bump) < 0
      end
    end
  end
end
