# frozen_string_literal: true

describe RuboCop::Cop::Style::OpMethod do
  subject(:cop) { described_class.new }

  %i(+ eql? equal?).each do |op|
    it "registers an offense for #{op} with arg not named other" do
      inspect_source(cop,
                     ["def #{op}(another)",
                      '  another',
                      'end'])
      expect(cop.offenses.size).to eq(1)
      expect(cop.messages)
        .to eq(["When defining the `#{op}` operator, " \
                'name its argument `other`.'])
    end
  end

  it 'works properly even if the argument not surrounded with braces' do
    inspect_source(cop, <<-END.strip_indent)
      def + another
        another
      end
    END
    expect(cop.offenses.size).to eq(1)
    expect(cop.messages)
      .to eq(['When defining the `+` operator, name its argument `other`.'])
  end

  it 'does not register an offense for arg named other' do
    inspect_source(cop, <<-END.strip_indent)
      def +(other)
        other
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'does not register an offense for arg named _other' do
    inspect_source(cop, <<-END.strip_indent)
      def <=>(_other)
        0
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'does not register an offense for []' do
    inspect_source(cop, <<-END.strip_indent)
      def [](index)
        other
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'does not register an offense for []=' do
    inspect_source(cop, <<-END.strip_indent)
      def []=(index, value)
        other
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'does not register an offense for <<' do
    inspect_source(cop, <<-END.strip_indent)
      def <<(cop)
        other
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'does not register an offense for non binary operators' do
    inspect_source(cop, <<-END.strip_indent)
      def -@; end
                    # This + is not a unary operator. It can only be
                    # called with dot notation.
      def +; end
      def *(a, b); end # Quite strange, but legal ruby.
      def `(cmd); end
    END
    expect(cop.offenses).to be_empty
  end
end
