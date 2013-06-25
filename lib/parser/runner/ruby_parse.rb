require 'parser/runner'
require 'parser/lexer/explanation'

module Parser

  class Runner::RubyParse < Parser::Runner

    class LocationProcessor < Parser::AST::Processor
      def process(node)
        p node

        if node.src.nil?
          puts "\e[31m[no location info]\e[0m"
        elsif node.src.expression.nil?
          puts "\e[31m[location info present but empty]\e[0m"
        else
          source_line_no = nil
          source_line    = ""
          hilight_line   = ""

          print_line = lambda do
            unless hilight_line.empty?
              puts hilight_line.
                gsub(/[a-z_]+/) { |m| "\e[1;33m#{m}\e[0m" }.
                gsub(/[~.]+/)   { |m| "\e[1;35m#{m}\e[0m" }
              hilight_line = ""
            end
          end

          print_source = lambda do |range|
            source_line = range.source_line
            puts "\e[32m#{source_line}\e[0m"
            source_line
          end

          node.src.to_hash.
            sort_by do |name, range|
              [(range ? range.line : 0),
               (name == :expression ? 1 : 0)]
            end.
            each do |name, range|
              next if range.nil?

              if source_line_no != range.line
                print_line.call()
                source_line    = print_source.call(range)
                source_line_no = range.line
              end

              beg_col = range.begin.column

              if beg_col + range.length > source_line.length
                multiline    = true
                range_length = source_line.length - beg_col + 3
              else
                multiline    = false
                range_length = range.length
              end

              length  = range_length + 1 + name.length
              end_col = beg_col + length

              if beg_col > 0
                col_range = (beg_col - 1)...end_col
              else
                col_range = beg_col...end_col
              end

              if hilight_line.length < end_col
                hilight_line = hilight_line.ljust(end_col)
              end

              if hilight_line[col_range] =~ /^\s*$/
                if multiline
                  tail = ('~' * (source_line.length - beg_col)) + '...'
                else
                  tail = '~' * range_length
                end

                tail = ' ' + tail if beg_col > 0

                hilight_line[col_range] = tail + " #{name}"
              else
                print_line.call
                redo
              end
            end

          print_line.call
        end

        super
      end
    end

    private

    def runner_name
      'ruby-parse'
    end

    def setup_option_parsing
      super

      @slop.on 'L', 'locate',  'Explain how source maps for AST nodes are laid out'

      @slop.on 'E', 'explain', 'Explain how the source is tokenized' do
        ENV['RACC_DEBUG'] = '1'

        Lexer.send :include, Lexer::Explanation
      end
    end

    def process_all_input
      super

      if input_size > 1
        puts "Using #{@parser_class} to parse #{input_size} files."
      end
    end

    def process(buffer)
      ast = @parser.parse(buffer)

      if @slop.locate?
        LocationProcessor.new.process(ast)
      elsif !@slop.benchmark?
        p ast
      end
    end
  end

end
