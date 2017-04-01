# frozen_string_literal: true

describe RuboCop::Cop::Style::MultilineIfThen do
  subject(:cop) { described_class.new }

  # if

  it 'does not get confused by empty elsif branch' do
    inspect_source(cop, <<-END.strip_indent)
      if cond
      elsif cond
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'registers an offense for then in multiline if' do
    inspect_source(cop, <<-END.strip_indent)
      if cond then
      end
      if cond then\t
      end
      if cond then
      end
      if cond
      then
      end
      if cond then # bad
      end
    END
    expect(cop.offenses.map(&:line)).to eq([1, 3, 5, 8, 10])
    expect(cop.highlights).to eq(['then'] * 5)
    expect(cop.messages).to eq(['Do not use `then` for multi-line `if`.'] * 5)
  end

  it 'registers an offense for then in multiline elsif' do
    inspect_source(cop, <<-END.strip_indent)
      if cond1
        a
      elsif cond2 then
        b
      end
    END
    expect(cop.offenses.map(&:line)).to eq([3])
    expect(cop.highlights).to eq(['then'])
    expect(cop.messages).to eq(['Do not use `then` for multi-line `elsif`.'])
  end

  it 'accepts multiline if without then' do
    inspect_source(cop, <<-END.strip_indent)
      if cond
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'accepts table style if/then/elsif/ends' do
    inspect_source(cop, <<-END.strip_indent)
      if    @io == $stdout then str << "$stdout"
      elsif @io == $stdin  then str << "$stdin"
      elsif @io == $stderr then str << "$stderr"
      else                      str << @io.class.to_s
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'does not get confused by a then in a when' do
    inspect_source(cop, <<-END.strip_indent)
      if a
        case b
        when c then
        end
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'does not get confused by a commented-out then' do
    inspect_source(cop, <<-END.strip_indent)
      if a # then
        b
      end
      if c # then
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'does not raise an error for an implicit match if' do
    expect do
      inspect_source(cop, <<-END.strip_indent)
        if //
        end
      END
    end.not_to raise_error
  end

  # unless

  it 'registers an offense for then in multiline unless' do
    inspect_source(cop, <<-END.strip_indent)
      unless cond then
      end
    END
    expect(cop.messages).to eq(
      ['Do not use `then` for multi-line `unless`.']
    )
  end

  it 'accepts multiline unless without then' do
    inspect_source(cop, <<-END.strip_indent)
      unless cond
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'does not get confused by a postfix unless' do
    inspect_source(cop, 'two unless one')
    expect(cop.offenses).to be_empty
  end

  it 'does not get confused by a nested postfix unless' do
    inspect_source(cop, <<-END.strip_indent)
      if two
        puts 1
      end unless two
    END
    expect(cop.offenses).to be_empty
  end

  it 'does not raise an error for an implicit match unless' do
    expect do
      inspect_source(cop, <<-END.strip_indent)
        unless //
        end
      END
    end.not_to raise_error
  end

  it 'auto-corrects the usage of "then" in multiline if' do
    new_source = autocorrect_source(cop, <<-END.strip_indent)
      if cond then
        something
      end
    END
    expect(new_source).to eq(<<-END.strip_indent)
      if cond
        something
      end
    END
  end
end
