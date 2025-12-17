require "bundler"
require "set"

require_relative "group"
require_relative "common"

module BundleAlphabetically
  class GemfileSorter
    extend Common

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
        @lines = contents.lines
        return contents if lines.empty?

        process_gemfile!

        lines.join
      end

      private

      def process_gemfile!
        i = 0
        current_group_start = nil

        while i < lines.size
          # Peek ahead of comments to find next group
          peek_index = i
          while peek_index < lines.size && blank_or_comment?(lines[peek_index])
            peek_index += 1
          end

          # 2. If we hit a group header, handle it
          if peek_index < lines.size && group_header?(lines[peek_index])

            # Close current group including blanks and comments
            if current_group_start
               process_gem_block(current_group_start, peek_index - 1)
               current_group_start = nil
            end

            # Now we are at the group header.
            i = process_group_block(peek_index)
            next
          end

          # 3. Not a group. Consume the next "entry" (gem, source, ruby, etc.)
          _, entry_lines, next_index = collect_gem_entry(lines, i)

          if gem_entry?(entry_lines)
            current_group_start ||= i
          else
            # We hit something that isn't a gem and isn't a group (e.g. source, ruby version, etc.)
            process_gem_block(current_group_start, i - 1) if current_group_start
            current_group_start = nil
          end

          i = next_index
        end

        # Finish any trailing gem block
        process_gem_block(current_group_start, lines.size - 1) if current_group_start
      end

      def process_group_block(header_index)
        end_index = find_matching_end(lines, header_index)

        # If we can't find an end, just skip this line
        return header_index + 1 unless end_index

        group = Group.new(lines, {
          header: header_index,
          body_start: header_index + 1,
          body_end: end_index - 1,
          end: end_index
        })

        group.sort!
        lines[group.body_start_index..group.body_end_index] = group.body if group.body

        end_index + 1
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

      def gem_entry?(entry_lines)
        entry_lines.any? && gem_start?(entry_lines.first)
      end

      def process_gem_block(start_index, end_index)
        return unless start_index

        create_and_sort_group(lines, start_index, end_index)
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
    end
  end
end
