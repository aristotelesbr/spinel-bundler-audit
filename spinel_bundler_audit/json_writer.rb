module SpinelBundlerAudit
  # Streams JSON the way JSON.generate / JSON.pretty_generate spell it, so
  # reports never build a mixed-type Hash first.
  class JsonWriter
    ESCAPES = { "\"" => "\\\"", "\\" => "\\\\", "\b" => "\\b", "\f" => "\\f",
                "\n" => "\\n", "\r" => "\\r", "\t" => "\\t" }.freeze

    def self.string(text)
      escaped = text.gsub(/["\\\x00-\x1f]/) { |char| ESCAPES[char] || format("\\u%04x", char.ord) }
      "\"#{escaped}\""
    end

    def self.number(value)
      value.to_s
    end

    attr_reader :output

    def initialize(pretty)
      @pretty = pretty
      @output = +""
      @counts = []
    end

    def begin_object
      open("{")
    end

    def end_object
      close("}")
    end

    def begin_array
      open("[")
    end

    def end_array
      close("]")
    end

    def key(name)
      separate
      @output << JsonWriter.string(name) << (@pretty ? ": " : ":")
      @after_key = true
    end

    # A value already spelled as JSON: a string, number or null literal.
    def literal(json)
      separate
      @output << json
    end

    def string(text)
      literal(text.nil? ? "null" : JsonWriter.string(text))
    end

    private

    def open(bracket)
      separate
      @output << bracket
      @counts << 0
    end

    def close(bracket)
      count = @counts.pop
      @output << "\n" << ("  " * @counts.size) if @pretty && count > 0
      @output << bracket
    end

    # Writes what goes before a key or an array element; a value right after
    # its key needs nothing.
    def separate
      if @after_key
        @after_key = false
        return
      end
      return if @counts.empty?

      @output << "," if @counts[-1] > 0
      @output << "\n" << ("  " * @counts.size) if @pretty
      @counts[-1] += 1
    end
  end
end
