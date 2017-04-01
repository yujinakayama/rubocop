# frozen_string_literal: true

describe RuboCop::Cop::Style::UnlessElse do
  subject(:cop) { described_class.new }

  context 'unless with else' do
    let(:source) do
      <<-END.strip_indent
        unless x # negative 1
          a = 1 # negative 2
        else # positive 1
          a = 0 # positive 2
        end
      END
    end

    it 'registers an offense' do
      inspect_source(cop, source)
      expect(cop.offenses.size).to eq(1)
    end

    it 'auto-corrects' do
      corrected = autocorrect_source(cop, source)
      expect(corrected).to eq(<<-END.strip_indent)
        if x # positive 1
          a = 0 # positive 2
        else # negative 1
          a = 1 # negative 2
        end
      END
    end
  end

  context 'unless with nested if-else' do
    let(:source) do
      <<-END.strip_indent
        unless(x)
          if(y == 0)
            a = 0
          elsif(z == 0)
            a = 1
          else
            a = 2
          end
        else
          a = 3
        end
      END
    end

    it 'registers an offense' do
      inspect_source(cop, source)
      expect(cop.offenses.size).to eq(1)
    end

    it 'auto-corrects' do
      corrected = autocorrect_source(cop, source)
      expect(corrected).to eq(<<-END.strip_indent)
        if(x)
          a = 3
        else
          if(y == 0)
            a = 0
          elsif(z == 0)
            a = 1
          else
            a = 2
          end
        end
      END
    end
  end

  context 'unless without else' do
    it 'does not register an offense' do
      inspect_source(cop, <<-END.strip_indent)
        unless x
          a = 1
        end
      END
      expect(cop.offenses).to be_empty
    end
  end
end
