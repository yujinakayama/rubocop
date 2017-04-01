# frozen_string_literal: true

describe RuboCop::Cop::Style::MultilineHashBraceLayout, :config do
  subject(:cop) { described_class.new(config) }
  let(:cop_config) { { 'EnforcedStyle' => 'symmetrical' } }

  it 'ignores implicit hashes' do
    inspect_source(cop, <<-END.strip_indent)
      foo(a: 1,
      b: 2)
    END

    expect(cop.offenses).to be_empty
  end

  it 'ignores single-line hashes' do
    inspect_source(cop, '{a: 1, b: 2}')

    expect(cop.offenses).to be_empty
  end

  it 'ignores empty hashes' do
    inspect_source(cop, '{}')

    expect(cop.offenses).to be_empty
  end

  include_examples 'multiline literal brace layout' do
    let(:open) { '{' }
    let(:close) { '}' }
    let(:a) { 'a: 1' }
    let(:b) { 'b: 2' }
    let(:multi_prefix) { 'b: ' }
    let(:multi) { ['[', '1', ']'] }
  end

  include_examples 'multiline literal brace layout trailing comma' do
    let(:open) { '{' }
    let(:close) { '}' }
    let(:a) { 'a: 1' }
    let(:b) { 'b: 2' }
  end
end
