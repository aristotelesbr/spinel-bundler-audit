module SpinelBundlerAudit
  module Formats
    NAMES = ["text", "json", "junit"].freeze

    def self.label(advisory)
      criticality = advisory.criticality
      criticality ? criticality.capitalize : "Unknown"
    end

    def self.solution(advisory)
      if advisory.patched_versions.empty?
        "remove or disable this gem until a patch is available!"
      else
        "update to #{advisory.patched_versions.map { |requirement| "'#{requirement}'" }.join(', ')}"
      end
    end

    def self.print(name, report, out, quiet, verbose)
      shell = Shell.new(out, quiet)
      case name
      when "json" then Json.new(out).print(report)
      when "junit" then Junit.new(shell).print(report)
      else Text.new(shell, verbose).print(report)
      end
    end

    class Text
      def initialize(shell, verbose)
        @shell = shell
        @verbose = verbose
      end

      def print(report)
        report.results.each do |result|
          if result.insecure_source?
            @shell.say "Insecure Source URI found: #{result.source}", Shell::YELLOW
          else
            print_advisory(result.gem, result.advisory)
          end
        end

        if report.vulnerable?
          @shell.say "Vulnerabilities found!", Shell::RED
        else
          @shell.say "No vulnerabilities found", Shell::GREEN
        end
      end

      private

      def print_advisory(gem, advisory)
        field "Name: ", gem.name
        field "Version: ", gem.version.normalized
        field "CVE: ", advisory.cve_id if advisory.cve
        field "GHSA: ", advisory.ghsa_id if advisory.ghsa
        @shell.say "Criticality: ", Shell::RED
        print_criticality(advisory.criticality)
        field "URL: ", advisory.url

        if @verbose
          @shell.say "Description:", Shell::RED
          @shell.say
          @shell.print_wrapped advisory.description.to_s, 2
          @shell.say
        else
          field "Title: ", advisory.title
        end

        if advisory.patched_versions.empty?
          @shell.say "Solution: ", Shell::RED
          @shell.say "remove or disable this gem until a patch is available!", Shell::RED, Shell::BOLD
        else
          field "Solution: update to ", advisory.patched_versions.map { |requirement| "'#{requirement}'" }.join(", ")
        end

        @shell.say
      end

      def field(label, value)
        @shell.say label, Shell::RED
        @shell.say value
      end

      def print_criticality(criticality)
        case criticality
        when "none" then @shell.say "None"
        when "low" then @shell.say "Low"
        when "medium" then @shell.say "Medium", Shell::YELLOW
        when "high" then @shell.say "High", Shell::RED, Shell::BOLD
        when "critical" then @shell.say "Critical", Shell::RED, Shell::BOLD
        else @shell.say "Unknown"
        end
      end
    end

    # bundler-audit's report hash: pretty on a terminal, compact otherwise.
    class Json
      def initialize(out)
        @out = out
      end

      def print(report)
        pretty = @out.tty?
        json = JsonWriter.new(pretty)
        json.begin_object
        json.key("version")
        json.string(VERSION)
        json.key("created_at")
        json.string(report.created_at.to_s)
        json.key("results")
        json.begin_array
        report.results.each { |result| write_result(json, result) }
        json.end_array
        json.end_object
        pretty ? @out.puts(json.output) : @out.write(json.output)
      end

      private

      def write_result(json, result)
        json.begin_object
        json.key("type")
        if result.insecure_source?
          json.string("insecure_source")
          json.key("source")
          json.string(result.source)
        else
          json.string("unpatched_gem")
          json.key("gem")
          json.begin_object
          json.key("name")
          json.string(result.gem.name)
          json.key("version")
          json.string(result.gem.version.normalized)
          json.end_object
          json.key("advisory")
          write_advisory(json, result.advisory)
        end
        json.end_object
      end

      def write_advisory(json, advisory)
        json.begin_object
        json.key("path")
        json.string(advisory.path)
        json.key("id")
        json.string(advisory.id)
        Advisory::JSON_FIELDS.each do |field|
          json.key(field)
          json.literal(advisory.json(field))
        end
        write_requirements(json, "unaffected_versions", advisory.unaffected_versions)
        write_requirements(json, "patched_versions", advisory.patched_versions)
        json.key("criticality")
        json.string(advisory.criticality)
        json.end_object
      end

      def write_requirements(json, key, requirements)
        json.key(key)
        json.begin_array
        requirements.each { |requirement| json.string(requirement.to_s) }
        json.end_array
      end
    end

    class Junit
      def initialize(shell)
        @shell = shell
      end

      def print(report)
        say_xml(%{<?xml version="1.0" encoding="UTF-8" ?>},
                %{<testsuites id="#{Time.now.to_i}" name="Bundle Audit">},
                %{  <testsuite id="Gemfile" name="Ruby Gemfile" failures="#{report.results.size}">})
        report.results.each { |result| print_testcase(result) }
        say_xml(%{  </testsuite>}, %{</testsuites>})
      end

      private

      def say_xml(*lines)
        @shell.say(lines.join("\n"))
      end

      def print_testcase(result)
        if result.insecure_source?
          source = xml(result.source)
          say_xml(%{    <testcase id="#{source}" name="Insecure Source URI found: #{source}">},
                  %{      <failure message="Insecure Source URI found: #{source}" type="Unknown"></failure>},
                  %{    </testcase>})
        else
          gem = result.gem
          advisory = result.advisory
          label = Formats.label(advisory)
          say_xml(%{    <testcase id="#{xml(gem.name)}" name="#{xml("#{label.upcase} #{gem.name}(#{gem.version.normalized}) #{advisory.title}")}">},
                  %{      <failure message="#{xml(advisory.title)}" type="#{xml(advisory.criticality)}">},
                  %{        Name: #{xml(gem.name)}},
                  %{        Version: #{xml(gem.version.normalized)}},
                  %{        Advisory: #{xml(advisory.identifiers.join(' '))}},
                  %{        Criticality: #{xml(label)}},
                  %{        URL: #{xml(advisory.url)}},
                  %{        Title: #{xml(advisory.title)}},
                  %{        Solution: #{xml(Formats.solution(advisory))}},
                  %{      </failure>},
                  %{    </testcase>})
        end
      end

      XML_ESCAPES = { "'" => "&#39;", "&" => "&amp;", "\"" => "&quot;", "<" => "&lt;", ">" => "&gt;" }.freeze

      def xml(text)
        text.to_s.gsub(/['&"<>]/) { |char| XML_ESCAPES[char] }
      end
    end
  end
end
