# frozen_string_literal: true

describe RuboCop::Cop::Style::MixinGrouping, :config do
  subject(:cop) { described_class.new(config) }

  before do
    inspect_source(cop, source)
  end

  shared_examples 'code with offense' do |code, expected|
    context "when checking #{code}" do
      let(:source) { code }

      it 'registers an offense' do
        expect(cop.offenses.size).to eq(offenses)
        expect(cop.messages).to eq([message] * offenses)
      end

      if expected
        it 'auto-corrects' do
          expect(autocorrect_source(cop, code)).to eq(expected)
        end
      else
        it 'does not auto-correct' do
          expect(autocorrect_source(cop, code)).to eq(code)
        end
      end
    end
  end

  shared_examples 'code without offense' do |code|
    let(:source) { code }

    it 'does not register an offense' do
      expect(cop.offenses).to be_empty
    end
  end

  context 'when configured with separated style' do
    let(:cop_config) { { 'EnforcedStyle' => 'separated' } }

    let(:offenses) { 1 }

    context 'when using `include`' do
      let(:message) { 'Put `include` mixins in separate statements.' }

      context 'with several mixins in one call' do
        it_behaves_like 'code with offense', <<-END.strip_indent
          class Foo
            include Bar, Qux
          end
        END
      end

      context 'with several mixins in separate calls' do
        it_behaves_like 'code without offense', <<-END.strip_indent
          class Foo
            include Bar
            include Qux
          end
        END
      end

      context 'when include call is an argument to another method' do
        it_behaves_like 'code without offense',
                        'expect(foo).to include(bar, baz)'
      end
    end

    context 'when using `extend`' do
      let(:message) { 'Put `extend` mixins in separate statements.' }

      context 'with several mixins in one call' do
        it_behaves_like 'code with offense', <<-END.strip_indent
          class Foo
            extend Bar, Qux
          end
        END
      end

      context 'with several mixins in separate calls' do
        it_behaves_like 'code without offense', <<-END.strip_indent
          class Foo
            extend Bar
            extend Qux
          end
        END
      end
    end

    context 'when using `prepend`' do
      let(:message) { 'Put `prepend` mixins in separate statements.' }

      context 'with several mixins in one call' do
        it_behaves_like 'code with offense', <<-END.strip_indent
          class Foo
            prepend Bar, Qux
          end
        END
      end

      context 'with several mixins in separate calls' do
        it_behaves_like 'code without offense', <<-END.strip_indent
          class Foo
            prepend Bar
            prepend Qux
          end
        END
      end
    end

    context 'when using a mix of diffent methods' do
      context 'with some calls having several mixins' do
        let(:message) { 'Put `include` mixins in separate statements.' }

        it_behaves_like 'code with offense', <<-END.strip_indent
          class Foo
            include Bar, Baz
            extend Qux
          end
        END
      end

      context 'with all calls having one mixin' do
        it_behaves_like 'code without offense', <<-END.strip_indent
          class Foo
            include Bar
            prepend Baz
            extend Baz
          end
        END
      end
    end
  end

  context 'when configured with grouped style' do
    let(:cop_config) { { 'EnforcedStyle' => 'grouped' } }

    context 'when using include' do
      context 'with several mixins in one call' do
        let(:offenses) { 3 }
        let(:message) { 'Put `include` mixins in a single statement.' }

        it_behaves_like 'code with offense', <<-END.strip_indent
          class Foo
            include Bar
            include Baz
            include Qux
          end
        END
      end

      context 'with several mixins in separate calls' do
        it_behaves_like 'code without offense', <<-END.strip_indent
          class Foo
            include Bar, Qux
          end
        END
      end

      context 'when include has an explicit receiver' do
        it_behaves_like 'code without offense', <<-END.strip_indent
          config.include Foo
          config.include Bar
        END
      end
    end

    context 'when using `extend`' do
      context 'with several mixins in one call' do
        let(:offenses) { 2 }
        let(:message) { 'Put `extend` mixins in a single statement.' }

        it_behaves_like 'code with offense', <<-END.strip_indent
          class Foo
            extend Bar
            extend Baz
          end
        END
      end

      context 'with several mixins in separate calls' do
        it_behaves_like 'code without offense', <<-END.strip_indent
          class Foo
            extend Bar, Qux
          end
        END
      end
    end

    context 'when using `prepend`' do
      context 'with several mixins in one call' do
        let(:offenses) { 2 }
        let(:message) { 'Put `prepend` mixins in a single statement.' }

        it_behaves_like 'code with offense', <<-END.strip_indent
          class Foo
            prepend Bar
            prepend Baz
          end
        END
      end

      context 'with several mixins in separate calls' do
        it_behaves_like 'code without offense', <<-END.strip_indent
          class Foo
            prepend Bar, Qux
          end
        END
      end
    end

    context 'when using a mix of diffent methods' do
      context 'with some duplicated mixin methods' do
        let(:offenses) { 2 }
        let(:message) { 'Put `include` mixins in a single statement.' }

        it_behaves_like 'code with offense', <<-END.strip_indent
          class Foo
            include Bar
            include Baz
            extend Baz
          end
        END
      end

      context 'with all different mixin methods' do
        it_behaves_like 'code without offense', <<-END.strip_indent
          class Foo
            include Bar
            prepend Baz
            extend Baz
          end
        END
      end
    end
  end
end
