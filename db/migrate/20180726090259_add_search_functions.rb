class AddSearchFunctions < Rails.version < '5.2' ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def up
    execute <<-SQL
  CREATE OR REPLACE FUNCTION extract_words (text text, word_config regconfig)
      RETURNS SETOF text
      LANGUAGE plpgsql STABLE
  AS $f$
  BEGIN
      RETURN QUERY
      SELECT
          word
      FROM
          ts_stat(format('SELECT to_tsvector(%s, %s) ', quote_literal(word_config), quote_literal(text)))
      WHERE
          length(word) > 4;
  END;
  $f$;

  CREATE OR REPLACE FUNCTION increase_occurence_count (words text [ ])
      RETURNS void
      LANGUAGE plpgsql
  AS $f$
  BEGIN
      INSERT INTO fulltext_words
      SELECT
          unnest(words), 1 ON CONFLICT (word)
          DO
          UPDATE
          SET
              ndoc = fulltext_words.ndoc + 1;
  END;
  $f$;

  CREATE OR REPLACE FUNCTION decrease_occurence_count (words text [ ])
      RETURNS void
      LANGUAGE plpgsql
  AS $f$
  BEGIN
      UPDATE
          fulltext_words
      SET
          ndoc = ndoc - 1
      WHERE
          word IN (
              SELECT
                  unnest(decrease_occurence_count.words));
  END;
  $f$;

  CREATE OR REPLACE FUNCTION update_wordlist (previous_words text [ ], current_words text [ ])
      RETURNS void
      LANGUAGE plpgsql
  AS $f$
  DECLARE
      added_words text [ ];
      removed_words text [ ];
  BEGIN
      added_words := ARRAY (
          SELECT
              unnest(current_words)
          EXCEPT
          SELECT
              unnest(previous_words));
      removed_words := ARRAY (
          SELECT
              unnest(previous_words)
          EXCEPT
          SELECT
              unnest(current_words));
      -- RAISE NOTICE 'added words: %', added_words;
      -- RAISE NOTICE 'removed words: %', removed_words;
      RAISE NOTICE 'added words: %', array_length(added_words, 1);
      RAISE NOTICE 'removed words: %', array_length(removed_words, 1);
      PERFORM
          decrease_occurence_count (removed_words);
      PERFORM
          increase_occurence_count (added_words);
  END;
  $f$;

  CREATE OR REPLACE FUNCTION texts_to_tsvector (search_config regconfig, texts text [ ], weights char [ ])
      RETURNS tsvector
      LANGUAGE plpgsql STABLE
  AS $f$
  DECLARE
      tsvector tsvector = '';
      text text;
      weight "char";
  BEGIN
      FOR text,
      weight IN
      SELECT
          unnest(texts),
          unnest(weights)
          LOOP
              tsvector := tsvector || setweight(to_tsvector(search_config::regconfig, quote_literal(text)), weight);
          END LOOP;
      RETURN tsvector;
  END;
  $f$;

  CREATE OR REPLACE FUNCTION update_search_data (search_config regconfig, word_config regconfig, index_id integer, texts text [ ], weights char [ ])
      RETURNS void
      LANGUAGE plpgsql
  AS $f$
  DECLARE
      previous_words text [ ];
      current_words text [ ];
  BEGIN
      UPDATE
          fulltext_indices
      SET
          tsv = texts_to_tsvector (search_config,
              texts,
              weights)
      WHERE
          id = index_id;
      SELECT
          words INTO previous_words
      FROM
          fulltext_indices
      WHERE
          id = index_id;
      current_words := ARRAY (
          SELECT
              extract_words (array_to_string(texts, ' '),
                  word_config));
      PERFORM
          update_wordlist (previous_words,
              current_words);
      UPDATE
          fulltext_indices
      SET
          words = current_words
      WHERE
          id = index_id;
  END;
  $f$;
    SQL
  end

  def down
    execute <<-SQL
  DROP FUNCTION IF EXISTS update_search_data (search_config regconfig, word_config regconfig, id integer, texts text [ ], weights char [ ]);
  DROP FUNCTION IF EXISTS update_wordlist (previous_words text [ ], current_words text [ ]);
  DROP FUNCTION IF EXISTS texts_to_tsvector (search_config regconfig, texts text [ ], weights char [ ]);
  DROP FUNCTION IF EXISTS extract_words (text text, word_config regconfig);
    SQL
  end
end
