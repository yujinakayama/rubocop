# frozen_string_literal: true

describe RuboCop::Cop::Style::PredicateName, :config do
  subject(:cop) { described_class.new(config) }

  context 'with blacklisted prefixes' do
    let(:cop_config) do
      { 'NamePrefix' => %w[has_ is_],
        'NamePrefixBlacklist' => %w[has_ is_] }
    end

    %w[has is].each do |prefix|
      it 'registers an offense when method name starts with known prefix' do
        inspect_source(cop, ["def #{prefix}_attr",
                             '  # ...',
                             'end'])
        expect(cop.offenses.size).to eq(1)
        expect(cop.messages).to eq(["Rename `#{prefix}_attr` to `attr?`."])
        expect(cop.highlights).to eq(["#{prefix}_attr"])
      end
    end

    it 'accepts method name that starts with unknown prefix' do
      inspect_source(cop, <<-END.strip_indent)
        def have_attr
          # ...
        end
      END
      expect(cop.offenses).to be_empty
    end
  end

  context 'without blacklisted prefixes' do
    let(:cop_config) do
      { 'NamePrefix' => %w[has_ is_], 'NamePrefixBlacklist' => [] }
    end

    %w[has is].each do |prefix|
      it 'registers an offense when method name starts with known prefix' do
        inspect_source(cop, ["def #{prefix}_attr",
                             '  # ...',
                             'end'])
        expect(cop.offenses.size).to eq(1)
        expect(cop.messages)
          .to eq(["Rename `#{prefix}_attr` to `#{prefix}_attr?`."])
        expect(cop.highlights).to eq(["#{prefix}_attr"])
      end
    end

    it 'accepts method name that starts with unknown prefix' do
      inspect_source(cop, <<-END.strip_indent)
        def have_attr
          # ...
        end
      END
      expect(cop.offenses).to be_empty
    end
  end

  context 'with whitelisted predicate names' do
    let(:cop_config) do
      { 'NamePrefix' => %w[is_], 'NamePrefixBlacklist' => %w[is_],
        'NameWhitelist' => %w[is_a?] }
    end

    it 'accepts method name which is in whitelist' do
      inspect_source(cop, <<-END.strip_indent)
        def is_a?
          # ...
        end
      END
      expect(cop.offenses).to be_empty
    end
  end
end
