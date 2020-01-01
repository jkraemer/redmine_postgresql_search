module RedminePostgresqlSearch
  class Tokenizer
    class << self
      # extract tokens from the question
      # eg. hello "bye bye" => ["hello", "bye bye"]
      def build_tokens(question)
        tokens = question.scan(/((\s|^)"[^"]+"(\s|$)|\S+)/).collect { |m| m.first.gsub(/(^\s*"\s*|\s*"\s*$)/, '') }
        return [] if tokens.empty?

        @force_regular_search = false
        [sanitize_query_tokens(tokens), @force_regular_search]
      end

      private

      def force_regular_search?(token)
        return true if @force_regular_search

        # allow ip address search
        @force_regular_search = true if token =~ /\b\d{1,3}\.\d{1,3}\.\d{1,3}\./

        @force_regular_search
      end

      # TODO: at the moment this breaks phrase search
      def sanitize_query_tokens(tokens)
        rc = Array(tokens).map do |token|
          if force_regular_search? token
            token
          else
            token.to_s.split(/[^[:alnum:]\*]+/).select { |w| w.present? && w.length > 1 }
          end
        end

        rc.flatten!
        rc.uniq
      end
    end

    def initialize(record, mapping = {})
      @record = record
      @mapping = mapping
    end

    def index_data
      {}.tap do |data|
        @mapping.each do |weight, fields|
          data[weight] = get_value_for_fields fields
        end
      end
    end

    private

    def normalize_string(string)
      string.to_s.gsub(/[^[:alnum:]]+/, ' ')
    end

    def get_value_for_fields(fields)
      Array(fields).map do |f|
        normalize_string(
          if f.respond_to?(:call)
            @record.instance_exec(&f)
          else
            @record.send(f)
          end
        )
      end.join ' '
    end
  end
end
