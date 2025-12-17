require "bundler"
require "set"

require_relative "group"

module BundleAlphabetically
  class GemfileSorter
    class CheckFailed < Bundler::BundlerError
      def status_code
        1
      end
    end

    class << self
      attr_accessor :groups, :lines

      def run!(check: false, io: $stdout)
        gemfile = Bundler.default_gemfile

        unless gemfile && File.file?(gemfile.to_s)
          raise Bundler::BundlerError, "Gemfile not found at #{gemfile}"
        end

        path = gemfile.to_s
        original = File.read(path)
        sorted = sort_contents(original)

        if original == sorted
          io.puts "Gemfile already sorted" unless check
          return
        end

        if check
          raise CheckFailed, "Gemfile is not alphabetically sorted"
        else
          File.write(path, sorted)
          io.puts "Gemfile gems alphabetized by bundle_alphabetically"
        end
      end

      def sort_contents(contents)
        @groups = []
        @lines = contents.lines
        return contents if lines.empty?

        find_group_ranges(lines)

        sort_group_bodies!(lines)
        sort_top_level_segments!(lines)

        lines.join
      end

      private

      def find_group_ranges(lines)
        ranges = []

        lines.each_with_index do |line, index|
          if group_header?(line)
            header = index
            end_index = find_matching_end(lines, header)

            if end_index
              groups << Group.new(lines, {
                header: header,
                body_start: header + 1,
                body_end: end_index - 1,
                end: end_index
              })
            end
          end
        end

        ranges
      end

      def group_header?(line)
        stripped = line.lstrip
        stripped.start_with?("group ") || stripped.start_with?("group(")
      end

      def find_matching_end(lines, header_index)
        header_indent = indent_of(lines[header_index])
        i = header_index + 1

        while i < lines.length
          line = lines[i]
          stripped = line.lstrip
          indent = indent_of(line)

          if group_header?(line) && indent > header_indent
            nested_end = find_matching_end(lines, i)
            return nil unless nested_end
            i = nested_end + 1
            next
          end

          if stripped.start_with?("end") && indent == header_indent
            return i
          end

          i += 1
        end

        nil
      end

      def sort_group_bodies!(lines)
        groups.each do |group|
          group.sort!
          lines[group.body_start_index..group.body_end_index] = group.body
        end
      end

      def sort_top_level_segments!(lines)
        forbidden_ranges = groups.map { |g| (g.header_index..g.end_index) }
        i = 0
        current_gem_block_start = nil

        while i < lines.size
          if (range = forbidden_ranges.find { |r| r.cover?(i) })
            if current_gem_block_start
              create_and_sort_group(lines, current_gem_block_start, i - 1)
              current_gem_block_start = nil
            end
            i = range.end + 1
            next
          end

          _, entry_lines, next_index = collect_gem_entry(lines, i)
          is_gem = entry_lines.any? && gem_start?(entry_lines.first)

          if is_gem
            current_gem_block_start ||= i
          else
            if current_gem_block_start
              create_and_sort_group(lines, current_gem_block_start, i - 1)
              current_gem_block_start = nil
            end
          end

          i = next_index
        end

        if current_gem_block_start
          create_and_sort_group(lines, current_gem_block_start, lines.size - 1)
        end
      end

      def create_and_sort_group(lines, start_index, end_index)
        return if start_index >= end_index

        group = Group.new(lines, {
          header: start_index,
          body_start: start_index,
          body_end: end_index,
          end: end_index
        })

        group.sort!
        lines[group.body_start_index..group.body_end_index] = group.body if group.body
      end

      def sort_gem_lines(lines)
        result = []
        i = 0

        while i < lines.length
          line = lines[i]

          if gem_start?(line)
            preceding_formatting = []
            while result.any? && blank_or_comment?(result.last)
              preceding_formatting.unshift(result.pop)
            end

            region, new_index = collect_and_sort_gem_region(lines, i, preceding_formatting)
            result.concat(region)
            i = new_index
          else
            result << line
            i += 1
          end
        end

        result
      end

      def collect_and_sort_gem_region(lines, start_index, initial_formatting = [])
        entries = []
        i = start_index
        unsortable = false
        first_entry = true

        loop do
          formatting_lines, entry_lines, next_index = collect_gem_entry(lines, i)

          if first_entry
            formatting_lines = initial_formatting + formatting_lines
            first_entry = false
          end

          if entry_lines.empty?
             # End of file or region
             if formatting_lines.any?
               entries << { name: "", lines: [], formatting_lines: formatting_lines }
             end
             i = next_index
             break
          end

          unless gem_start?(entry_lines.first)
            # We hit a non-gem line (e.g. group block or other code).
            # The formatting lines we collected belong to the gem region (trailing),
            # but the entry_lines do not.
            if formatting_lines.any?
               entries << { name: "", lines: [], formatting_lines: formatting_lines }
            end

            # The current entry_lines are NOT part of the region, so we must not consume them.
            # We advanced to next_index which is after entry_lines.
            # We need to return the index where entry_lines started.
            i = i + formatting_lines.size
            break
          end

          name = extract_gem_name(entry_lines.first)
          unsortable ||= name.nil?

          if name
            entries << { name: name, lines: entry_lines, formatting_lines: formatting_lines }
          else
            entries << { name: "", lines: entry_lines, formatting_lines: formatting_lines }
          end

          i = next_index
        end

        # If we couldn't safely parse names, or there is nothing to sort,
        # return the region untouched.
        # Note: if we have 1 gem + trailing comments, entries.length is 2. We don't sort.
        # But we might want to re-render to ensure formatting is attached?
        # No, if unsortable, we return original range.
        # Wait, i is the end index. existing code used lines[start_index...i].
        if unsortable || entries.count { |e| !e[:name].empty? } <= 1
          return [lines[start_index...i], i]
        end

        # Separate trailing entry if exists
        trailing_entry = nil
        if entries.last[:name].empty? && entries.last[:lines].empty?
          trailing_entry = entries.pop
        end

        sorted = entries.sort_by { |entry| entry[:name].downcase }

        if trailing_entry
          sorted << trailing_entry
        end

        region_result = []

        sorted.each do |entry|
          if entry[:formatting_lines].any?
             region_result.concat(entry[:formatting_lines])
          end
          region_result.concat(entry[:lines])
        end

        [region_result, i]
      end

      # No longer returns [separators, entries] structure
      # def collect_gem_region(lines, start_index) ... end

      def collect_gem_entry(lines, start_index)
        formatting_lines = []

        while start_index < lines.length && blank_or_comment?(lines[start_index])
          formatting_lines << lines[start_index]
          start_index += 1
        end

        if start_index >= lines.length
          return [formatting_lines, [], start_index]
        end

        entry_lines = [lines[start_index]]
        base_indent = indent_of(lines[start_index])
        i = start_index + 1

        while i < lines.length
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

      def gem_start?(line)
        stripped = line.lstrip
        return false if stripped.start_with?("#")

        stripped.start_with?("gem ") || stripped.start_with?("gem(")
      end

      def extract_gem_name(line)
        stripped = line.lstrip
        match = stripped.match(/\Agem\s+["']([^"']+)["']/)
        match && match[1]
      end

      def blank_or_comment?(line)
        stripped = line.lstrip
        stripped.empty? || stripped.start_with?("#")
      end

      def normalize_gem_separators(separators)
        last_index = separators.length - 1

        separators.each_with_index.map do |sep, idx|
          # keep leading separators intact (comments / blank lines before the
          # first gem in the region), and trailing separators (before the
          # next non-gem line)
          next sep if idx == 0 || idx == last_index

          contains_comment = sep.any? { |line| line.lstrip.start_with?("#") }

          if contains_comment
            sep
          else
            # strip out pure blank lines so consecutive gem entries are
            # rendered without empty lines between them
            sep.reject { |line| line.lstrip.empty? }
          end
        end
      end

      def starter_keyword?(stripped)
        stripped.start_with?("gem ", "gem(", "group ", "group(", "source ", "source(", "ruby ", "ruby(", "path ", "path(", "plugin ", "plugin(", "platforms ", "platforms(", "end")
      end

      def indent_of(line)
        line[/\A[ \t]*/].size
      end
    end
  end
end


