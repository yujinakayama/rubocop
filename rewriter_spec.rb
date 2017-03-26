require './rewriter'

describe SourceRewriter do
  subject(:rewriter) do
    SourceRewriter.new(processed_source).rewrite
  end

  let(:processed_source) do
    RuboCop::ProcessedSource.new(source, 2.4)
  end

  context 'with emacs style as an argument' do
    let(:source) { <<-SOURCE }
      begin
        do_something(['foo',
                      'bar',
                      'baz'])
      end
    SOURCE

    let(:rewritten_source) { <<-SOURCE }
      begin
        do_something(<<-END.strip_indent)
          foo
          bar
          baz
        END
      end
    SOURCE

    it { should eq rewritten_source }
  end

  context 'with emacs style as an argument with linefeed' do
    let(:source) { <<-SOURCE }
      begin
        do_something(some_arg,
                     ['foo',
                      'bar',
                      'baz'])
      end
    SOURCE

    let(:rewritten_source) { <<-SOURCE }
      begin
        do_something(some_arg, <<-END.strip_indent)
          foo
          bar
          baz
        END
      end
    SOURCE

    it { should eq rewritten_source }
  end

  context 'with emacs style with #join as an argument' do
    let(:source) { <<-SOURCE }
      begin
        do_something(['foo',
                      'bar',
                      'baz'].join(''))
      end
    SOURCE

    let(:rewritten_source) { <<-SOURCE }
      begin
        do_something(<<-END.strip_indent)
          foo
          bar
          baz
        END
      end
    SOURCE

    it { should eq rewritten_source }
  end

  context 'with emacs style' do
    let(:source) { <<-SOURCE }
      ['foo',
       'bar',
       'baz']
    SOURCE

    let(:rewritten_source) { <<-SOURCE }
      <<-END.strip_indent
        foo
        bar
        baz
      END
    SOURCE

    it { should eq rewritten_source }
  end

  context 'with emacs style with #join' do
    let(:source) { <<-SOURCE }
      ['foo',
       'bar',
       'baz'].join('')
    SOURCE

    let(:rewritten_source) { <<-SOURCE }
      <<-END.strip_indent
        foo
        bar
        baz
      END
    SOURCE

    it { should eq rewritten_source }
  end

  context 'with consistent style as an argument' do
    let(:source) { <<-SOURCE }
      begin
        do_something([
          'foo',
          'bar',
          'baz'
        ])
      end
    SOURCE

    let(:rewritten_source) { <<-SOURCE }
      begin
        do_something(<<-END.strip_indent)
          foo
          bar
          baz
        END
      end
    SOURCE

    it { should eq rewritten_source }
  end

  context 'with consistent style as an argument with indentation' do
    let(:source) { <<-SOURCE }
      begin
        do_something(some_arg, [
                       'foo',
                       'bar',
                       'baz'
                     ])
      end
    SOURCE

    let(:rewritten_source) { <<-SOURCE }
      begin
        do_something(some_arg, <<-END.strip_indent)
          foo
          bar
          baz
        END
      end
    SOURCE

    it { should eq rewritten_source }
  end

  context 'with consistent style with #join as an argument' do
    let(:source) { <<-SOURCE }
      begin
        do_something([
          'foo',
          'bar',
          'baz'
        ].join(''))
      end
    SOURCE

    let(:rewritten_source) { <<-SOURCE }
      begin
        do_something(<<-END.strip_indent)
          foo
          bar
          baz
        END
      end
    SOURCE

    it { should eq rewritten_source }
  end

  context 'with consistent style' do
    let(:source) { <<-SOURCE }
      [
        'foo',
        'bar',
        'baz'
      ]
    SOURCE

    let(:rewritten_source) { <<-SOURCE }
      <<-END.strip_indent
        foo
        bar
        baz
      END
    SOURCE

    it { should eq rewritten_source }
  end

  context 'with option array' do
    let(:source) { <<-SOURCE }
      expect(cli.run(['--format',
                      'emacs',
                      '--debug',
                      'example1.rb'])).to eq(1)
    SOURCE

    it { should eq source }
  end

  context 'with option array' do
    let(:source) { <<-SOURCE }
      new_source = autocorrect_source(
        cop,
        ['variable =',
         '  a_long_method_that_dont_fit_on_the_line do |v|',
         '    v.foo',
         'end']
      )
    SOURCE

    let(:rewritten_source) { <<-SOURCE }
      new_source = autocorrect_source(
        cop,
        <<-END.strip_indent
          variable =
            a_long_method_that_dont_fit_on_the_line do |v|
              v.foo
          end
        END
      )
    SOURCE

    it { should eq rewritten_source }
  end

  context 'when part of parent array' do
    let(:source) { <<-SOURCE }
      [
        ['ordinary method chain', 'x.foo.bar.baz'],
        ['ordinary method chain with argument', 'x.foo(x).bar(y).baz(z)'],
        ['method chain with safe navigation only', 'x&.foo&.bar&.baz'],
        ['method chain with safe navigation only with argument',
         'x&.foo(x)&.bar(y)&.baz(z)'],
        ['safe navigation at last only', 'x.foo.bar&.baz'],
        ['safe navigation at last only with argument', 'x.foo(x).bar(y)&.baz(z)'],
        ['safe navigation with == operator', 'x&.foo == bar'],
        ['safe navigation with === operator', 'x&.foo === bar'],
        ['safe navigation with || operator', 'x&.foo || bar'],
        ['safe navigation with && operator', 'x&.foo && bar'],
        ['safe navigation with | operator', 'x&.foo | bar'],
        ['safe navigation with & operator', 'x&.foo & bar'],
        ['safe navigation with `nil?` method', 'x&.foo.nil?'],
        ['safe navigation with `present?` method', 'x&.foo.present?'],
        ['safe navigation with `blank?` method', 'x&.foo.blank?'],
        ['safe navigation with `try` method', 'a&.b.try(:c)'],
        ['safe navigation with assignment method', 'x&.foo = bar'],
        ['safe navigation with self assignment method', 'x&.foo += bar']
      ]
    SOURCE

    it { should eq source }
  end

  context 'with string literal include #{}' do
    let(:source) { <<-'SOURCE' }
      [
        'foo#{obj}bar',
        'foo'
      ]
    SOURCE

    let(:rewritten_source) { <<-'SOURCE' }
      <<-'END'.strip_indent
        foo#{obj}bar
        foo
      END
    SOURCE

    it { should eq rewritten_source }
  end

  context 'with multiline chain' do
    let(:source) { <<-'SOURCE' }
      expect(corrected).to eq(['class Test',
                               '  def self.foo',
                               '    true',
                               '  end',
                               '',
                               '  def self.bar',
                               '    true',
                               '  end',
                               'end']
                               .join("\n"))
    SOURCE

    let(:rewritten_source) { <<-'SOURCE' }
      expect(corrected).to eq(<<-END.strip_indent)
        class Test
          def self.foo
            true
          end

          def self.bar
            true
          end
        end
      END
    SOURCE

    it { should eq rewritten_source }
  end

  context 'with string literal include #{}' do
    let(:source) { <<-SOURCE }
      expect(cop.messages)
        .to eq(['Unnecessary disabling of `Metrics/MethodLength`.',
                'Unnecessary disabling of `Lint/Debugger`.',
                'Unnecessary disabling of `Lint/AmbiguousOperator`.'])
    SOURCE

    it { should eq source }
  end

  context 'with indented source' do
    let(:source) { <<-'SOURCE' }
      expect(corrected).to eq ['  def some_method arg;',
                               '    body',
                               '  end'].join("\n")
    SOURCE

    let(:rewritten_source) { <<-'SOURCE' }
      expect(corrected).to eq <<-END.strip_margin('|')
        |  def some_method arg;
        |    body
        |  end
      END
    SOURCE

    it { should eq rewritten_source }
  end

  context 'with trailing whitespace' do
    let(:source) { <<-'SOURCE' }
      expect(corrected).to eq ['  def some_method arg; ',
                               '    body ',
                               '  end'].join("\n")
    SOURCE

    it { should eq source }
  end

  context 'with trailing linefeed' do
    let(:source) { <<-'SOURCE' }
      expect($stdout.string)
        .to eq(['== example.rb ==',
                '',
                '1 file inspected, 1 offense detected',
                ''].join("\n"))
    SOURCE

    let(:rewritten_source) { <<-'SOURCE' }
      expect($stdout.string)
        .to eq(<<-END.strip_indent)
          == example.rb ==

          1 file inspected, 1 offense detected
        END
    SOURCE

    it { should eq rewritten_source }
  end

  context 'with trailing escape' do
    let(:source) { <<-'SOURCE' }
      corrected = ["puts 'foo' \\",
                   '     "#{bar}"',
                   "puts 'a' \\",
                   "     'b'",
                   'c.to_s',
                   '']
    SOURCE

    it { should eq source }
  end

  context 'with unhandled escape' do
    let(:source) { <<-'SOURCE' }
      source = ['  render_views',
                "    describe 'GET index' do",
                "\t    it 'returns http success' do",
                "\t    end",
                "\tdescribe 'admin user' do",
                '     before(:each) do',
                "\t    end",
                "\tend",
                '    end',
                '']
    SOURCE

    let(:rewritten_source) { <<-'SOURCE' }
      source = <<-END.strip_indent
          render_views
            describe 'GET index' do
        \t    it 'returns http success' do
        \t    end
        \tdescribe 'admin user' do
             before(:each) do
        \t    end
        \tend
            end
      END
    SOURCE

    it { should eq rewritten_source }
  end
end
