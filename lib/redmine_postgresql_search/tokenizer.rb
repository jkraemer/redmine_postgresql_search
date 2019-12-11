module RedminePostgresqlSearch
  class Tokenizer
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

    def self.normalize_string(string)
      string.to_s.gsub(/[^[:alnum:]]+/, ' ')
    end

    # extract tokens from the question
    # eg. hello "bye bye" => ["hello", "bye bye"]
    def self.build_tokens(question)
      tokens = question.scan(/((\s|^)"[^"]+"(\s|$)|\S+)/).collect { |m| m.first.gsub(/(^\s*"\s*|\s*"\s*$)/, '') }
      return [] if tokens.empty?

      Tokenizer.sanitize_query_tokens(tokens)
    end

    # TODO: at the moment this breaks phrase search
    def self.sanitize_query_tokens(tokens)
      Array(tokens).map do |token|
        if token =~ /\b\d{1,3}\.\d{1,3}\.\d{1,3}\./ # allow ip address search
          token
        else
          token.to_s.split(/[^[:alnum:]\*]+/).select { |w| w.present? && w.length > 1 }
        end
      end.flatten.uniq
    end

    private

    def get_value_for_fields(fields)
      Array(fields).map do |f|
        self.class.normalize_string(
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
