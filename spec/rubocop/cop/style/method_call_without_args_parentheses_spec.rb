# frozen_string_literal: true

describe RuboCop::Cop::Style::MethodCallWithoutArgsParentheses do
  subject(:cop) { described_class.new }

  it 'registers an offense for parens in method call without args' do
    inspect_source(cop, 'top.test()')
    expect(cop.offenses.size).to eq(1)
  end

  it 'accepts parentheses for methods starting with an upcase letter' do
    inspect_source(cop, 'Test()')
    expect(cop.offenses).to be_empty
  end

  it 'accepts no parens in method call without args' do
    inspect_source(cop, 'top.test')
    expect(cop.offenses).to be_empty
  end

  it 'accepts parens in method call with args' do
    inspect_source(cop, 'top.test(a)')
    expect(cop.offenses).to be_empty
  end

  it 'accepts special lambda call syntax' do
    # Style/LambdaCall checks for this syntax
    inspect_source(cop, 'thing.()')
    expect(cop.offenses).to be_empty
  end

  it 'accepts parens after not' do
    inspect_source(cop, 'not(something)')
    expect(cop.offenses).to be_empty
  end

  context 'assignment to a variable with the same name' do
    it 'accepts parens in local variable assignment ' do
      inspect_source(cop, 'test = test()')
      expect(cop.offenses).to be_empty
    end

    it 'accepts parens in shorthand assignment' do
      inspect_source(cop, 'test ||= test()')
      expect(cop.offenses).to be_empty
    end

    it 'accepts parens in parallel assignment' do
      inspect_source(cop, 'one, test = 1, test()')
      expect(cop.offenses).to be_empty
    end

    it 'accepts parens in complex assignment' do
      inspect_source(cop, <<-END.strip_indent)
        test = begin
          case a
          when b
            c = test() if d
          end
        end
      END
      expect(cop.offenses).to be_empty
    end
  end

  it 'registers an offense for `obj.method ||= func()`' do
    inspect_source(cop, 'obj.method ||= func()')
    expect(cop.offenses.size).to eq 1
  end

  it 'registers an offense for `obj.method &&= func()`' do
    inspect_source(cop, 'obj.method &&= func()')
    expect(cop.offenses.size).to eq 1
  end

  it 'registers an offense for `obj.method += func()`' do
    inspect_source(cop, 'obj.method += func()')
    expect(cop.offenses.size).to eq 1
  end

  it 'auto-corrects by removing unneeded braces' do
    new_source = autocorrect_source(cop, 'test()')
    expect(new_source).to eq('test')
  end

  # These will be offenses for the EmptyLiteral cop. The autocorrect loop will
  # handle that.
  it 'auto-corrects calls that could be empty literals' do
    original = <<-END.strip_indent
      Hash.new()
      Array.new()
      String.new()
    END
    new_source = autocorrect_source(cop, original)
    expect(new_source).to eq(<<-END.strip_indent)
      Hash.new
      Array.new
      String.new
    END
  end

  context 'method call as argument' do
    it 'accepts without parens' do
      inspect_source(cop, '_a = c(d.e)')
      expect(cop.offenses).to be_empty
    end

    it 'registers an offense with empty parens' do
      inspect_source(cop, '_a = c(d())')
      expect(cop.offenses.size).to eq 1
    end

    it 'registers an empty parens offense for multiple assignment' do
      inspect_source(cop, '_a, _b, _c = d(e())')
      expect(cop.offenses.size).to eq 1
    end
  end
end
