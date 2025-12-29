module BundleAlphabetically
  module Common
    def collect_gem_entry(lines, start_index, body_end_index = nil)
      body_end_index ||= lines.length - 1
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

        break if stripped.empty?

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

    def blank_or_comment?(line)
      line.strip.empty? || line.strip.start_with?("#")
    end

    def indent_of(line)
      line[/\A[ \t]*/].size
    end

    def starter_keyword?(stripped)
      stripped.start_with?(
        "gem ", "gem(",
        "group ", "group(",
        "source ", "source(",
        "ruby ", "ruby(",
        "path ", "path(",
        "plugin ", "plugin(",
        "platforms ", "platforms(",
        "end",
        "gemspec",
        "git ", "git(",
        "if ", "else",
        "local_gemfile",
        "instance_eval",
        "rack_version"
      )
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
  end
end

