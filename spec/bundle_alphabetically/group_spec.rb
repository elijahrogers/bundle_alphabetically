require "spec_helper"

RSpec.describe BundleAlphabetically::Group do
  let(:group) { BundleAlphabetically::Group.new(lines, indices) }
  let(:indices) { { body_start: 0, body_end: 3 } }

  describe "#find_entries" do
    let(:lines) do
      [
        'gem "rails"',
        'gem "bootsnap"',
        'gem "puma"',
      ]
    end

    it "finds the entries in the group" do
      group.find_entries
      expect(group.entries.first).to eq({ name: "rails", lines: ["gem \"rails\""], formatting_lines: [] })
    end

    it 'only collects entries between start and end indices' do
      group = BundleAlphabetically::Group.new(lines, { body_start: 1, body_end: 1 })
      group.find_entries
      expect(group.entries).to eq([{ name: "bootsnap", lines: ["gem \"bootsnap\""], formatting_lines: [] }])
    end

    context 'when a gem name is not valid' do
      let(:lines) do
        [
          'gem "rails"',
          'gem ',
          'gem "puma"',
        ]
      end

      it 'marks the group as unsortable' do
        group.find_entries

        expect(group.unsortable).to be true
      end
    end

    context 'when the group has formatting lines' do
      let(:lines) do
        [
          '# This is a comment',
          'gem "rails"',
          '# This is another comment',
        ]
      end

      it 'collects the formatting lines' do
        group.find_entries
        expect(group.entries.first[:formatting_lines]).to eq(["# This is a comment"])
      end
    end

    context 'when the group is empty' do
      let(:lines) { [] }
      let(:indices) { { body_start: 0, body_end: 0 } }

      it "does not find any entries" do
        group.find_entries
        expect(group.entries).to be_empty
      end
    end
  end

  describe '#sort_entries!' do
    let(:indices) { { body_start: 1, body_end: 3 } }
    let(:lines) do
      [
        'group "development" do',
        '  gem "rails" ~> 7.0',
        '  gem "bootsnap" ~> 1.0',
        '  gem "puma" ~> 5.0',
        'end',
      ]
    end

    before do
      group.entries = [
        { name: "rails", lines: ["  gem \"rails\" ~> 7.0"], formatting_lines: [] },
        { name: "bootsnap", lines: ["  gem \"bootsnap\" ~> 1.0"], formatting_lines: [] },
        { name: "puma", lines: ["  gem \"puma\" ~> 5.0"], formatting_lines: [] },
      ]
    end

    it 'sorts the entries alphabetically' do
      group.sort_entries!

      expect(group.body).to eq([
        '  gem "bootsnap" ~> 1.0',
        '  gem "puma" ~> 5.0',
        '  gem "rails" ~> 7.0',
      ])
    end

    context 'when the group has formatting lines' do
      let(:lines) do
        [
          'group "development" do',
          '  # This is a comment',
          '  gem "rails" ~> 7.0',
          '  gem "bootsnap" ~> 1.0',
          '  # This is another comment',
          '  gem "puma" ~> 5.0',
          'end',
        ]
      end

      before do
        group.entries = [
          { name: "rails", lines: ["  gem \"rails\" ~> 7.0"], formatting_lines: ["  # This is a comment"] },
          { name: "bootsnap", lines: ["  gem \"bootsnap\" ~> 1.0"], formatting_lines: ["  # This is another comment"] },
          { name: "puma", lines: ["  gem \"puma\" ~> 5.0"], formatting_lines: [] },
        ]
      end

      it 'preserves the formatting lines' do
        group.sort_entries!
        expect(group.body).to eq([
          '  # This is another comment',
          '  gem "bootsnap" ~> 1.0',
          '  gem "puma" ~> 5.0',
          '  # This is a comment',
          '  gem "rails" ~> 7.0',
        ])
      end
    end
  end

  describe '#blank_or_comment?' do
    let(:group) { BundleAlphabetically::Group.new([]) }

    it 'handles blank lines' do
      expect(group.blank_or_comment?('')).to be true
      expect(group.blank_or_comment?('     ')).to be true
      expect(group.blank_or_comment?("\n")).to be true
      expect(group.blank_or_comment?("\t")).to be true
    end

    it 'handles comment lines' do
      expect(group.blank_or_comment?('# This is a comment')).to be true
      expect(group.blank_or_comment?('This is not a #comment')).to be false
    end

    it 'handles non-blank, non-comment lines' do
      expect(group.blank_or_comment?('gem "rails"')).to be false
    end
  end

  describe '#gem_start?' do
    let(:lines) { [] }

    it 'handles gem declarations' do
      expect(group.gem_start?('gem "rails"')).to be true
      expect(group.gem_start?('gem("rails")')).to be true
    end

    it 'handles non-gem declarations' do
      expect(group.gem_start?('group "rails"')).to be false
    end

    it 'handles comments' do
      expect(group.gem_start?('# gem "rails"')).to be false
    end
  end

  describe '#extract_gem_name' do
    let(:lines) { [] }

    it 'extracts the correct gem name' do
      expect(group.extract_gem_name('gem "rails"')).to eq("rails")
    end

    it 'retruns nil if no gem is found' do
      expect(group.extract_gem_name('group "rails"')).to be nil
    end

    it 'handles hyphens and underscores in gem names' do
      expect(group.extract_gem_name('gem "rails-activerecord"')).to eq("rails-activerecord")
      expect(group.extract_gem_name('gem "log_bench"')).to eq("log_bench")
    end
  end

  describe '#indent_of' do
    let(:lines) { [] }

    it 'returns the correct indent of a line' do
      expect(group.indent_of('  gem "rails"')).to eq(2)
      expect(group.indent_of('gem "rails"')).to eq(0)
      expect(group.indent_of('      gem "rails"')).to eq(6)
    end

    it 'handles tabs' do
      expect(group.indent_of("\tgem \"rails\"")).to eq(1)
      expect(group.indent_of("\t\tgem \"rails\"")).to eq(2)
      expect(group.indent_of("\t\t\tgem \"rails\"")).to eq(3)
    end
  end
end
