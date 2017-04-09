# frozen_string_literal: true

module RuboCop
  module Formatter
    describe DisabledConfigFormatter, :isolated_environment do
      include FileHelper

      subject(:formatter) { described_class.new(output) }

      let(:output) do
        io = StringIO.new

        def io.path
          '.rubocop_todo.yml'
        end

        io
      end

      let(:offenses) do
        [RuboCop::Cop::Offense.new(:convention, location, 'message', 'Cop1'),
         RuboCop::Cop::Offense.new(:convention, location, 'message', 'Cop2')]
      end

      let(:location) { OpenStruct.new(line: 1, column: 5) }

      let(:heading) do
        format(described_class::HEADING, expected_heading_command) + "\n"
      end

      let(:expected_heading_command) do
        'rubocop --auto-gen-config'
      end

      around do |example|
        original_stdout = $stdout
        original_stderr = $stderr

        $stdout = StringIO.new
        $stderr = StringIO.new

        example.run

        $stdout = original_stdout
        $stderr = original_stderr
      end

      before do
        # Avoid intermittent failure when another test set ConfigLoader options
        ConfigLoader.clear_options
      end

      context 'when any offenses are detected' do
        before do
          formatter.started(['test_a.rb', 'test_b.rb'])
          formatter.file_started('test_a.rb', {})
          formatter.file_finished('test_a.rb', offenses)
          formatter.file_started('test_b.rb', {})
          formatter.file_finished('test_b.rb', [offenses.first])
          formatter.finished(['test_a.rb', 'test_b.rb'])
        end

        let(:expected_rubocop_todo) do
          [heading,
           '# Offense count: 2',
           'Cop1:',
           '  Exclude:',
           "    - 'test_a.rb'",
           "    - 'test_b.rb'",
           '',
           '# Offense count: 1',
           'Cop2:',
           '  Exclude:',
           "    - 'test_a.rb'",
           ''].join("\n")
        end

        it 'displays YAML configuration disabling all cops with offenses' do
          expect(output.string).to eq(expected_rubocop_todo)

          expect($stdout.string)
            .to eq(['Created .rubocop_todo.yml.',
                    'Run `rubocop --config .rubocop_todo.yml`, or ' \
                    'add `inherit_from: .rubocop_todo.yml` in a .rubocop.yml ' \
                    'file.',
                    ''].join("\n"))
        end
      end

      context "when there's .rubocop.yml" do
        before do
          create_file('.rubocop.yml', <<-END.strip_indent)
            Cop1:
              Exclude:
                - Gemfile
            Cop2:
              Exclude:
                - "**/*.blah"
          END
        end

        before do
          formatter.started(['test_a.rb', 'test_b.rb'])
          formatter.file_started('test_a.rb', {})
          formatter.file_finished('test_a.rb', offenses)
          formatter.file_started('test_b.rb', {})
          formatter.file_finished('test_b.rb', [offenses.first])
          formatter.finished(['test_a.rb', 'test_b.rb'])
        end

        let(:expected_rubocop_todo) do
          [heading,
           '# Offense count: 2',
           'Cop1:',
           '  Exclude:',
           "    - 'Gemfile'",
           "    - 'test_a.rb'",
           "    - 'test_b.rb'",
           '',
           '# Offense count: 1',
           'Cop2:',
           '  Exclude:',
           "    - '**/*.blah'",
           "    - 'test_a.rb'",
           ''].join("\n")
        end

        it 'merges in excludes from .rubocop.yml' do
          expect(output.string).to eq(expected_rubocop_todo)
        end
      end

      context 'when exclude_limit option is omitted' do
        before do
          formatter.started(filenames)

          filenames.each do |filename|
            formatter.file_started(filename, {})

            if filename == filenames.last
              formatter.file_finished(filename, [offenses.first])
            else
              formatter.file_finished(filename, offenses)
            end
          end

          formatter.finished(filenames)
        end

        let(:filenames) do
          Array.new(16) { |index| format('test_%02d.rb', index + 1) }
        end

        let(:expected_rubocop_todo) do
          [heading,
           '# Offense count: 16',
           'Cop1:',
           '  Enabled: false',
           '',
           '# Offense count: 15',
           'Cop2:',
           '  Exclude:',
           "    - 'test_01.rb'",
           "    - 'test_02.rb'",
           "    - 'test_03.rb'",
           "    - 'test_04.rb'",
           "    - 'test_05.rb'",
           "    - 'test_06.rb'",
           "    - 'test_07.rb'",
           "    - 'test_08.rb'",
           "    - 'test_09.rb'",
           "    - 'test_10.rb'",
           "    - 'test_11.rb'",
           "    - 'test_12.rb'",
           "    - 'test_13.rb'",
           "    - 'test_14.rb'",
           "    - 'test_15.rb'",
           ''].join("\n")
        end

        it 'disables the cop with 15 offending files' do
          expect(output.string).to eq(expected_rubocop_todo)
        end
      end

      context 'when exclude_limit option is passed' do
        let(:formatter) { described_class.new(output, exclude_limit: 5) }

        before do
          formatter.started(filenames)

          filenames.each do |filename|
            formatter.file_started(filename, {})

            if filename == filenames.last
              formatter.file_finished(filename, [offenses.first])
            else
              formatter.file_finished(filename, offenses)
            end
          end

          formatter.finished(filenames)
        end

        let(:filenames) do
          Array.new(6) { |index| format('test_%02d.rb', index + 1) }
        end

        let(:expected_heading_command) do
          'rubocop --auto-gen-config --exclude-limit 5'
        end

        let(:expected_rubocop_todo) do
          [heading,
           '# Offense count: 6',
           'Cop1:',
           '  Enabled: false',
           '',
           '# Offense count: 5',
           'Cop2:',
           '  Exclude:',
           "    - 'test_01.rb'",
           "    - 'test_02.rb'",
           "    - 'test_03.rb'",
           "    - 'test_04.rb'",
           "    - 'test_05.rb'",
           ''].join("\n")
        end

        it 'respects the file exclusion list limit' do
          expect(output.string).to eq(expected_rubocop_todo)
        end
      end

      context 'when no files are inspected' do
        before do
          formatter.started([])
          formatter.finished([])
        end

        it 'creates a .rubocop_todo.yml even in such case' do
          expect(output.string).to eq(heading)
        end
      end
    end
  end
end
