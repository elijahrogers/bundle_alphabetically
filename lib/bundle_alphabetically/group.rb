class BundleAlphabetically::Group
  attr_accessor :header_index, :body_start_index, :body_end_index, :end_index, :unsortable, :entries, :lines

  def initialize(lines, indices = {})
    @lines            = lines
    @header_index     = indices[:header]
    @body_start_index = indices[:body_start]
    @body_end_index   = indices[:body_end]
    @end_index        = indices[:end]
    @entries          = []
    @unsortable       = false
  end

  def sort!
    return unless valid?

    find_entries && sort_entries!
  end

  def sort_entries!
    return if unsortable || entries.empty?

    sorted = entries.sort_by { |entry| entry[:name].downcase }
    new_lines = []

    sorted.each_with_index do |entry, index|
      if entry[:formatting_lines].any?
        entry[:formatting_lines].each { |line| new_lines << line }
      end

      entry[:lines].each { |line| new_lines << line }
    end

    self.body = new_lines
  end

  def find_entries
    index = body_start_index

    while index <= body_end_index
      formatting_lines, entry_lines, after_entry_index = collect_gem_entry(index)

      break if formatting_lines.empty? && entry_lines.empty?

      # If we haven't advanced, force a break to avoid infinite loops
      break if after_entry_index == index

      if entry_lines.any?
        name = extract_gem_name(entry_lines.first)

        if name
          entries << { name: name, lines: entry_lines, formatting_lines: formatting_lines }
        else
          @unsortable = true
          entries << { name: "", lines: entry_lines, formatting_lines: formatting_lines }
        end
      else
        # Trailing formatting lines
        entries << { name: "", lines: [], formatting_lines: formatting_lines }
        @unsortable = true unless formatting_lines.all? { |l| l.strip.empty? }
      end

      index = after_entry_index
    end
  end

  def collect_gem_entry(start_index)
    formatting_lines = []

    while start_index <= body_end_index && start_index < lines.length && blank_or_comment?(lines[start_index])
      formatting_lines << lines[start_index]
      start_index += 1
    end

    if start_index > body_end_index || start_index >= lines.length
      return [formatting_lines, [], start_index]
    end

    entry_lines = [lines[start_index]]
    base_indent = indent_of(lines[start_index])
    i = start_index + 1

    while i <= body_end_index && i < lines.length
      line = lines[i]
      stripped = line.lstrip
      indent = indent_of(line)

      # A blank line indicates the end of this entry and start of formatting for next
      break if stripped.empty?

      # A comment at base indentation indicates start of next entry's formatting
      if blank_or_comment?(line) && indent <= base_indent
        break
      end

      if indent <= base_indent && starter_keyword?(stripped)
        break
      end

      entry_lines << line
      i += 1
    end

    [formatting_lines, entry_lines, i]
  end

  def valid?
    body_end_index > body_start_index
  end

  def body
    @body ||= lines[body_start_index..body_end_index]
  end

  def body=(new_lines)
    @body = new_lines
  end

  # TODO: Handle multi-line comments at some point
  def blank_or_comment?(line)
    line.strip.empty? || line.strip.start_with?("#")
  end

  def indent_of(line)
    line[/\A[ \t]*/].size
  end

  def gem_start?(line)
    return false if blank_or_comment?(line)

    line.lstrip.start_with?("gem ") || line.lstrip.start_with?("gem(")
  end

  def extract_gem_name(line)
    stripped = line.lstrip
    match = stripped.match(/\Agem\s+["']([^"']+)["']/)
    match && match[1]
  end

  def starter_keyword?(stripped)
    stripped.start_with?("gem ", "gem(", "group ", "group(", "source ", "source(", "ruby ", "ruby(", "path ", "path(", "plugin ", "plugin(", "platforms ", "platforms(", "end")
  end
end
