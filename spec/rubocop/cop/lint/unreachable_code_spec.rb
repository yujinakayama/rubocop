# frozen_string_literal: true

describe RuboCop::Cop::Lint::UnreachableCode do
  subject(:cop) { described_class.new }

  described_class::NODE_TYPES.each do |t|
    it "registers an offense for #{t} before other statements" do
      inspect_source(cop,
                     ['foo = 5',
                      t.to_s,
                      'bar'])
      expect(cop.offenses.size).to eq(1)
    end

    it "accepts code with conditional #{t}" do
      inspect_source(cop, <<-END.strip_indent)
        foo = 5
        #{t} if test
        bar
      END
      expect(cop.offenses).to be_empty
    end

    it "accepts #{t} as the final expression" do
      inspect_source(cop, <<-END.strip_indent)
        foo = 5
        #{t} if test
      END
      expect(cop.offenses).to be_empty
    end
  end

  described_class::FLOW_COMMANDS.each do |t|
    it "registers an offense for #{t} before other statements" do
      inspect_source(cop, <<-END.strip_indent)
        foo = 5
        #{t} something
        bar
      END
      expect(cop.offenses.size).to eq(1)
    end

    it "accepts code with conditional #{t}" do
      inspect_source(cop, <<-END.strip_indent)
        foo = 5
        #{t} something if test
        bar
      END
      expect(cop.offenses).to be_empty
    end

    it "accepts #{t} as the final expression" do
      inspect_source(cop, <<-END.strip_indent)
        foo = 5
        #{t} something if test
      END
      expect(cop.offenses).to be_empty
    end
  end
end
