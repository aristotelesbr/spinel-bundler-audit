require "yaml"

module SpinelBundlerAudit
  # The project's .bundler-audit.yml; only "ignore" means anything.
  class Configuration
    class InvalidConfigurationError < StandardError
    end

    attr_reader :ignore

    def self.load(path)
      text = File.read(path)
      data = YAML.safe_load(text)
      if data.nil? && text.lines.all? { |line| line.strip.empty? || line.lstrip.start_with?("#") }
        raise InvalidConfigurationError, "Configuration found in '#{path}' is not YAML"
      end
      raise InvalidConfigurationError, "Configuration found in '#{path}' is not a Hash" unless data.is_a?(Hash)

      ignore = []
      if data.key?("ignore")
        list = data["ignore"]
        raise InvalidConfigurationError, "'ignore' key found in config file, but is not an Array" unless list.is_a?(Array)
        if list.any? { |item| item.is_a?(Array) || item.is_a?(Hash) }
          raise InvalidConfigurationError, "'ignore' array in config file contains a non-String"
        end

        ignore = list.map(&:to_s)
      end
      new(ignore)
    end

    def initialize(ignore = [])
      @ignore = ignore
    end
  end
end
