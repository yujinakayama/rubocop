# frozen_string_literal: true

describe RuboCop::Cop::Style::SpaceInsideArrayPercentLiteral do
  subject(:cop) { described_class.new }

  %w[i I w W].each do |type|
    [%w[{ }], %w[( )], %w([ ]), %w[! !]].each do |(ldelim, rdelim)|
      context "for #{type} type and #{[ldelim, rdelim]} delimiters" do
        define_method(:code_example) do |content|
          ['%', type, ldelim, content, rdelim].join
        end

        def expect_corrected(source, expected)
          expect(autocorrect_source(cop, source)).to eq expected
        end

        it 'registers an offense for unnecessary spaces' do
          source = code_example('1   2')
          inspect_source(cop, source)
          expect(cop.offenses.size).to eq(1)
          expect(cop.highlights).to eq(['   '])
          expect(cop.messages).to eq([described_class::MSG])
          expect_corrected(source, code_example('1 2'))
        end

        it 'registers an offense for multiple spaces between items' do
          source = code_example('1   2   3')
          inspect_source(cop, source)
          expect(cop.offenses.size).to eq(2)
          expect_corrected(source, code_example('1 2 3'))
        end

        it 'accepts literals with escaped and additional spaces' do
          source = code_example('a\   b \ c')
          inspect_source(cop, source)
          expect(cop.offenses.size).to eq(1)
          expect_corrected(source, code_example('a\  b \ c'))
        end

        it 'accepts literals without additional spaces' do
          inspect_source(cop, code_example('a b c'))
          expect(cop.messages).to be_empty
        end

        it 'accepts literals with escaped spaces' do
          inspect_source(cop, code_example('a\  b\ \  c'))
          expect(cop.messages).to be_empty
        end

        it 'accepts multi-line literals' do
          inspect_source(cop, <<-END.strip_indent)
            %#{type}(
              a
              b
              c
            )
          END
          expect(cop.messages).to be_empty
        end

        it 'accepts multi-line literals within a method' do
          inspect_source(cop, <<-END.strip_indent)
            def foo
              %#{type}(
                a
                b
                c
              )
            end
          END
          expect(cop.messages).to be_empty
        end

        it 'accepts newlines and additional following alignment spaces' do
          inspect_source(cop, <<-END.strip_indent)
            %#{type}(a b
               c)
          END
          expect(cop.messages).to be_empty
        end
      end
    end
  end

  it 'accepts non array percent literals' do
    inspect_source(cop, '%q( a  b c )')
    expect(cop.messages).to be_empty
  end
end
