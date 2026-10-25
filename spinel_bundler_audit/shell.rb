module SpinelBundlerAudit
  # Prints as bundler-audit's Thor shell does: a message ends its line
  # unless it ends in a space or tab, colors only when the output is a
  # terminal (and NO_COLOR is unset), and --quiet silences all of it.
  class Shell
    CLEAR = "\e[0m"
    BOLD = "\e[1m"
    RED = "\e[31m"
    GREEN = "\e[32m"
    YELLOW = "\e[33m"
    DEFAULT_WIDTH = 80

    attr_reader :out

    def initialize(out, quiet, errors = $stderr)
      @out = out
      @errors = errors
      @quiet = quiet
      no_color = ENV["NO_COLOR"]
      @color = out.tty? && ENV["TERM"] != "dumb" && (no_color.nil? || no_color.empty?)
    end

    def say(message = "", *colors)
      return if @quiet

      @out.print(line(message, colors))
      @out.flush
    end

    def say_error(message, *colors)
      return if @quiet

      @errors.print(line(message, colors))
      @errors.flush
    end

    # Thor's print_wrapped: words joined up to the terminal width,
    # paragraphs kept apart by a blank line. Thor writes these lines straight
    # to the output, so --quiet does not silence them.
    def print_wrapped(message, indent)
      width = terminal_width - indent
      paras = message.split("\n\n").map { |text| wrap(text, width) }.compact
      paras.each do |para|
        para.split("\n").each { |text| @out.puts((" " * indent) + text) }
        @out.puts unless para == paras.last
      end
    end

    private

    def line(message, colors)
      text = message.to_s
      buffer = paint(text, colors)
      buffer += "\n" unless text.match?(/[ \t]\z/) || text.end_with?("\n")
      buffer
    end

    def paint(text, colors)
      return text if colors.empty? || !@color

      "#{colors.join}#{text}#{CLEAR}"
    end

    def wrap(text, width)
      words = text.split(" ")
      return nil if words.empty?

      wrapped = words.first
      counter = wrapped.length
      words.drop(1).each do |word|
        word = word.gsub(/\n\005/, "\n").gsub(/\005/, "\n")
        counter = 0 if word.include?("\n")
        if counter + word.length + 1 < width
          counter += word.length + 1
          wrapped = "#{wrapped} #{word}"
        else
          counter = word.length
          wrapped = "#{wrapped}\n#{word}"
        end
      end
      wrapped
    end

    def terminal_width
      width = `stty size 2>/dev/null`.split[1].to_i
      width = `tput cols 2>/dev/null`.to_i if width == 0
      width < 10 ? DEFAULT_WIDTH : width
    end
  end
end
