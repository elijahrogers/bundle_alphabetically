require "bundler"
require "set"

module BundleAlphabetically
  class GemfileSorter
    class << self
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
          raise Bundler::BundlerError, "Gemfile is not alphabetically sorted"
        else
          File.write(path, sorted)
          io.puts "Gemfile gems alphabetized by bundle_alphabetically"
        end
      end

      def sort_contents(contents)
        lines = contents.lines
        return contents if lines.empty?

        group_ranges = find_group_ranges(lines)

        sort_group_bodies!(lines, group_ranges)
        sort_top_level_segments!(lines, group_ranges)

        lines.join
      end

      private

      def find_group_ranges(lines)
        ranges = []
        i = 0

        while i < lines.length
          line = lines[i]
          if group_header?(line)
            header = i
            end_index = find_matching_end(lines, header)

            if end_index
              ranges << {
                header: header,
                body_start: header + 1,
                body_end: end_index - 1,
                end: end_index
              }
              i = end_index + 1
              next
            end
          end

          i += 1
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

      def top_level_ranges(total_lines, in_group_indices)
        ranges = []
        start = nil

        (0...total_lines).each do |idx|
          if in_group_indices.include?(idx)
            if start
              ranges << { start: start, end: idx - 1 }
              start = nil
            end
          else
            start ||= idx
          end
        end

        ranges << { start: start, end: total_lines - 1 } if start
        ranges
      end

      def sort_group_bodies!(lines, group_ranges)
        group_ranges.each do |range|
          body_start = range[:body_start]
          body_end = range[:body_end]
          next if body_end < body_start

          segment = lines[body_start..body_end]
          lines[body_start..body_end] = sort_gem_lines(segment)
        end
      end

      def sort_top_level_segments!(lines, group_ranges)
        in_group_indices = group_ranges.flat_map { |r| (r[:header]..r[:end]) }.to_set

        top_level_ranges(lines.size, in_group_indices).each do |range|
          seg_start = range[:start]
          seg_end = range[:end]
          next if seg_end < seg_start

          segment = lines[seg_start..seg_end]
          lines[seg_start..seg_end] = sort_gem_lines(segment)
        end
      end

      def sort_gem_lines(lines)
        result = []
        i = 0

        while i < lines.length
          line = lines[i]

          if gem_start?(line)
            region, new_index = collect_and_sort_gem_region(lines, i)
            result.concat(region)
            i = new_index
          else
            result << line
            i += 1
          end
        end

        result
      end

      def collect_and_sort_gem_region(lines, start_index)
        region_state, i = collect_gem_region(lines, start_index)
        separators = region_state[:separators]
        entries = region_state[:entries]
        unsortable = region_state[:unsortable]

        # If we couldn't safely parse names, or there is nothing to sort,
        # return the region untouched.
        if unsortable || entries.length <= 1
          return [lines[start_index...i], i]
        end

        sorted_indices = (0...entries.length).sort_by do |idx|
          entries[idx][:name].downcase
        end

        region_result = []

        region_result.concat(separators[0])

        sorted_indices.each_with_index do |entry_idx, pos|
          region_result.concat(entries[entry_idx][:lines])
          if pos + 1 < separators.length
            region_result.concat(separators[pos + 1])
          end
        end

        [region_result, i]
      end

      def collect_gem_region(lines, start_index)
        separators = [[]]
        entries = []
        i = start_index
        unsortable = false

        while i < lines.length
          # separators before next gem in the region
          while i < lines.length && blank_or_comment?(lines[i])
            separators.last << lines[i]
            i += 1
          end

          break if i >= lines.length
          break unless gem_start?(lines[i])

          entry_start = i
          name = extract_gem_name(lines[entry_start])

          unsortable ||= name.nil?

          entry_lines, after_entry_index = collect_gem_entry(lines, entry_start)

          if name
            entries << { name: name, lines: entry_lines }
          else
            # if we cannot extract a name, keep the entry but mark as unsortable
            entries << { name: "", lines: entry_lines }
          end

          i = after_entry_index

          # separators between this entry and the next (or trailing separators)
          separators << []

          while i < lines.length && blank_or_comment?(lines[i])
            separators.last << lines[i]
            i += 1
          end

          break if i >= lines.length
          break unless gem_start?(lines[i])
        end

        [{ separators: separators, entries: entries, unsortable: unsortable }, i]
      end

      def collect_gem_entry(lines, start_index)
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

        [entry_lines, i]
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

      def starter_keyword?(stripped)
        stripped.start_with?("gem ", "gem(", "group ", "group(", "source ", "source(", "ruby ", "ruby(", "path ", "path(", "plugin ", "plugin(", "platforms ", "platforms(", "end")
      end

      def indent_of(line)
        line[/\A[ \t]*/].size
      end
    end
  end
end


