# frozen_string_literal: true

describe RuboCop::Cop::Style::MultilineAssignmentLayout, :config do
  subject(:cop) { described_class.new(config) }
  let(:supported_types) { %w[if] }

  let(:cop_config) do
    {
      'EnforcedStyle' => enforced_style,
      'SupportedTypes' => supported_types
    }
  end

  context 'new_line style' do
    let(:enforced_style) { 'new_line' }

    it 'registers an offense when the rhs is on the same line' do
      inspect_source(cop, <<-END.strip_indent)
        blarg = if true
        end
      END

      expect(cop.offenses.size).to eq(1)
      expect(cop.offenses.first.line).to eq(1)
      expect(cop.highlights).to eq(["blarg = if true\nend"])
      expect(cop.messages).to eq([described_class::NEW_LINE_OFFENSE])
    end

    it 'auto-corrects offenses' do
      new_source = autocorrect_source(cop, <<-END.strip_indent)
        blarg = if true
        end
      END

      expect(new_source).to eq(<<-END.strip_indent)
        blarg =
         if true
        end
      END
    end

    it 'ignores arrays' do
      inspect_source(cop, <<-END.strip_indent)
        a, b = 4,
        5
      END

      expect(cop.offenses).to be_empty
    end

    context 'configured supported types' do
      let(:supported_types) { %w[array] }

      it 'allows supported types to be configured' do
        inspect_source(cop, <<-END.strip_indent)
          a, b = 4,
          5
        END

        expect(cop.offenses.size).to eq(1)
        expect(cop.offenses.first.line).to eq(1)
        expect(cop.highlights).to eq(["a, b = 4,\n5"])
        expect(cop.messages).to eq([described_class::NEW_LINE_OFFENSE])
      end
    end

    it 'allows multi-line assignments on separate lines' do
      inspect_source(cop, <<-END.strip_indent)
        blarg=
        if true
        end
      END

      expect(cop.offenses).to be_empty
    end

    it 'registers an offense for masgn with multi-line lhs' do
      inspect_source(cop, <<-END.strip_indent)
        a,
        b = if foo
        end
      END

      expect(cop.offenses.size).to eq(1)
      expect(cop.offenses.first.line).to eq(1)
      expect(cop.highlights).to eq(["a,\nb = if foo\nend"])
      expect(cop.messages).to eq([described_class::NEW_LINE_OFFENSE])
    end
  end

  context 'same_line style' do
    let(:enforced_style) { 'same_line' }

    it 'registers an offense when the rhs is a different line' do
      inspect_source(cop, <<-END.strip_indent)
        blarg =
        if true
        end
      END

      expect(cop.offenses.size).to eq(1)
      expect(cop.offenses.first.line).to eq(1)
      expect(cop.highlights).to eq(["blarg =\nif true\nend"])
      expect(cop.messages).to eq([described_class::SAME_LINE_OFFENSE])
    end

    it 'auto-corrects offenses' do
      new_source = autocorrect_source(cop, <<-END.strip_indent)
        blarg =
        if true
        end
      END

      expect(new_source).to eq(<<-END.strip_indent)
        blarg = if true
        end
      END
    end

    it 'ignores arrays' do
      inspect_source(cop, <<-END.strip_indent)
        a, b =
        4,
        5
      END

      expect(cop.offenses).to be_empty
    end

    context 'configured supported types' do
      let(:supported_types) { %w[array] }

      it 'allows supported types to be configured' do
        inspect_source(cop, <<-END.strip_indent)
          a, b =
          4,
          5
        END

        expect(cop.offenses.size).to eq(1)
        expect(cop.offenses.first.line).to eq(1)
        expect(cop.highlights).to eq(["a, b =\n4,\n5"])
        expect(cop.messages).to eq([described_class::SAME_LINE_OFFENSE])
      end
    end

    it 'allows multi-line assignments on the same line' do
      inspect_source(cop, <<-END.strip_indent)
        blarg= if true
        end
      END

      expect(cop.offenses).to be_empty
    end

    it 'registers an offense for masgn with multi-line lhs' do
      inspect_source(cop, <<-END.strip_indent)
        a,
        b =
        if foo
        end
      END

      expect(cop.offenses.size).to eq(1)
      expect(cop.offenses.first.line).to eq(1)
      expect(cop.highlights).to eq(["a,\nb =\nif foo\nend"])
      expect(cop.messages).to eq([described_class::SAME_LINE_OFFENSE])
    end
  end
end
