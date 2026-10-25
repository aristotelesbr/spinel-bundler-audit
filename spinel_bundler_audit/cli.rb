require "optparse"

module SpinelBundlerAudit
  # The command line. Options are read by OptionParser, so an unknown
  # option is an error, an attached short value (-Gfile) works and a long
  # option may be abbreviated (--verb). One bundler-audit habit is kept:
  # "-i A B C" (a multi-value ignore) is expanded to "-i A -i B -i C"
  # before parsing. A unique prefix names a command ("che" is check).
  class CLI
    class UsageError < StandardError
    end

    COMMANDS = {
      "check" => ["check [DIR]", "Checks the Gemfile.lock for insecure dependencies"],
      "download" => ["download", "Downloads ruby-advisory-db"],
      "help" => ["help [COMMAND]", "Describe available commands or one specific command"],
      "stats" => ["stats", "Prints ruby-advisory-db stats"],
      "update" => ["update", "Updates the ruby-advisory-db"],
      "version" => ["version", "Prints the spinel-bundler-audit version"]
    }.freeze

    def self.start(argv)
      new.run(argv)
    end

    def run(argv)
      args = argv.dup
      command = resolve(args)
      case command
      when "check" then check(args)
      when "stats" then stats(args)
      when "download" then download_command(args)
      when "update" then update_command(args)
      when "version" then puts "spinel-bundler-audit #{VERSION}"
      else help(args)
      end
    rescue UsageError => error
      $stderr.puts error.message
      exit 1
    end

    private

    def resolve(args)
      first = args.first
      return "check" if first.nil? || (first.start_with?("-") && !["--version", "-h", "--help"].include?(first))

      args.shift
      return "version" if first == "--version"
      return "help" if first == "-h" || first == "--help"

      matches = COMMANDS.keys.select { |name| name.start_with?(first) }
      return first if COMMANDS.key?(first)
      return matches.first if matches.size == 1

      raise UsageError, "Could not find command #{first.inspect}." if matches.empty?

      raise UsageError, "Ambiguous command #{first} matches [#{matches.join(', ')}]"
    end

    def check(args)
      options, positional = parse(args, "check")
      dir = positional.first || Dir.pwd
      shell = Shell.new($stdout, options["quiet"])

      unless File.directory?(dir)
        shell.say_error "No such file or directory: #{dir}", Shell::RED
        exit 1
      end
      format = options["format"]
      unless Formats::NAMES.include?(format)
        shell.say_error "Unknown format: #{format}", Shell::RED
        exit 1
      end

      path = options["database"] || Database.default_path
      if !Database.exists?(path)
        download(path, shell, options["quiet"])
      elsif options["update"]
        update(path, shell, options["quiet"])
      end
      database = Database.new(path)

      root = File.expand_path(dir)
      lock = File.join(root, options["gemfile_lock"])
      unless File.file?(lock)
        shell.say "Could not find #{options['gemfile_lock'].inspect} in #{root.inspect}", Shell::RED
        exit 1
      end
      ignore = options["ignore"] || load_config(File.absolute_path(options["config"], root)).ignore

      report = Scanner.new(Lockfile.read(lock), database, ignore).report
      output = options["output"] ? File.open(options["output"], "w") : $stdout
      Formats.print(format, report, output, options["quiet"], options["verbose"])
      output.close if options["output"]
      exit 1 if report.vulnerable?
    end

    def load_config(path)
      File.exist?(path) ? Configuration.load(path) : Configuration.new
    rescue Configuration::InvalidConfigurationError => error
      $stderr.puts "spinel-bundler-audit: #{error.message}"
      exit 1
    end

    def stats(args)
      _options, positional = parse(args, "stats")
      print_stats(positional.first || Database.default_path)
    end

    def print_stats(path)
      database = Database.new(path)
      puts "ruby-advisory-db:"
      puts "  advisories:\t#{database.size} advisories"
      puts "  last updated:\t#{database.last_updated_at}"
      commit_id = database.commit_id
      puts "  commit:\t#{commit_id}" if commit_id
    end

    def download_command(args)
      options, positional = parse(args, "download")
      path = positional.first || Database.default_path
      shell = Shell.new($stdout, options["quiet"])
      if Database.exists?(path)
        shell.say "Database already exists", Shell::YELLOW
        return
      end
      download(path, shell, options["quiet"])
    end

    def update_command(args)
      options, positional = parse(args, "update")
      update(positional.first || Database.default_path, Shell.new($stdout, options["quiet"]), options["quiet"])
    end

    def download(path, shell, quiet)
      shell.say "Download ruby-advisory-db ..."
      Database.download(path, quiet)
      print_stats(path) unless quiet
    rescue Database::DownloadFailed => error
      shell.say error.message, Shell::RED
      exit 1
    end

    def update(path, shell, quiet)
      return download(path, shell, quiet) unless Database.exists?(path)

      shell.say "Updating ruby-advisory-db ..."
      case Database.new(path).update!(quiet)
      when true
        shell.say "Updated ruby-advisory-db", Shell::GREEN
      when nil
        unless Database.git_installed?
          shell.say_error "Git is not installed!", Shell::RED
          exit 1
        end
        shell.say "Skipping update, ruby-advisory-db is not a git repository", Shell::YELLOW
      end
      print_stats(path) unless quiet
    rescue Database::UpdateFailed => error
      shell.say error.message, Shell::RED
      exit 1
    end

    def help(args)
      name = args.first
      if name && COMMANDS.key?(name)
        usage, description = COMMANDS[name]
        puts "Usage:\n  spinel-bundler-audit #{usage}\n\n#{description}"
        return
      end
      puts "Commands:"
      width = COMMANDS.values.map { |usage, _| usage.size }.max
      COMMANDS.each_value { |usage, description| puts "  spinel-bundler-audit #{usage.ljust(width)}  # #{description}" }
    end

    # Returns [options, positional arguments]; at most one positional
    # (the directory or database path) is accepted.
    def parse(args, command)
      options = default_options(command)
      parser = option_parser(command, options)
      begin
        positional = parser.parse(expand_ignore(args))
      rescue OptionParser::ParseError => error
        raise UsageError, error.message
      end
      if positional.size > 1
        raise UsageError, "ERROR: \"spinel-bundler-audit #{command}\" was called with arguments #{positional.inspect}\n" \
                          "Usage: \"spinel-bundler-audit #{COMMANDS[command][0]}\""
      end
      [options, positional]
    end

    def default_options(command)
      options = { "quiet" => false }
      return options unless command == "check"

      options["verbose"] = false
      options["ignore"] = nil
      options["update"] = false
      options["database"] = nil
      options["format"] = "text"
      options["config"] = ".bundler-audit.yml"
      options["gemfile_lock"] = "Gemfile.lock"
      options["output"] = nil
      options
    end

    def option_parser(command, options)
      parser = OptionParser.new
      parser.program_name = "spinel-bundler-audit"
      parser.version = VERSION
      parser.banner = "Usage: spinel-bundler-audit #{COMMANDS[command][0]} [options]"
      parser.on("-q", "--[no-]quiet", "Be quiet") { |value| options["quiet"] = value }
      add_check_options(parser, options) if command == "check"
      parser
    end

    def add_check_options(parser, options)
      parser.on("-v", "--[no-]verbose", "Run in verbose mode") { |value| options["verbose"] = value }
      parser.on("-i", "--ignore ADVISORY", String, "Advisory IDs to ignore (repeatable)") do |value|
        options["ignore"] = (options["ignore"] || []) + [value]
      end
      parser.on("-u", "--[no-]update", "Update the database before checking") { |value| options["update"] = value }
      parser.on("-D", "--database PATH", String, "Path to the advisory database") { |value| options["database"] = value }
      parser.on("-F", "--format FORMAT", String, "Output format (text, json, junit)") { |value| options["format"] = value }
      parser.on("-c", "--config FILE", String, "Configuration file") { |value| options["config"] = value }
      parser.on("-G", "--gemfile-lock FILE", String, "Gemfile.lock to check") { |value| options["gemfile_lock"] = value }
      parser.on("-o", "--output FILE", String, "Write the report to FILE") { |value| options["output"] = value }
    end

    # bundler-audit's "-i CVE-1 CVE-2" form: every argument up to the next
    # option is another advisory to ignore. Each becomes its own
    # "--ignore=VALUE", which optparse cannot pair with the wrong token.
    def expand_ignore(args)
      expanded = []
      ignoring = false
      waiting = nil # the -i or --ignore still without a value
      args.each do |arg|
        if ignoring && !arg.start_with?("-")
          expanded << "--ignore=#{arg}"
          waiting = nil
          next
        end
        raise UsageError, "missing argument: #{waiting}" if waiting

        if arg == "-i" || arg == "--ignore"
          ignoring = true
          waiting = arg
        else
          ignoring = arg.start_with?("--ignore=")
          expanded << arg
        end
      end
      raise UsageError, "missing argument: #{waiting}" if waiting

      expanded
    end
  end
end
