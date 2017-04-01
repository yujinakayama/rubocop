# frozen_string_literal: true

describe RuboCop::Cop::Style::GuardClause, :config do
  let(:cop) { described_class.new(config) }
  let(:cop_config) { {} }

  shared_examples 'reports offense' do |body|
    it 'reports an offense if method body is if / unless without else' do
      inspect_source(cop,
                     ['def func',
                      '  if something',
                      "    #{body}",
                      '  end',
                      'end',
                      '',
                      'def func',
                      '  unless something',
                      "    #{body}",
                      '  end',
                      'end'])
      expect(cop.offenses.size).to eq(2)
      expect(cop.offenses.map(&:line).sort).to eq([2, 8])
      expect(cop.messages)
        .to eq(['Use a guard clause instead of wrapping ' \
                'the code inside a conditional expression.'] * 2)
      expect(cop.highlights).to eq(%w(if unless))
    end

    it 'reports an offense if method body is if / unless without else' do
      inspect_source(cop,
                     ['def func',
                      '  if something',
                      "    #{body}",
                      '  end',
                      'end',
                      '',
                      'def func',
                      '  unless something',
                      "    #{body}",
                      '  end',
                      'end'])
      expect(cop.offenses.size).to eq(2)
      expect(cop.offenses.map(&:line).sort).to eq([2, 8])
      expect(cop.messages)
        .to eq(['Use a guard clause instead of wrapping ' \
                'the code inside a conditional expression.'] * 2)
      expect(cop.highlights).to eq(%w(if unless))
    end

    it 'reports an offense if method body ends with if / unless without else' do
      inspect_source(cop,
                     ['def func',
                      '  test',
                      '  if something',
                      "    #{body}",
                      '  end',
                      'end',
                      '',
                      'def func',
                      '  test',
                      '  unless something',
                      "    #{body}",
                      '  end',
                      'end'])
      expect(cop.offenses.size).to eq(2)
      expect(cop.offenses.map(&:line).sort).to eq([3, 10])
      expect(cop.messages)
        .to eq(['Use a guard clause instead of wrapping ' \
                'the code inside a conditional expression.'] * 2)
      expect(cop.highlights).to eq(%w(if unless))
    end
  end

  it_behaves_like('reports offense', 'work')
  it_behaves_like('reports offense', '# TODO')

  it 'does not report an offense if body is if..elsif..end' do
    inspect_source(cop, <<-END.strip_indent)
      def func
        if something
          a
        elsif something_else
          b
        end
      end
    END
    expect(cop.offenses).to be_empty
  end

  it "doesn't report an offense if condition has multiple lines" do
    inspect_source(cop, <<-END.strip_indent)
      def func
        if something &&
             something_else
          work
        end
      end

      def func
        unless something &&
                 something_else
          work
        end
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'accepts a method which body is if / unless with else' do
    inspect_source(cop, <<-END.strip_indent)
      def func
        if something
          work
        else
          test
        end
      end

      def func
        unless something
          work
        else
          test
        end
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'accepts a method which body does not end with if / unless' do
    inspect_source(cop, <<-END.strip_indent)
      def func
        if something
          work
        end
        test
      end

      def func
        unless something
          work
        end
        test
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'accepts a method whose body is a modifier if / unless' do
    inspect_source(cop, <<-END.strip_indent)
      def func
        work if something
      end

      def func
        work if something
      end
    END
    expect(cop.offenses).to be_empty
  end

  context 'MinBodyLength: 1' do
    let(:cop_config) do
      { 'MinBodyLength' => 1 }
    end

    it 'reports an offense for if whose body has 1 line' do
      inspect_source(cop, <<-END.strip_indent)
        def func
          if something
            work
          end
        end

        def func
          unless something
            work
          end
        end
      END
      expect(cop.offenses.size).to eq(2)
      expect(cop.offenses.map(&:line).sort).to eq([2, 8])
      expect(cop.messages)
        .to eq(['Use a guard clause instead of wrapping ' \
                'the code inside a conditional expression.'] * 2)
      expect(cop.highlights).to eq(%w(if unless))
    end
  end

  context 'MinBodyLength: 4' do
    let(:cop_config) do
      { 'MinBodyLength' => 4 }
    end

    it 'accepts a method whose body has 3 lines' do
      inspect_source(cop, <<-END.strip_indent)
        def func
          if something
            work
            work
            work
          end
        end

        def func
          unless something
            work
            work
            work
          end
        end
      END
      expect(cop.offenses).to be_empty
    end
  end

  context 'Invalid MinBodyLength' do
    let(:cop_config) do
      { 'MinBodyLength' => -2 }
    end

    it 'fails with an error' do
      source = <<-END.strip_indent
        def func
          if something
            work
          end
        end
      END

      expect { inspect_source(cop, source) }
        .to raise_error('MinBodyLength needs to be a positive integer!')
    end
  end

  shared_examples 'on if nodes which exit current scope' do |kw|
    it "registers an error with #{kw} in the if branch" do
      inspect_source(cop, ['if something',
                           "  #{kw}",
                           'else',
                           '  puts "hello"',
                           'end'])
      expect(cop.offenses.size).to eq(1)
      expect(cop.messages).to eq(['Use a guard clause instead of wrapping ' \
                                  'the code inside a conditional expression.'])
    end

    it "registers an error with #{kw} in the else branch" do
      inspect_source(cop, ['if something',
                           ' puts "hello"',
                           'else',
                           "  #{kw}",
                           'end'])
      expect(cop.offenses.size).to eq(1)
      expect(cop.messages).to eq(['Use a guard clause instead of wrapping ' \
                                  'the code inside a conditional expression.'])
    end

    it "doesn't register an error if condition has multiple lines" do
      inspect_source(cop, ['if something &&',
                           '     something_else',
                           "  #{kw}",
                           'else',
                           '  puts "hello"',
                           'end'])
      expect(cop.offenses).to be_empty
    end

    it "does not report an offense if #{kw} is inside elsif" do
      inspect_source(cop,
                     ['if something',
                      '  a',
                      'elsif something_else',
                      "  #{kw}",
                      'end'])
      expect(cop.offenses).to be_empty
    end

    it "does not report an offense if #{kw} is inside if..elsif..else..end" do
      inspect_source(cop,
                     ['if something',
                      '  a',
                      'elsif something_else',
                      '  b',
                      'else',
                      "  #{kw}",
                      'end'])
      expect(cop.offenses).to be_empty
    end

    it "doesn't register an error if control flow expr has multiple lines" do
      inspect_source(cop, ['if something',
                           "  #{kw} 'blah blah blah' \\",
                           "        'blah blah blah'",
                           'else',
                           '  puts "hello"',
                           'end'])
      expect(cop.offenses).to be_empty
    end

    it 'registers an error if non-control-flow branch has multiple lines' do
      inspect_source(cop, ['if something',
                           "  #{kw}",
                           'else',
                           '  puts "hello" \\',
                           '       "blah blah blah"',
                           'end'])
      expect(cop.offenses.size).to eq(1)
    end
  end

  include_examples('on if nodes which exit current scope', 'return')
  include_examples('on if nodes which exit current scope', 'next')
  include_examples('on if nodes which exit current scope', 'break')
  include_examples('on if nodes which exit current scope', 'raise "error"')

  context 'method in module' do
    it 'registers an offense for instance method' do
      inspect_source(cop, <<-END.strip_indent)
        module CopTest
          def test
            if something
              work
            end
          end
        end
      END
      expect(cop.offenses.size).to eq(1)
    end

    it 'registers an offense for singleton methods' do
      inspect_source(cop, <<-END.strip_indent)
        module CopTest
          def self.test
            if something
              work
            end
          end
        end
      END
      expect(cop.offenses.size).to eq(1)
    end
  end
end
