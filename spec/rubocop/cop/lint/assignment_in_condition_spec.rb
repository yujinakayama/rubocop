# frozen_string_literal: true

describe RuboCop::Cop::Lint::AssignmentInCondition, :config do
  subject(:cop) { described_class.new(config) }
  let(:cop_config) { { 'AllowSafeAssignment' => true } }

  it 'registers an offense for lvar assignment in condition' do
    inspect_source(cop, <<-END.strip_indent)
      if test = 10
      end
    END
    expect(cop.offenses.size).to eq(1)
  end

  it 'registers an offense for lvar assignment in while condition' do
    inspect_source(cop, <<-END.strip_indent)
      while test = 10
      end
    END
    expect(cop.offenses.size).to eq(1)
  end

  it 'registers an offense for lvar assignment in until condition' do
    inspect_source(cop, <<-END.strip_indent)
      until test = 10
      end
    END
    expect(cop.offenses.size).to eq(1)
  end

  it 'registers an offense for ivar assignment in condition' do
    inspect_source(cop, <<-END.strip_indent)
      if @test = 10
      end
    END
    expect(cop.offenses.size).to eq(1)
  end

  it 'registers an offense for clvar assignment in condition' do
    inspect_source(cop, <<-END.strip_indent)
      if @@test = 10
      end
    END
    expect(cop.offenses.size).to eq(1)
  end

  it 'registers an offense for gvar assignment in condition' do
    inspect_source(cop, <<-END.strip_indent)
      if $test = 10
      end
    END
    expect(cop.offenses.size).to eq(1)
  end

  it 'registers an offense for constant assignment in condition' do
    inspect_source(cop, <<-END.strip_indent)
      if TEST = 10
      end
    END
    expect(cop.offenses.size).to eq(1)
  end

  it 'registers an offense for collection element assignment in condition' do
    inspect_source(cop, <<-END.strip_indent)
      if a[3] = 10
      end
    END
    expect(cop.offenses.size).to eq(1)
  end

  it 'accepts == in condition' do
    inspect_source(cop, <<-END.strip_indent)
      if test == 10
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'registers an offense for assignment after == in condition' do
    inspect_source(cop, <<-END.strip_indent)
      if test == 10 || foobar = 1
      end
    END
    expect(cop.offenses.size).to eq(1)
  end

  it 'accepts = in a block that is called in a condition' do
    inspect_source(cop,
                   'return 1 if any_errors? { o = inspect(file) }')
    expect(cop.offenses).to be_empty
  end

  it 'accepts = in a block followed by method call' do
    inspect_source(cop,
                   'return 1 if any_errors? { o = file }.present?')
    expect(cop.offenses).to be_empty
  end

  it 'accepts ||= in condition' do
    inspect_source(cop,
                   'raise StandardError unless foo ||= bar')
    expect(cop.offenses).to be_empty
  end

  it 'registers an offense for assignment after ||= in condition' do
    inspect_source(cop,
                   'raise StandardError unless (foo ||= bar) || a = b')
    expect(cop.offenses.size).to eq(1)
  end

  it 'registers an offense for assignment methods' do
    inspect_source(cop, <<-END.strip_indent)
      if test.method = 10
      end
    END
    expect(cop.offenses.size).to eq(1)
  end

  it 'does not blow up for empty if condition' do
    inspect_source(cop, <<-END.strip_indent)
      if ()
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'does not blow up for empty unless condition' do
    inspect_source(cop, <<-END.strip_indent)
      unless ()
      end
    END
    expect(cop.offenses).to be_empty
  end

  context 'safe assignment is allowed' do
    it 'accepts = in condition surrounded with braces' do
      inspect_source(cop, <<-END.strip_indent)
        if (test = 10)
        end
      END
      expect(cop.offenses).to be_empty
    end

    it 'accepts []= in condition surrounded with braces' do
      inspect_source(cop, <<-END.strip_indent)
        if (test[0] = 10)
        end
      END
      expect(cop.offenses).to be_empty
    end
  end

  context 'safe assignment is not allowed' do
    let(:cop_config) { { 'AllowSafeAssignment' => false } }

    it 'does not accept = in condition surrounded with braces' do
      inspect_source(cop, <<-END.strip_indent)
        if (test = 10)
        end
      END
      expect(cop.offenses.size).to eq(1)
    end

    it 'does not accept []= in condition surrounded with braces' do
      inspect_source(cop, <<-END.strip_indent)
        if (test[0] = 10)
        end
      END
      expect(cop.offenses.size).to eq(1)
    end
  end
end
