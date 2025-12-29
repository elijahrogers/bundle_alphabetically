require_relative "common"

class BundleAlphabetically::Group
  include BundleAlphabetically::Common

  attr_accessor :header_index, :body_start_index, :body_end_index, :end_index, :unsortable, :entries, :lines, :trailing_lines, :leading_lines

  def initialize(lines, indices = {})
    @lines            = lines
    @header_index     = indices[:header]
    @body_start_index = indices[:body_start]
    @body_end_index   = indices[:body_end]
    @end_index        = indices[:end]
    @entries          = []
    @unsortable       = false
    @trailing_lines   = []
    @leading_lines    = []
  end

  def sort!
    return unless valid?

    find_entries
    sort_entries!
  end

  def sort_entries!
    return if unsortable || entries.empty?

    collect_trailing_lines
    collect_leading_lines
    normalize_formatting_lines

    sorted_entries = entries.sort_by { |e| e[:name].downcase }

    self.body = rebuild_body(sorted_entries)
  end

  def rebuild_body(sorted_entries)
    new_body = []

    leading_lines.each { |line| new_body << line } if !leading_separator_exists?

    sorted_entries.each_with_index do |entry, index|
      # Always move leading blanks for the first entry
      move_leading_blanks = entry[:formatting_lines].empty? || index.zero?

      new_body = append_entry(entry, new_body, move_leading_blanks)
    end

    trailing_lines.each { |line| new_body << line } if trailing_lines.any?

    new_body
  end

  # If an entry has no comments/formatting (just a plain gem), treat blanks as trailing
  # separators by placing them after the entry. This keeps "section" spacing stable when
  # gems reorder.
  def append_entry(entry, new_body, move_leading_blanks)
    leading_blanks = entry[:leading_blanks] || []

    leading_blanks.each { |line| new_body << line } unless move_leading_blanks

    entry[:formatting_lines].each { |line| new_body << line }
    entry[:lines].each { |line| new_body << line }

    leading_blanks.each { |line| new_body << line } if move_leading_blanks

    new_body
  end

  def normalize_formatting_lines
    entries.each do |entry|
      entry[:leading_blanks] = []
      next unless entry[:formatting_lines]&.any?

      while entry[:formatting_lines].any? && entry[:formatting_lines].first.strip.empty?
        entry[:leading_blanks] << entry[:formatting_lines].shift
      end
    end
  end

  # If the group starts with blank lines (e.g. spacing after `plugin` / `gemspec`),
  # keep them at the start of the group rather than attaching them to a gem
  # that might move during sorting.
  def collect_leading_lines
    return unless entries.first[:formatting_lines]&.any?

    while entries.first[:formatting_lines].any? && entries.first[:formatting_lines].first.strip.empty?
      @leading_lines << entries.first[:formatting_lines].shift
    end
  end

  # Don't sort trailing comments and blank lines
  def collect_trailing_lines
    return unless entries.last[:name].empty? && entries.last[:lines].empty?

    @trailing_lines = entries.pop[:formatting_lines]
  end

  # If we're starting from the top or the prior group ended with a blank line,
  # we don't need to move leading blank lines before the first entry.
  def leading_separator_exists?
    !body_start_index.positive? || lines[body_start_index - 1].strip.empty?
  end

  def find_entries
    index = body_start_index

    while index <= body_end_index
      formatting_lines, entry_lines, after_entry_index = collect_gem_entry(lines, index, body_end_index)

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
