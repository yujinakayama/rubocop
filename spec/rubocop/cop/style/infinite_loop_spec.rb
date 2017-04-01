# frozen_string_literal: true

describe RuboCop::Cop::Style::InfiniteLoop do
  subject(:cop) { described_class.new(config) }
  let(:config) do
    RuboCop::Config.new('Style/IndentationWidth' => { 'Width' => 2 })
  end

  %w(1 2.0 [1] {}).each do |lit|
    it "registers an offense for a while loop with #{lit} as condition" do
      inspect_source(cop,
                     ["while #{lit}",
                      '  top',
                      'end'])
      expect(cop.messages).to eq(['Use `Kernel#loop` for infinite loops.'])
      expect(cop.highlights).to eq(['while'])
    end
  end

  %w(false nil).each do |lit|
    it "registers an offense for a until loop with #{lit} as condition" do
      inspect_source(cop,
                     ["until #{lit}",
                      '  top',
                      'end'])
      expect(cop.messages).to eq(['Use `Kernel#loop` for infinite loops.'])
      expect(cop.highlights).to eq(['until'])
    end
  end

  it 'accepts Kernel#loop' do
    inspect_source(cop,
                   'loop { break if something }')
    expect(cop.offenses).to be_empty
  end

  shared_examples_for 'auto-corrector' do |keyword, lit|
    it "auto-corrects single line modifier #{keyword}" do
      new_source =
        autocorrect_source(cop, "something += 1 #{keyword} #{lit} # comment")
      expect(new_source).to eq('loop { something += 1 } # comment')
    end

    context 'with non-default indentation width' do
      let(:config) do
        RuboCop::Config.new('Style/IndentationWidth' => { 'Width' => 4 })
      end

      it "auto-corrects multi-line modifier #{keyword} and indents correctly" do
        new_source = autocorrect_source(cop, <<-END.strip_indent)
          # comment
          something 1, # comment 1
              # comment 2
              2 #{keyword} #{lit}
        END

        expect(new_source).to eq(<<-END.strip_indent)
          # comment
          loop do
              something 1, # comment 1
                  # comment 2
                  2
          end
        END
      end
    end

    it "auto-corrects begin-end-#{keyword} with one statement" do
      new_source = autocorrect_source(cop, <<-END.strip_indent)
        begin # comment 1
          something += 1 # comment 2
        end #{keyword} #{lit} # comment 3
      END

      expect(new_source).to eq(<<-END.strip_indent)
        loop do # comment 1
          something += 1 # comment 2
        end # comment 3
      END
    end

    it "auto-corrects begin-end-#{keyword} with two statements" do
      new_source = autocorrect_source(cop, <<-END.strip_indent)
        begin
         something += 1
         something_else += 1
        end #{keyword} #{lit}
      END

      expect(new_source).to eq(<<-END.strip_indent)
         loop do
          something += 1
          something_else += 1
         end
      END
    end

    it "auto-corrects single line modifier #{keyword} with and" do
      new_source =
        autocorrect_source(cop,
                           "something and something_else #{keyword} #{lit}")
      expect(new_source).to eq('loop { something and something_else }')
    end

    it "auto-corrects the usage of #{keyword} with do" do
      new_source = autocorrect_source(cop, <<-END.strip_indent)
        #{keyword} #{lit} do
        end
      END

      expect(new_source).to eq(<<-END.strip_indent)
        loop do
        end
      END
    end

    it "auto-corrects the usage of #{keyword} without do" do
      new_source = autocorrect_source(cop, <<-END.strip_indent)
        #{keyword} #{lit}
        end
      END

      expect(new_source).to eq(<<-END.strip_indent)
        loop do
        end
      END
    end
  end

  it_behaves_like 'auto-corrector', 'while', 'true'
  it_behaves_like 'auto-corrector', 'until', 'false'
end
