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

- checkout the plugin to `REDMINE/plugins/redmine_postgresql_search`
- run plugin migrations: `bundle exec rake redmine:plugins:migrate`
- run index rebuild task to initialize the index table: `bundle exec rake redmine)postgresql_search:rebuild_index`


Known Issues
------------

Search on custom fields and journal entries is done separately from search in
issues - therefore a search for 'all words' of the query 'foo bar' will not
find issues with foo in the description and bar in a journal entry or custom
field. The reason is the way Redmine search works (which this plugin does not
change). To make things a little better this plugin indexes the issue's subject
along with each journal, so if you have foo in the subject and bar in a journal
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

You should have received a copy of the GNU General Public License
along with Bold.  If not, see [www.gnu.org/licenses](http://www.gnu.org/licenses/).


