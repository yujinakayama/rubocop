# frozen_string_literal: true

describe RuboCop::ConfigLoader do
  include FileHelper

  let(:default_config) { described_class.default_configuration }

  describe '.configuration_file_for', :isolated_environment do
    subject(:configuration_file_for) do
      described_class.configuration_file_for(dir_path)
    end

    context 'when no config file exists in ancestor directories' do
      let(:dir_path) { 'dir' }
      before { create_file('dir/example.rb', '') }

      context 'but a config file exists in home directory' do
        before { create_file('~/.rubocop.yml', '') }

        it 'returns the path to the file in home directory' do
          expect(configuration_file_for).to end_with('home/.rubocop.yml')
        end
      end

      context 'and no config file exists in home directory' do
        it 'falls back to the provided default file' do
          expect(configuration_file_for).to end_with('config/default.yml')
        end
      end

      context 'and ENV has no `HOME` defined' do
        before { ENV.delete 'HOME' }

        it 'falls back to the provided default file' do
          expect(configuration_file_for).to end_with('config/default.yml')
        end
      end
    end

    context 'when a config file exists in the parent directory' do
      let(:dir_path) { 'dir' }

      before do
        create_file('dir/example.rb', '')
        create_file('.rubocop.yml', '')
      end

      it 'returns the path to that configuration file' do
        expect(configuration_file_for).to end_with('work/.rubocop.yml')
      end
    end

    context 'when multiple config files exist in ancestor directories' do
      let(:dir_path) { 'dir' }

      before do
        create_file('dir/example.rb', '')
        create_file('dir/.rubocop.yml', '')
        create_file('.rubocop.yml', '')
      end

      it 'prefers closer config file' do
        expect(configuration_file_for).to end_with('dir/.rubocop.yml')
      end
    end
  end

  describe '.configuration_from_file', :isolated_environment do
    subject(:configuration_from_file) do
      described_class.configuration_from_file(file_path)
    end

    context 'with any config file' do
      let(:file_path) { '.rubocop.yml' }

      before do
        create_file(file_path, <<-END.strip_indent)
          Style/Encoding:
            Enabled: false
        END
      end

      it 'returns a configuration inheriting from default.yml' do
        config = default_config['Style/Encoding'].dup
        config['Enabled'] = false
        expect(configuration_from_file.to_h)
          .to eql(default_config.merge('Style/Encoding' => config))
      end
    end

    context 'when multiple config files exist in ancestor directories' do
      let(:file_path) { 'dir/.rubocop.yml' }

      before do
        create_file('.rubocop.yml', <<-END.strip_indent)
          AllCops:
            Exclude:
              - vendor/**
        END

        create_file(file_path, <<-END.strip_indent)
          AllCops:
            Exclude: []
        END
      end

      it 'gets AllCops/Exclude from the highest directory level' do
        excludes = configuration_from_file['AllCops']['Exclude']
        expect(excludes).to eq([File.expand_path('vendor/**')])
      end
    end

    context 'when a parent file specifies DisabledByDefault: true' do
      let(:file_path) { '.rubocop.yml' }

      before do
        create_file('disable.yml', <<-END.strip_indent)
          AllCops:
            DisabledByDefault: true
        END

        create_file(file_path, ['inherit_from: disable.yml'])
      end

      it 'disables cops by default' do
        cop_options = configuration_from_file['Style/Alias']
        expect(cop_options.fetch('Enabled')).to be(false)
      end
    end

    context 'when a file inherits from a parent file' do
      let(:file_path) { 'dir/.rubocop.yml' }

      before do
        create_file('.rubocop.yml', <<-END.strip_indent)
          AllCops:
            Exclude:
              - vendor/**
              - !ruby/regexp /[A-Z]/
        END

        create_file(file_path, ['inherit_from: ../.rubocop.yml'])
      end

      it 'gets an absolute AllCops/Exclude' do
        excludes = configuration_from_file['AllCops']['Exclude']
        expect(excludes).to eq([File.expand_path('vendor/**'), /[A-Z]/])
      end
    end

    context 'when a file inherits from an empty parent file' do
      let(:file_path) { 'dir/.rubocop.yml' }

      before do
        create_file('.rubocop.yml', [''])

        create_file(file_path, ['inherit_from: ../.rubocop.yml'])
      end

      it 'does not fail to load' do
        expect { configuration_from_file }.not_to raise_error
      end
    end

    context 'when a file inherits from a sibling file' do
      let(:file_path) { 'dir/.rubocop.yml' }

      before do
        create_file('src/.rubocop.yml', <<-END.strip_indent)
          AllCops:
            Exclude:
              - vendor/**
        END

        create_file(file_path, ['inherit_from: ../src/.rubocop.yml'])
      end

      it 'gets an absolute AllCops/Exclude' do
        excludes = configuration_from_file['AllCops']['Exclude']
        expect(excludes).to eq([File.expand_path('src/vendor/**')])
      end
    end

    context 'when a third party require defines a new gem' do
      before do
        allow(RuboCop::Cop::Cop)
          .to receive(:registry)
          .and_return(
            RuboCop::Cop::Registry.new(RuboCop::Cop::Cop.registry.cops)
          )

        create_file('third_party/gem.rb', <<-END.strip_indent)
          module RuboCop
            module Cop
              module Custom
                class FilePath < Cop
                end
              end
            end
          end
        END

        create_file('.rubocop.yml', <<-END.strip_indent)
          Custom/FilePath:
            Enabled: false
        END

        create_file('.rubocop_with_require.yml', <<-END.strip_indent)
          require: ./third_party/gem
          Custom/FilePath:
            Enabled: false
        END
      end

      it 'does not emit a warning' do
        aggregate_failures('loads requires before resolving namespace') do
          expect { described_class.configuration_from_file('.rubocop.yml') }
            .to output(
              a_string_including(
                '.rubocop.yml: Custom/FilePath has the ' \
                "wrong namespace - should be Rails\n"
              )
            ).to_stderr

          expect do
            described_class.configuration_from_file('.rubocop_with_require.yml')
          end.not_to output.to_stderr
        end
      end
    end

    context 'when a file inherits from a parent and grandparent file' do
      let(:file_path) { 'dir/subdir/.rubocop.yml' }

      before do
        create_file('dir/subdir/example.rb', '')

        create_file('.rubocop.yml', <<-END.strip_indent)
          Metrics/LineLength:
            Enabled: false
            Max: 77
        END

        create_file('dir/.rubocop.yml', <<-END.strip_indent)
          inherit_from: ../.rubocop.yml

          Metrics/MethodLength:
            Enabled: true
            CountComments: false
            Max: 10
        END

        create_file(file_path, <<-END.strip_indent)
          inherit_from: ../.rubocop.yml

          Metrics/LineLength:
            Enabled: true

          Metrics/MethodLength:
            Max: 5
        END
      end

      it 'returns the ancestor configuration plus local overrides' do
        config =
          default_config.merge(
            'Metrics/LineLength' => {
              'Description' =>
              default_config['Metrics/LineLength']['Description'],
              'StyleGuide' => '#80-character-limits',
              'Enabled' => true,
              'Max' => 77,
              'AllowHeredoc' => true,
              'AllowURI' => true,
              'URISchemes' => %w(http https),
              'IgnoreCopDirectives' => false,
              'IgnoredPatterns' => []
            },
            'Metrics/MethodLength' => {
              'Description' =>
              default_config['Metrics/MethodLength']['Description'],
              'StyleGuide' => '#short-methods',
              'Enabled' => true,
              'CountComments' => false,
              'Max' => 5
            }
          )
        expect(configuration_from_file.to_h).to eq(config)
      end
    end

    context 'when a file inherits from two configurations' do
      let(:file_path) { '.rubocop.yml' }

      before do
        create_file('example.rb', '')

        create_file('normal.yml', <<-END.strip_indent)
          Metrics/MethodLength:
            Enabled: false
            CountComments: true
            Max: 80
        END

        create_file('special.yml', <<-END.strip_indent)
          Metrics/MethodLength:
            Enabled: false
            Max: 200
        END

        create_file(file_path, <<-END.strip_indent)
          inherit_from:
            - normal.yml
            - special.yml

          Metrics/MethodLength:
            Enabled: true
        END
      end

      it 'returns values from the last one when possible' do
        expected = { 'Enabled' => true,        # overridden in .rubocop.yml
                     'CountComments' => true,  # only defined in normal.yml
                     'Max' => 200 }            # special.yml takes precedence
        expect(configuration_from_file['Metrics/MethodLength'].to_set)
          .to be_superset(expected.to_set)
      end
    end

    context 'when a file inherits and overrides with non-namedspaced cops' do
      let(:file_path) { '.rubocop.yml' }

      before do
        create_file('example.rb', '')

        create_file('line_length.yml', <<-END.strip_indent)
          LineLength:
            Max: 120
        END

        create_file(file_path, <<-END.strip_indent)
          inherit_from:
            - line_length.yml

          LineLength:
            AllowHeredoc: false
        END
      end

      it 'returns includes both of the cop changes' do
        config =
          default_config.merge(
            'Metrics/LineLength' => {
              'Description' =>
              default_config['Metrics/LineLength']['Description'],
              'StyleGuide' => '#80-character-limits',
              'Enabled' => true,
              'Max' => 120,             # overridden in line_length.yml
              'AllowHeredoc' => false,  # overridden in rubocop.yml
              'AllowURI' => true,
              'URISchemes' => %w(http https),
              'IgnoreCopDirectives' => false,
              'IgnoredPatterns' => []
            }
          )

        expect(configuration_from_file.to_h).to eq(config)
      end
    end

    context 'when a file inherits from an expanded path' do
      let(:file_path) { '.rubocop.yml' }

      before do
        create_file('~/.rubocop.yml', [''])
        create_file(file_path, ['inherit_from: ~/.rubocop.yml'])
      end

      it 'does not fail to load expanded path' do
        expect { configuration_from_file }.not_to raise_error
      end
    end

    context 'when a file inherits from an unknown gem' do
      let(:file_path) { '.rubocop.yml' }

      before do
        create_file(file_path, <<-END.strip_indent)
          inherit_gem:
            not_a_real_gem: config/rubocop.yml
        END
      end

      it 'fails to load' do
        expect { configuration_from_file }.to raise_error(Gem::LoadError)
      end
    end

    context 'when a file inherits from the rubocop gem' do
      let(:file_path) { '.rubocop.yml' }

      before do
        create_file(file_path, <<-END.strip_indent)
          inherit_gem:
            rubocop: config/default.yml
        END
      end

      it 'fails to load' do
        expect { configuration_from_file }.to raise_error(ArgumentError)
      end
    end

    context 'when a file inherits from a known gem' do
      let(:file_path) { '.rubocop.yml' }

      before do
        create_file('gemone/config/rubocop.yml', <<-END.strip_indent)
          Metrics/MethodLength:
            Enabled: false
            Max: 200
            CountComments: false
        END
        create_file('gemtwo/config/default.yml', <<-END.strip_indent)
          Metrics/LineLength:
            Enabled: true
        END
        create_file('gemtwo/config/strict.yml', <<-END.strip_indent)
          Metrics/LineLength:
            Max: 72
            AllowHeredoc: false
        END
        create_file('local.yml', <<-END.strip_indent)
          Metrics/MethodLength:
            CountComments: true
        END
        create_file(file_path, <<-END.strip_indent)
          inherit_gem:
            gemone: config/rubocop.yml
            gemtwo:
              - config/default.yml
              - config/strict.yml

          inherit_from: local.yml

          Metrics/MethodLength:
            Enabled: true

          Metrics/LineLength:
            AllowURI: false
        END
      end

      it 'returns values from the gem config with local overrides' do
        gem_class = Struct.new(:gem_dir)
        %w(gemone gemtwo).each do |gem_name|
          mock_spec = gem_class.new(gem_name)
          expect(Gem::Specification).to receive(:find_by_name)
            .at_least(:once).with(gem_name).and_return(mock_spec)
        end

        expected = { 'Enabled' => true,        # overridden in .rubocop.yml
                     'CountComments' => true,  # overridden in local.yml
                     'Max' => 200 }            # inherited from somegem
        expect(configuration_from_file['Metrics/MethodLength'].to_set)
          .to be_superset(expected.to_set)

        expected = { 'Enabled' => true,        # gemtwo/config/default.yml
                     'Max' => 72,              # gemtwo/config/strict.yml
                     'AllowHeredoc' => false,  # gemtwo/config/strict.yml
                     'AllowURI' => false }     # overridden in .rubocop.yml
        expect(configuration_from_file['Metrics/LineLength'].to_set)
          .to be_superset(expected.to_set)
      end
    end

    context 'when a file inherits from a url' do
      let(:file_path) { '.rubocop.yml' }
      let(:cache_file) { '.rubocop-http---example-com-rubocop-yml' }

      before do
        stub_request(:get, /example.com/)
          .to_return(status: 200, body: "Style/Encoding:\n    Enabled: true")

        create_file(file_path, ['inherit_from: http://example.com/rubocop.yml'])
      end

      after do
        File.unlink cache_file if File.exist? cache_file
      end

      it 'creates the cached file alongside the owning file' do
        configuration_from_file
        expect(File.exist?(cache_file)).to be true
      end
    end

    context 'when a file inherits from a non http/https url' do
      let(:file_path) { '.rubocop.yml' }

      before do
        create_file(file_path, ['inherit_from: c:\\\\foo\\bar.yml'])
      end

      it 'fails to load the resulting path' do
        expect { configuration_from_file }.to raise_error(Errno::ENOENT)
      end
    end

    context 'EnabledByDefault / DisabledByDefault' do
      def cop_enabled?(cop_class)
        configuration_from_file.for_cop(cop_class).fetch('Enabled')
      end

      let(:file_path) { '.rubocop.yml' }

      before do
        create_file(file_path, config)
      end

      context 'when DisabledByDefault is true' do
        let(:config) do
          <<-END.strip_indent
            AllCops:
              DisabledByDefault: true
            Style/Copyright:
              Exclude:
              - foo
          END
        end

        it 'enables cops that are explicitly in the config file '\
          'even if they are disabled by default' do
          cop_class = RuboCop::Cop::Style::Copyright
          expect(cop_enabled?(cop_class)).to be true
        end

        it 'disables cops that are normally enabled by default' do
          cop_class = RuboCop::Cop::Style::TrailingWhitespace
          expect(cop_enabled?(cop_class)).to be false
        end
      end

      context 'when EnabledByDefault is true' do
        let(:config) do
          <<-END.strip_indent
            AllCops:
              EnabledByDefault: true
            Style/TrailingWhitespace:
              Enabled: false
          END
        end

        it 'enables cops that are disabled by default' do
          cop_class = RuboCop::Cop::Style::FirstMethodArgumentLineBreak
          expect(cop_enabled?(cop_class)).to be true
        end

        it 'respects cops that are disbled in the config' do
          cop_class = RuboCop::Cop::Style::TrailingWhitespace
          expect(cop_enabled?(cop_class)).to be false
        end
      end
    end
  end

  describe '.load_file', :isolated_environment do
    subject(:load_file) do
      described_class.load_file(configuration_path)
    end

    let(:configuration_path) { '.rubocop.yml' }

    it 'returns a configuration loaded from the passed path' do
      create_file(configuration_path, <<-END.strip_indent)
        Style/Encoding:
          Enabled: true
      END
      configuration = load_file
      expect(configuration['Style/Encoding']).to eq(
        'Enabled' => true
      )
    end

    it 'fails with a TypeError when loading a malformed configuration file' do
      create_file(configuration_path, 'This string is not a YAML hash')
      expect { load_file }.to raise_error(
        TypeError, /^Malformed configuration in .*\.rubocop\.yml$/
      )
    end

    it 'changes target ruby version with a patch to float' do
      create_file(configuration_path, <<-END.strip_indent)
        AllCops:
          TargetRubyVersion: 2.3.4
      END

      expect(load_file.to_h).to eq('AllCops' => { 'TargetRubyVersion' => 2.3 })
    end

    it 'loads configuration properly when it includes non-ascii characters ' do
      create_file(configuration_path, <<-END.strip_indent)
        # All these cops of mine are ❤
        Style/Encoding:
          Enabled: false
      END

      expect(load_file.to_h).to eq('Style/Encoding' => { 'Enabled' => false })
    end

    it 'returns an empty configuration loaded from an empty file' do
      create_file(configuration_path, '')
      configuration = load_file
      expect(configuration.to_h).to eq({})
    end

    context 'when SafeYAML is required' do
      before do
        create_file(configuration_path, <<-END.strip_indent)
          Style/WordArray:
            WordRegex: !ruby/regexp '/\\A[\\p{Word}]+\\z/'
        END
      end

      context 'when it is fully required' do
        it 'de-serializes Regexp class' do
          in_its_own_process_with('safe_yaml') do
            configuration = described_class.load_file('.rubocop.yml')

            word_regexp = configuration['Style/WordArray']['WordRegex']
            expect(word_regexp).to be_a(::Regexp)
          end
        end
      end

      context 'when safe_yaml is required without monkey patching' do
        it 'de-serializes Regexp class' do
          in_its_own_process_with('safe_yaml/load') do
            configuration = described_class.load_file('.rubocop.yml')

            word_regexp = configuration['Style/WordArray']['WordRegex']
            expect(word_regexp).to be_a(::Regexp)
          end
        end

        context 'and SafeYAML.load is private' do
          # According to issue #2935, SafeYAML.load can be private in some
          # circumstances.
          it 'does not raise private method load called for SafeYAML:Module' do
            in_its_own_process_with('safe_yaml/load') do
              SafeYAML.send :private_class_method, :load
              configuration = described_class.load_file('.rubocop.yml')

              word_regexp = configuration['Style/WordArray']['WordRegex']
              expect(word_regexp).to be_a(::Regexp)
            end
          end
        end
      end
    end
  end

  describe '.merge' do
    subject(:merge) { described_class.merge(base, derived) }

    let(:base) do
      {
        'AllCops' => {
          'Include' => ['**/*.gemspec', '**/Rakefile'],
          'Exclude' => []
        }
      }
    end
    let(:derived) do
      { 'AllCops' => { 'Exclude' => ['example.rb', 'exclude_*'] } }
    end

    it 'returns a recursive merge of its two arguments' do
      expect(merge).to eq('AllCops' => {
                            'Include' => ['**/*.gemspec', '**/Rakefile'],
                            'Exclude' => ['example.rb', 'exclude_*']
                          })
    end
  end

  describe 'configuration for CharacterLiteral', :isolated_environment do
    let(:dir_path) { 'test/blargh' }

    let(:config) do
      config_path = described_class.configuration_file_for(dir_path)
      described_class.configuration_from_file(config_path)
    end

    context 'when .rubocop.yml inherits from a file with a name starting ' \
            'with .rubocop' do
      before do
        create_file('test/.rubocop_rules.yml', <<-END.strip_indent)
          Style/CharacterLiteral:
            Exclude:
              - blargh/blah.rb
        END
        create_file('test/.rubocop.yml', 'inherit_from: .rubocop_rules.yml')
      end

      it 'gets an Exclude relative to the inherited file converted to ' \
         'absolute' do
        expect(config.for_cop(RuboCop::Cop::Style::CharacterLiteral)['Exclude'])
          .to eq([File.join(Dir.pwd, 'test/blargh/blah.rb')])
      end
    end
  end

  describe 'configuration for AssignmentInCondition' do
    describe 'AllowSafeAssignment' do
      it 'is enabled by default' do
        default_config = described_class.default_configuration
        symbol_name_config =
          default_config.for_cop('Lint/AssignmentInCondition')
        expect(symbol_name_config['AllowSafeAssignment']).to be_truthy
      end
    end
  end

  describe 'when a requirement is defined', :isolated_environment do
    let(:required_file_path) { './required_file.rb' }

    before do
      create_file('.rubocop.yml', ['require:', "  - #{required_file_path}"])
      create_file(required_file_path, ['class MyClass', 'end'])
    end

    it 'requires the passed path' do
      config_path = described_class.configuration_file_for('.')
      described_class.configuration_from_file(config_path)
      expect(defined?(MyClass)).to be_truthy
    end

    it 'uses paths relative to the .rubocop.yml, not cwd' do
      config_path = described_class.configuration_file_for('.')
      Dir.chdir '..' do
        described_class.configuration_from_file(config_path)
        expect(defined?(MyClass)).to be_truthy
      end
    end
  end

  describe 'when a unqualified requirement is defined', :isolated_environment do
    let(:required_file_path) { 'required_file' }

    before do
      create_file('.rubocop.yml', ['require:', "  - #{required_file_path}"])
      create_file(required_file_path + '.rb', ['class MyClass', 'end'])
    end

    it 'works without a starting .' do
      config_path = described_class.configuration_file_for('.')
      $LOAD_PATH.unshift(File.dirname(config_path))
      Dir.chdir '..' do
        described_class.configuration_from_file(config_path)
        expect(defined?(MyClass)).to be_truthy
      end
    end
  end
end
