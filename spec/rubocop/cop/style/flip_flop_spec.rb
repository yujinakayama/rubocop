# frozen_string_literal: true

describe RuboCop::Cop::Style::FlipFlop do
  subject(:cop) { described_class.new }

  it 'registers an offense for inclusive flip flops' do
    inspect_source(cop, <<-END.strip_indent)
      DATA.each_line do |line|
      print line if (line =~ /begin/)..(line =~ /end/)
      end
    END
    expect(cop.offenses.size).to eq(1)
  end

  it 'registers an offense for exclusive flip flops' do
    inspect_source(cop, <<-END.strip_indent)
      DATA.each_line do |line|
      print line if (line =~ /begin/)...(line =~ /end/)
      end
    END
    expect(cop.offenses.size).to eq(1)
  end
end
