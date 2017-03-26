require 'rubocop'

SourceArray = Struct.new(:node, :rewriter) do
  def source_array?
    all_str_elements? &&
      str_nodes.size > 1 &&
      multiline_elements? &&
      node.loc.begin.source == '[' &&
      last_arg_if_wrapped? &&
      !option_array? &&
      !part_of_parent_array? &&
      !chained_with_block? &&
      !non_source_expectation? &&
      !trailing_whitespace? &&
      !trailing_escape?
  end

  def rewrite
    if wrapper_node && emacs_wrap_style?
      _receiver_node, _name, *arg_nodes = *wrapper_node
      preceding_arg_node = arg_nodes.take_while { |arg_node| !arg_node.equal?(chain_root_node) }.last
      if preceding_arg_node
        range = preceding_arg_node.loc.expression.end.join(chain_root_node.loc.expression.begin)
        rewriter.replace(range, ', ')
      end
    end

    if emacs_style?
      rewriter.replace(node.loc.begin, "<<-#{beginning_marker}.#{stripper}#{trailing_source}\n#{source_indentation}#{first_line_prefix}")
      rewriter.replace(node.loc.end, "\n#{base_indentation}END")
    else
      rewriter.replace(node.loc.begin, "<<-#{beginning_marker}.#{stripper}#{trailing_source}")
      rewriter.replace(node.loc.end, 'END')

      indentation_difference = node.loc.end.column - base_indentation.size
      removed_indentation_range = beginning_of_line_range(node.loc.end).resize(indentation_difference)
      rewriter.remove(removed_indentation_range)
    end

    rewriter.remove(trailing_range) if trailing_range

    str_nodes.each_with_index do |str_node, index|
      if indented_source?
        rewriter.insert_after(str_node.loc.begin, '|') if (index.nonzero? && emacs_style?) || !emacs_style?
      end

      if index == str_nodes.size - 1 && str_node.source.size == 2
        prev_linefeed_range = Parser::Source::Range.new(
          str_node.loc.expression.source_buffer,
          beginning_of_line_range(str_node.loc.expression).begin_pos - 1,
          beginning_of_line_range(str_node.loc.expression).begin_pos,
        )
        rewriter.remove(prev_linefeed_range.join(str_node.loc.expression))
        next
      end

      rewriter.remove(str_node.loc.begin)
      rewriter.remove(str_node.loc.end)

      comma_range = str_node.loc.end.end.resize(1)
      if comma_range.source == ','
        rewriter.remove(comma_range)
      end

      if (index.nonzero? && emacs_style?) || !emacs_style?
        if str_node.loc.expression.source.size > 2
          indentation_difference = str_node.loc.begin.column - source_indentation.size
          if indentation_difference > 0
            removed_indentation_range = beginning_of_line_range(str_node.loc.begin).resize(indentation_difference)
            rewriter.remove(removed_indentation_range)
          elsif indentation_difference < 0
            rewriter.insert_before(str_node.loc.begin, ' ' * (-indentation_difference))
          end
        else
          rewriter.remove(beginning_of_line_range(str_node.loc.expression).join(str_node.loc.expression.begin))
        end
      end
    end
  end

  def stripper
    if indented_source?
      "strip_margin('|')"
    else
      'strip_indent'
    end
  end

  def first_line_prefix
    indented_source? ? '|' : ''
  end

  def indented_source?
    str_nodes.all? do |str_node|
      str_node.source.match(/\A['"]\s+/)
    end
  end

  def base_indentation
    @base_indentation ||=
      if wrapper_node && emacs_wrap_style?
        indentation_of_line(wrapper_node.loc.expression)
      else
        indentation_of_line(node.loc.expression)
      end
  end

  def source_indentation
    @source_indentation ||= base_indentation + '  '
  end

  def beginning_marker
    if dynamic? || !include_interporation?
      'END'
    else
      "'END'"
    end
  end

  def dynamic?
    str_nodes.any?(&:dstr_type?)
  end

  def include_interporation?
    str_nodes.any? do |str_node|
      str_node.loc.expression.source.include?('#{') ||
        (str_node.loc.begin.source == "'" && str_node.loc.expression.source.match(/\\[^']/))
    end
  end

  def trailing_source
    return '' unless trailing_range
    source = if join?
               if wrapper_node
                 chain_root_node.loc.expression.end.join(wrapper_node.loc.expression.end).source
               else
                 ''
               end
             else
               trailing_range.source
             end
    /\A(?<single_line>[^\n]+)/ =~ source
    single_line
  end

  def trailing_range
    if wrapper_node && emacs_wrap_style?
      node.loc.expression.end.join(wrapper_node.loc.expression.end)
    elsif chained?
      node.loc.expression.end.join(chain_root_node.loc.expression.end)
    else
      nil
    end
  end

  def all_str_elements?
    str_nodes.all? { |node| node.str_type? || (node.dstr_type? && node.loc.respond_to?(:begin) && node.loc.begin) }
  end

  def multiline_elements?
    str_nodes.map { |str_node| str_node.loc.expression.line }.uniq.size == str_nodes.size
  end

  def last_arg_if_wrapped?
    return true unless wrapper_node
    wrapper_node.children.last.equal?(chain_root_node)
  end

  def option_array?
    str_nodes.first.loc.expression.source.start_with?("'--")
  end

  def part_of_parent_array?
    chain_root_node.parent && chain_root_node.parent.array_type?
  end

  def chained_with_block?
    return false unless chained?
    chain_root_node.parent && chain_root_node.parent.block_type?
  end

  # s(:send,
  #   s(:send, nil, :expect,
  #     s(:send,
  #       s(:send, nil, :cop), :messages)), :to,
  #   s(:send, nil, :eq,
  #     s(:array,
  #       s(:str, "Unnecessary disabling of `Metrics/MethodLength`."),
  #       s(:str, "Unnecessary disabling of `Lint/Debugger`."),
  #       s(:str, "Unnecessary disabling of `Lint/AmbiguousOperator`."))))
  def non_source_expectation?
    node.each_ancestor(:send).any? do |send_node|
      receiver, = *send_node
      next if receiver.nil? || !receiver.send_type?
      next unless receiver.children[1] == :expect
      receiver.source.match(/messages|highlights|names/)
    end
  end

  def trailing_whitespace?
    str_nodes.any? do |str_node|
      str_node.source.match(/\s['"]\z/)
    end
  end

  def trailing_escape?
    str_nodes.any? do |str_node|
      str_node.source.match(/\\['"]\z/)
    end
  end

  def str_nodes
    node.children
  end

  # ['foo',
  #  'bar']
  def emacs_style?
    node.loc.expression.line == str_nodes.first.loc.expression.line
  end

  def emacs_wrap_style?
    wrapper_node.loc.expression.end.line == chain_root_node.loc.expression.end.line
  end

  def remove_join
    return unless join?
    rewriter.remove(chain_root_node.loc.dot.join(chain_root_node.loc.end))
  end

  def join?
    return unless chained?
    _receiver_node, name, *arg_nodes = * chain_root_node
    name == :join && !arg_nodes.empty?
  end

  def chained?
    !chain_root_node.equal?(node)
  end

  def chain_root_node
    @chain_root_node ||= begin
      node = self.node
      while node.parent && node.parent.send_type? && node.sibling_index.zero?
        node = node.parent
      end
      node
    end
  end

  def wrapper_node
    if chain_root_node.parent && chain_root_node.parent.send_type? && chain_root_node.sibling_index >= 2
      chain_root_node.parent
    end
  end

  def indentation_of_line(range)
    /^(?<indentation>\s*)\S/ =~ range.source_line
    indentation
  end

  def line_range(range, include_linefeed: false)
    size = range.source_line.size
    size += 1 if include_linefeed
    beginning_of_line_range(range).resize(size)
  end

  def beginning_of_line_range(range)
    begin_pos = range.begin_pos - range.column
    Parser::Source::Range.new(range.source_buffer, begin_pos, begin_pos)
  end
end

SourceRewriter = Struct.new(:processed_source) do
  def rewrite
    processed_source.ast.each_node(:array) do |array_node|
      source_array = SourceArray.new(array_node, rewriter)
      next unless source_array.source_array?
      source_array.rewrite
    end

    rewriter.process
  end

  def rewriter
    @rewriter ||= Parser::Source::Rewriter.new(processed_source.buffer)
  end
end

if ENV['RUN']
  blacklist = [
    'string_literals_in_interpolation_spec.rb',
    'space_inside_string_interpolation_spec.rb',
    'string_literals_spec.rb',
    'trailing_whitespace_spec.rb',
    'unneeded_percent_q_spec.rb',
    'command_literal_spec.rb',
    '_line_break_spec.rb',
    'indent',
    'regexp_literal_spec.rb',
    'line_end_concatenation_spec',
    'empty_method_spec.rb',
    'rails/safe_navigation_spec.rb',
    'rubocop/config_spec.rb',
    'debugger_spec.rb',
    'end_of_line_spec.rb',
    'word_array_spec.rb'
  ]

  Dir.glob('spec/**/*.rb') do |path|
    next if blacklist.any? { |black_word| path.include?(black_word) }
    puts path
    processed_source = RuboCop::ProcessedSource.new(File.read(path), 2.4)
    rewriter = SourceRewriter.new(processed_source)
    File.write(path, rewriter.rewrite)
  end
end
