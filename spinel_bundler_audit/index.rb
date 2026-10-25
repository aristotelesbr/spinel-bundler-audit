module SpinelBundlerAudit
  # Every advisory of the database in one file, so a check reads one file
  # instead of parsing a YAML file per advisory. It is tied to the commit
  # the database is checked out at: when the commit changes the index is
  # stale and the database is read as YAML again.
  #
  # Layout: a header line, the commit, the number of gems, one
  # "dir<TAB>offset<TAB>length" line per gem directory, then the records
  # (one line per advisory, grouped by gem; offsets in bytes into them).
  # A check reads the table and then only the records of its gems.
  class Index
    HEADER = "spinel-bundler-audit index 1"
    NIL = "\\N"
    # A JSON column holding this is the JSON string of the text column.
    SAME = "\\S"
    LIST_SEPARATOR = "\x1f"
    ESCAPES = { "\\" => "\\\\", "\t" => "\\t", "\n" => "\\n", "\r" => "\\r" }.freeze
    UNESCAPES = { "\\\\" => "\\", "\\t" => "\t", "\\n" => "\n", "\\r" => "\r" }.freeze

    def self.path_for(database_path)
      cache = ENV["XDG_CACHE_HOME"] || File.join(Dir.home, ".cache")
      key = File.expand_path(database_path).gsub(/[^A-Za-z0-9._-]/, "_")
      File.join(cache, "spinel-bundler-audit", "#{key}.index")
    end

    # The commit a git checkout is at, read from .git without running git;
    # nil when the database is not a plain git checkout.
    def self.revision(database_path)
      git = File.join(database_path, ".git")
      return nil unless File.directory?(git)

      head = File.read(File.join(git, "HEAD")).strip
      return head if head.match?(/\A[0-9a-f]{40}\z/)

      ref = head[/\Aref: (.+)\z/, 1]
      return nil if ref.nil?

      loose = File.join(git, ref)
      return File.read(loose).strip if File.file?(loose)

      packed = File.join(git, "packed-refs")
      return nil unless File.file?(packed)

      File.read(packed).each_line do |line|
        sha, name = line.chomp.split(" ", 2)
        return sha if name == ref
      end
      nil
    end

    # Writes the index for the database at its current commit. Returns the
    # index, or nil when there is no commit to tie it to or it cannot be
    # written (the check then reads YAML, as without an index).
    def self.build(database_path)
      revision = revision(database_path)
      return nil if revision.nil?

      groups = []
      current = nil
      Dir.glob(File.join(database_path, "gems", "*", "*.yml")).sort.each do |file|
        dir = File.basename(File.dirname(file))
        if current.nil? || current[0] != dir
          current = [dir, +""]
          groups << current
        end
        current[1] << record(File.basename(file), Advisory.load(file)) << "\n"
      end

      table = +""
      offset = 0
      groups.each do |dir, body|
        table << "#{dir}\t#{offset}\t#{body.bytesize}\n"
        offset += body.bytesize
      end
      text = +"#{HEADER}\n#{revision}\n#{groups.size}\n"
      text << table
      groups.each { |_, body| text << body }

      write(path_for(database_path), text)
      load(database_path)
    rescue StandardError
      nil
    end

    # The index for the database when one exists for its current commit.
    def self.load(database_path)
      revision = revision(database_path)
      return nil if revision.nil?

      path = path_for(database_path)
      return nil unless File.file?(path)

      file = File.open(path, "rb")
      unless file.gets == "#{HEADER}\n" && file.gets == "#{revision}\n"
        file.close
        return nil
      end

      new(database_path, file)
    end

    def self.write(path, text)
      dir = File.dirname(path)
      Dir.mkdir(File.dirname(dir)) unless File.directory?(File.dirname(dir))
      Dir.mkdir(dir) unless File.directory?(dir)
      temporary = "#{path}.#{Process.pid}"
      File.write(temporary, text)
      File.rename(temporary, path)
    end

    def self.record(file, advisory)
      fields = [file]
      Advisory::TEXT_FIELDS.each { |field| fields << encode(advisory.texts[field]) }
      fields << encode(advisory.unaffected_texts.join(LIST_SEPARATOR))
      fields << encode(advisory.patched_texts.join(LIST_SEPARATOR))
      Advisory::JSON_FIELDS.each do |field|
        literal = advisory.json(field)
        text = advisory.texts[field]
        fields << (field != "date" && literal == (text.nil? ? "null" : JsonWriter.string(text)) ? SAME : encode(literal))
      end
      fields.join("\t")
    end

    def self.encode(value)
      return NIL if value.nil?

      value.gsub(/[\\\t\n\r]/) { |char| ESCAPES[char] }
    end

    def self.decode(value)
      return nil if value == NIL

      value.gsub(/\\[\\tnr]/) { |pair| UNESCAPES[pair] }
    end

    # Reads the table from file, positioned after the commit line; each gem's
    # records are read from the file only when asked for.
    def initialize(database_path, file)
      @database_path = database_path
      @file = file
      @groups = {}
      file.gets.to_i.times do
        dir, offset, length = file.gets.chomp.split("\t")
        @groups[dir] = [offset.to_i, length.to_i]
      end
      @body_start = file.pos
    end

    # The advisories of a gem directory, or nil when the index has no
    # directory by that exact name.
    def advisories_for(name)
      group = @groups[name]
      return nil if group.nil?

      @file.seek(@body_start + group[0])
      body = @file.read(group[1]).force_encoding(Encoding::UTF_8)
      body.split("\n").map { |line| advisory(name, line) }
    end

    # The gem directory whose name differs from name only in case.
    def directory_like(name)
      @groups.keys.find { it.casecmp?(name) }
    end

    private

    def advisory(dir, line)
      fields = line.split("\t", -1)
      file = fields[0]
      texts = {}
      Advisory::TEXT_FIELDS.each_with_index { |field, i| texts[field] = Index.decode(fields[1 + i]) }
      base = 1 + Advisory::TEXT_FIELDS.size
      unaffected = Index.list(fields[base])
      patched = Index.list(fields[base + 1])
      json = {}
      Advisory::JSON_FIELDS.each_with_index do |field, i|
        raw = fields[base + 2 + i]
        json[field] = Index.decode(raw) unless raw == Index::SAME
      end
      Advisory.new(File.join(@database_path, "gems", dir, file), File.basename(file, ".yml"),
                   texts, json, unaffected, patched)
    end

    def self.list(value)
      text = decode(value)
      text.nil? || text.empty? ? [] : text.split(LIST_SEPARATOR)
    end
  end
end
