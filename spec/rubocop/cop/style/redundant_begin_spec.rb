# frozen_string_literal: true

describe RuboCop::Cop::Style::RedundantBegin do
  subject(:cop) { described_class.new }

  it 'reports an offense for single line def with redundant begin block' do
    src = '  def func; begin; x; y; rescue; z end end'
    inspect_source(cop, src)
    expect(cop.offenses.size).to eq(1)
  end

  it 'reports an offense for def with redundant begin block' do
    src = <<-END.strip_indent
      def func
        begin
          ala
        rescue => e
          bala
        end
      end
    END
    inspect_source(cop, src)
    expect(cop.offenses.size).to eq(1)
  end

  it 'reports an offense for defs with redundant begin block' do
    src = <<-END.strip_indent
      def Test.func
        begin
          ala
        rescue => e
          bala
        end
      end
    END
    inspect_source(cop, src)
    expect(cop.offenses.size).to eq(1)
  end

  it 'accepts a def with required begin block' do
    src = <<-END.strip_indent
      def func
        begin
          ala
        rescue => e
          bala
        end
        something
      end
    END
    inspect_source(cop, src)
    expect(cop.offenses).to be_empty
  end

  it 'accepts a defs with required begin block' do
    src = <<-END.strip_indent
      def Test.func
        begin
          ala
        rescue => e
          bala
        end
        something
      end
    END
    inspect_source(cop, src)
    expect(cop.offenses).to be_empty
  end

  it 'auto-corrects source separated by newlines ' \
     'by removing redundant begin blocks' do
    src = <<-END.strip_indent
        def func
          begin
            foo
            bar
          rescue
            baz
          end
        end
    END
    result_src = <<-END.strip_indent
        def func
          
            foo
            bar
          rescue
            baz
          
        end
    END
    new_source = autocorrect_source(cop, src)
    expect(new_source).to eq(result_src)
  end

  it 'auto-corrects source separated by semicolons ' \
     'by removing redundant begin blocks' do
    src = '  def func; begin; x; y; rescue; z end end'
    result_src = '  def func; ; x; y; rescue; z  end'
    new_source = autocorrect_source(cop, src)
    expect(new_source).to eq(result_src)
  end

  it "doesn't modify spacing when auto-correcting" do
    src = <<-END.strip_indent
      def method
        begin
          BlockA do |strategy|
            foo
          end

          BlockB do |portfolio|
            foo
          end

        rescue => e # some problem
          bar
        end
      end
    END

    result_src = <<-END.strip_indent
      def method
        
          BlockA do |strategy|
            foo
          end

          BlockB do |portfolio|
            foo
          end

        rescue => e # some problem
          bar
        
      end
    END
    new_source = autocorrect_source(cop, src)
    expect(new_source).to eq(result_src)
  end

  it 'auto-corrects when there are trailing comments' do
    src = <<-END.strip_indent
      def method
        begin # comment 1
          do_some_stuff
        rescue # comment 2
        end # comment 3
      end
    END
    result_src = <<-END.strip_indent
      def method
         # comment 1
          do_some_stuff
        rescue # comment 2
         # comment 3
      end
    END
    new_source = autocorrect_source(cop, src)
    expect(new_source).to eq(result_src)
  end
end
