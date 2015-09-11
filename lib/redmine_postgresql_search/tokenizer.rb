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

    # TODO at the moment this breaks phrase search
    def self.sanitize_query_tokens(tokens)
      Array(tokens).map do |token|
        token.to_s.split(/[^[:alnum:]\*]+/).reject(&:blank?)
      end.flatten
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
