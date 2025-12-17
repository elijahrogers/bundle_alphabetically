require_relative "common"

class BundleAlphabetically::Group
  include BundleAlphabetically::Common

  attr_accessor :header_index, :body_start_index, :body_end_index, :end_index, :unsortable, :entries, :lines, :trailing_entry

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

  def valid?
    body_end_index > body_start_index
  end

  def body
    @body ||= lines[body_start_index..body_end_index]
  end

  def body=(new_lines)
    @body = new_lines
  end
end
