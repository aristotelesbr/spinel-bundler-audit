require "yaml"

module SpinelBundlerAudit
  class Advisory
    # The YAML fields a report shows, in the order bundler-audit's JSON
    # lists them.
    JSON_FIELDS = ["url", "title", "date", "description", "cvss_v2", "cvss_v3", "cve", "osvdb", "ghsa"].freeze
    # An unquoted YAML date loads as a Date, which Spinel's psych cannot
    # build; the line is read here instead.
    DATE_LINE = /^date: (\d{4})-(\d{1,2})-(\d{1,2})[ \t]*$/

    # The fields kept as text. A score stays text here and is read as a
    # number only when it is one in the YAML.
    TEXT_FIELDS = ["url", "title", "description", "cve", "osvdb", "ghsa", "cvss_v2", "cvss_v3"].freeze

    attr_reader :path, :id, :texts, :json_literals, :unaffected_texts, :patched_texts,
                :cvss_v2, :cvss_v3, :patched_versions, :unaffected_versions

    def self.load(path)
      text = File.read(path)
      date = nil
      if (match = DATE_LINE.match(text))
        date = format("%04d-%02d-%02d", match[1].to_i, match[2].to_i, match[3].to_i)
        text = text.sub(DATE_LINE, "")
      end
      data = YAML.safe_load(text)
      raise "advisory data in #{path.dump} was not a Hash" unless data.is_a?(Hash)

      texts = {}
      TEXT_FIELDS.each { |field| texts[field] = Advisory.text(data[field]) }
      ["cvss_v2", "cvss_v3"].each { |field| texts[field] = nil unless Advisory.number?(data[field]) }
      json = {}
      JSON_FIELDS.each { |field| json[field] = Advisory.json_literal(data[field]) }
      json["date"] = JsonWriter.string(date) if date
      new(path, File.basename(path, ".yml"), texts, json,
          Advisory.list(data["unaffected_versions"]), Advisory.list(data["patched_versions"]))
    end

    # texts: TEXT_FIELDS => String or nil; json: JSON_FIELDS => JSON literal
    # (a field left out is the JSON string of its text);
    # unaffected, patched: the version ranges as written.
    def initialize(path, id, texts, json, unaffected, patched)
      @path = path
      @id = id
      @texts = texts
      @json_literals = json
      @unaffected_texts = unaffected
      @patched_texts = patched
      @cvss_v2 = texts["cvss_v2"]&.to_f
      @cvss_v3 = texts["cvss_v3"]&.to_f
      @unaffected_versions = unaffected.map { |range| Requirement.new(range) }
      @patched_versions = patched.map { |range| Requirement.new(range) }
    end

    def url
      @texts["url"]
    end

    def title
      @texts["title"]
    end

    def description
      @texts["description"]
    end

    def cve
      @texts["cve"]
    end

    def osvdb
      @texts["osvdb"]
    end

    def ghsa
      @texts["ghsa"]
    end

    def self.text(value)    = value.nil? ? nil : value.to_s
    def self.number?(value) = value.is_a?(Integer) || value.is_a?(Float)

    def self.list(value)
      return [] if value.nil?

      (value.is_a?(Array) ? value : [value]).map(&:to_s)
    end

    def self.json_literal(value)
      if value.nil? then "null"
      elsif value == true then "true"
      elsif value == false then "false"
      elsif number?(value) then JsonWriter.number(value)
      else JsonWriter.string(value.to_s)
      end
    end

    # The YAML value of a field, spelled as JSON.
    # A field missing from json_literals is the JSON string of its text
    # (spelled only when a JSON report asks for it).
    def json(field)
      literal = @json_literals[field]
      return literal if literal

      text = @texts[field]
      text.nil? ? "null" : JsonWriter.string(text)
    end

    def cve_id
      "CVE-#{cve}" if cve
    end

    def osvdb_id
      "OSVDB-#{osvdb}" if osvdb
    end

    def ghsa_id
      "GHSA-#{ghsa}" if ghsa
    end

    def identifiers
      [cve_id, osvdb_id, ghsa_id].compact
    end

    # "none", "low", "medium", "high", "critical", or nil when the scores
    # say nothing (bundler-audit's ranges leave gaps such as 3.95).
    def criticality
      if cvss_v3
        score = cvss_v3
        if score == 0.0 then "none"
        elsif score >= 0.1 && score <= 3.9 then "low"
        elsif score >= 4.0 && score <= 6.9 then "medium"
        elsif score >= 7.0 && score <= 8.9 then "high"
        elsif score >= 9.0 && score <= 10.0 then "critical"
        end
      elsif cvss_v2
        score = cvss_v2
        if score >= 0.0 && score <= 3.9 then "low"
        elsif score >= 4.0 && score <= 6.9 then "medium"
        elsif score >= 7.0 && score <= 10.0 then "high"
        end
      end
    end

    def vulnerable?(version)
      !patched?(version) && !unaffected?(version)
    end

    def patched?(version)
      patched_versions.any? { |requirement| requirement.satisfied_by?(version) }
    end

    def unaffected?(version)
      unaffected_versions.any? { |requirement| requirement.satisfied_by?(version) }
    end
  end
end
