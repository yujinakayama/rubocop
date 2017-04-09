# frozen_string_literal: true

describe RuboCop::Cop::Style::RaiseArgs, :config do
  subject(:cop) { described_class.new(config) }

  context 'when enforced style is compact' do
    let(:cop_config) { { 'EnforcedStyle' => 'compact' } }

    context 'with a raise with 2 args' do
      it 'reports an offense' do
        inspect_source(cop, 'raise RuntimeError, msg')
        expect(cop.offenses.size).to eq(1)
        expect(cop.config_to_allow_offenses)
          .to eq('EnforcedStyle' => 'exploded')
      end

      it 'auto-corrects to compact style' do
        new_source = autocorrect_source(cop, 'raise RuntimeError, msg')
        expect(new_source).to eq('raise RuntimeError.new(msg)')
      end
    end

    context 'with correct + opposite' do
      it 'reports an offense' do
        inspect_source(cop, <<-END.strip_indent)
          if a
            raise RuntimeError, msg
          else
            raise Ex.new(msg)
          end
        END
        expect(cop.offenses.size).to eq(1)
        expect(cop.messages)
          .to eq(['Provide an exception object as an argument to `raise`.'])
        expect(cop.config_to_allow_offenses).to eq('Enabled' => false)
      end

      it 'auto-corrects to compact style' do
        new_source = autocorrect_source(cop, <<-END.strip_indent)
          if a
            raise RuntimeError, msg
          else
            raise Ex.new(msg)
          end
        END
        expect(new_source).to eq(<<-END.strip_indent)
          if a
            raise RuntimeError.new(msg)
          else
            raise Ex.new(msg)
          end
        END
      end
    end

    context 'with a raise with 3 args' do
      it 'reports an offense' do
        inspect_source(cop, 'raise RuntimeError, msg, caller')
        expect(cop.offenses.size).to eq(1)
      end

      it 'auto-corrects to compact style' do
        new_source = autocorrect_source(cop,
                                        ['raise RuntimeError, msg, caller'])
        expect(new_source).to eq('raise RuntimeError.new(msg, caller)')
      end
    end

    it 'accepts a raise with msg argument' do
      inspect_source(cop, 'raise msg')
      expect(cop.offenses).to be_empty
    end

    it 'accepts a raise with an exception argument' do
      inspect_source(cop, 'raise Ex.new(msg)')
      expect(cop.offenses).to be_empty
    end
  end

  context 'when enforced style is exploded' do
    let(:cop_config) { { 'EnforcedStyle' => 'exploded' } }

    context 'with a raise with exception object' do
      context 'with one argument' do
        it 'reports an offense' do
          inspect_source(cop, 'raise Ex.new(msg)')
          expect(cop.offenses.size).to eq(1)
          expect(cop.messages)
            .to eq(['Provide an exception class and message ' \
                    'as arguments to `raise`.'])
          expect(cop.config_to_allow_offenses)
            .to eq('EnforcedStyle' => 'compact')
        end

        it 'auto-corrects to exploded style' do
          new_source = autocorrect_source(cop, ['raise Ex.new(msg)'])
          expect(new_source).to eq('raise Ex, msg')
        end
      end

      context 'with no arguments' do
        it 'reports an offense' do
          inspect_source(cop, 'raise Ex.new')
          expect(cop.offenses.size).to eq(1)
          expect(cop.messages)
            .to eq(['Provide an exception class and message ' \
                    'as arguments to `raise`.'])
          expect(cop.config_to_allow_offenses)
            .to eq('EnforcedStyle' => 'compact')
        end

        it 'auto-corrects to exploded style' do
          new_source = autocorrect_source(cop, ['raise Ex.new'])
          expect(new_source).to eq('raise Ex')
        end
      end
    end

    context 'with opposite + correct' do
      it 'reports an offense for opposite + correct' do
        inspect_source(cop, <<-END.strip_indent)
          if a
            raise RuntimeError, msg
          else
            raise Ex.new(msg)
          end
        END
        expect(cop.offenses.size).to eq(1)
        expect(cop.config_to_allow_offenses).to eq('Enabled' => false)
      end

      it 'auto-corrects to exploded style' do
        new_source = autocorrect_source(cop, <<-END.strip_indent)
          if a
            raise RuntimeError, msg
          else
            raise Ex.new(msg)
          end
        END
        expect(new_source).to eq(<<-END.strip_indent)
          if a
            raise RuntimeError, msg
          else
            raise Ex, msg
          end
        END
      end
    end

    it 'accepts exception constructor with more than 1 argument' do
      inspect_source(cop, 'raise MyCustomError.new(a1, a2, a3)')
      expect(cop.offenses).to be_empty
    end

    it 'accepts exception constructor with keyword arguments' do
      inspect_source(cop, 'raise MyKwArgError.new(a: 1, b: 2)')
      expect(cop.offenses).to be_empty
    end

    it 'accepts a raise with splatted arguments' do
      inspect_source(cop, 'raise MyCustomError.new(*args)')
      expect(cop.offenses).to be_empty
    end

    it 'accepts a raise with 3 args' do
      inspect_source(cop, 'raise RuntimeError, msg, caller')
      expect(cop.offenses).to be_empty
    end

    it 'accepts a raise with 2 args' do
      inspect_source(cop, 'raise RuntimeError, msg')
      expect(cop.offenses).to be_empty
    end

    it 'accepts a raise with msg argument' do
      inspect_source(cop, 'raise msg')
      expect(cop.offenses).to be_empty
    end
  end
end
