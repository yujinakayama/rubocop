# frozen_string_literal: true

describe RuboCop::Cop::Rails::Delegate do
  subject(:cop) { described_class.new }

  it 'finds trivial delegate' do
    inspect_source(cop, <<-END.strip_indent)
      def foo
        bar.foo
      end
    END
    expect(cop.offenses.size).to eq(1)
    expect(cop.offenses
            .map(&:line).sort).to eq([1])
    expect(cop.messages)
      .to eq(['Use `delegate` to define delegations.'])
    expect(cop.highlights).to eq(['def'])
  end

  it 'finds trivial delegate with arguments' do
    inspect_source(cop, <<-END.strip_indent)
      def foo(baz)
        bar.foo(baz)
      end
    END
    expect(cop.offenses.size).to eq(1)
    expect(cop.offenses
            .map(&:line).sort).to eq([1])
    expect(cop.messages)
      .to eq(['Use `delegate` to define delegations.'])
    expect(cop.highlights).to eq(['def'])
  end

  it 'finds trivial delegate with prefix' do
    inspect_source(cop, <<-END.strip_indent)
      def bar_foo
        bar.foo
      end
    END
    expect(cop.offenses.size).to eq(1)
    expect(cop.offenses
            .map(&:line).sort).to eq([1])
    expect(cop.messages)
      .to eq(['Use `delegate` to define delegations.'])
    expect(cop.highlights).to eq(['def'])
  end

  it 'ignores class methods' do
    inspect_source(cop, <<-END.strip_indent)
      def self.fox
        new.fox
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'ignores non trivial delegate' do
    inspect_source(cop, <<-END.strip_indent)
      def fox
        bar.foo.fox
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'ignores trivial delegate with mismatched arguments' do
    inspect_source(cop, <<-END.strip_indent)
      def fox(baz)
        bar.fox(foo)
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'ignores trivial delegate with optional argument with a default value' do
    inspect_source(cop, <<-END.strip_indent)
      def fox(foo = nil)
        bar.fox(foo || 5)
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'ignores trivial delegate with mismatched number of arguments' do
    inspect_source(cop, <<-END.strip_indent)
      def fox(a, baz)
        bar.fox(a)
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'ignores trivial delegate with other prefix' do
    inspect_source(cop, <<-END.strip_indent)
      def fox_foo
        bar.foo
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'ignores methods with arguments' do
    inspect_source(cop, <<-END.strip_indent)
      def fox(bar)
        bar.fox
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'ignores private delegations' do
    inspect_source(cop, <<-END.strip_indent)
        private def fox # leading spaces are on purpose
          bar.fox
        end

          private

        def fox
          bar.fox
        end
    END
    expect(cop.offenses).to be_empty
  end

  it 'ignores protected delegations' do
    inspect_source(cop, <<-END.strip_indent)
        protected def fox # leading spaces are on purpose
          bar.fox
        end

        protected

        def fox
          bar.fox
        end
    END
    expect(cop.offenses).to be_empty
  end

  it 'ignores delegation with assignment' do
    inspect_source(cop, <<-END.strip_indent)
      def new
        @bar = Foo.new
      end
    END
    expect(cop.offenses).to be_empty
  end

  it 'ignores delegation to constant' do
    inspect_source(cop, <<-END.strip_indent)
      FOO = []
      def size
        FOO.size
      end
    END
    expect(cop.offenses).to be_empty
  end

  describe '#autocorrect' do
    context 'trivial delegation' do
      let(:source) do
        <<-END.strip_indent
          def bar
            foo.bar
          end
        END
      end

      let(:corrected_source) do
        <<-END.strip_indent
          delegate :bar, to: :foo
        END
      end

      it 'autocorrects' do
        expect(autocorrect_source(cop, source)).to eq(corrected_source)
      end
    end

    context 'trivial delegation with prefix' do
      let(:source) do
        <<-END.strip_indent
          def foo_bar
            foo.bar
          end
        END
      end

      let(:corrected_source) do
        <<-END.strip_indent
          delegate :bar, to: :foo, prefix: true
        END
      end

      it 'autocorrects' do
        expect(autocorrect_source(cop, source)).to eq(corrected_source)
      end
    end
  end
end
