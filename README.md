Redmine PostgreSQL Search [![Build Status](https://travis-ci.org/jkraemer/redmine_postgresql_search.svg?branch=master)](https://travis-ci.org/jkraemer/redmine_postgresql_search)
=========================

Makes Redmine search use the advanced PostgreSQL fulltext index capabilities.

Why?
----

### Relevance of results

Plain Redmine does simple `LIKE` queries and therefore lacks any relevancy
measurement. Lacking a better option, search results are sorted by modification
date. Especially in large setups with big result sets this leads to a bad user
experience, since they only find what they are looking for on the first page if
it has a recent modification date.

With this plugin, Redmine will rank more relevant hits higher, i.e.  a match in
an issue title ranks higher than one in the description, even if the latter
issue is more recent.

### Performance

With it's fine grained permissions and lots of different entities to search,
Redmine search is a complicated beast. A single search easily results in
multiple SQL queries, each using `LIKE` statements to do the matching. This
plugin replaces each of these LIKEs with a fast query against a dedicated
FulltextIndex model, which is kept up to date through `after_commit` hooks.

So there is a slight penalty at record addition / modification time when the
data gets indexed, but in general this will not be noticeable by users.

Installation
------------

Follow the generic [Redmine plugin installation
instructions](https://redmine.org/projects/redmine/wiki/Plugins), but with a
twist for Redmine installations with mostly non-english content:

_Before_ running the plugin migrations, set the `language` environment variable
to the language your Redmine content (mostly) is in. The `setup_tsearch`
migration uses this to create a matching [text search
configuration](http://www.postgresql.org/docs/current/static/textsearch-intro.html#TEXTSEARCH-INTRO-CONFIGURATIONS)
in your Redmine database.  This directly influences search results quality so
don't just skip this (unless your language would be english, this is the
default used by the migration).

To find out which languages are supported by your PostgreSQL installation, run
`\dF` in a shell:

    redmine=# \dF
                    List of text search configurations
       Schema   |     Name     |              Description
    ------------+--------------+---------------------------------------
     pg_catalog | danish       | configuration for danish language
     pg_catalog | dutch        | configuration for dutch language
     pg_catalog | english      | configuration for english language
     pg_catalog | finnish      | configuration for finnish language
     pg_catalog | french       | configuration for french language
     pg_catalog | german       | configuration for german language
     pg_catalog | hungarian    | configuration for hungarian language
     pg_catalog | italian      | configuration for italian language
     pg_catalog | norwegian    | configuration for norwegian language
     pg_catalog | portuguese   | configuration for portuguese language
     pg_catalog | romanian     | configuration for romanian language
     pg_catalog | russian      | configuration for russian language
     pg_catalog | simple       | simple configuration
     pg_catalog | spanish      | configuration for spanish language
     pg_catalog | swedish      | configuration for swedish language
     pg_catalog | turkish      | configuration for turkish language

So if your Redmine installation has mostly German text, you would run

    language=german bundle exec rake redmine:plugins:migrate

after unpacking the plugin to `YOUR_REDMINE/plugins/redmine_postgresql_search`.

After running the migrations, make sure to index all your existing content by running

    bundle exec rake redmine_postgresql_search:rebuild_index


In case you want to learn more about the internals of PostgreSQL full text
search - I found these two articles quite helpful:

- http://shisaa.jp/postset/postgresql-full-text-search-part-2.html
- http://linuxgazette.net/164/sephton.html


Known Issues
------------

Please report any issues not mentioned here [on
Github](https://github.com/jkraemer/redmine_postgresql_search/issues).


## Result Completeness

Search on custom fields and journal entries is done separately from search in
issues - therefore a search for all words of the query `foo bar` will not find
issues with `foo` in the description and `bar` in a journal entry or custom
field.  The reason is the way Redmine search works on a fundamental level.  To
make things a little better this plugin indexes the issue's subject along with
each journal, so if you have `foo` in the subject and `bar` in a journal entry
you will find the issue.



License
-------

Copyright (C) 2015 Jens Krämer <jk@jkraemer.net>

The Postgresql Search plugin for Redmine is free software: you can redistribute
it and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The Postgresql Search plugin for Redmine is distributed in the hope that it
will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
Public License for more details.

You should have received a copy of the GNU General Public License along with
the plugin. If not, see [www.gnu.org/licenses](http://www.gnu.org/licenses/).


