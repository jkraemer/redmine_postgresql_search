DROP FUNCTION IF EXISTS update_search_data (search_config regconfig, word_config regconfig, id integer, texts text [ ], weights char [ ]);
DROP FUNCTION IF EXISTS update_wordlist (previous_words text [ ], current_words text [ ]);
DROP FUNCTION IF EXISTS texts_to_tsvector (search_config regconfig, texts text [ ], weights char [ ]);
DROP FUNCTION IF EXISTS extract_words (text text, word_config regconfig);
