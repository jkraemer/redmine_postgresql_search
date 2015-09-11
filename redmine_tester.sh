#!/bin/bash

#ln -sf $PATH_TO_INSTALL/$NAME_OF_PLUGIN/features/ .
#ln -sf $PATH_TO_INSTALL/$NAME_OF_PLUGIN/spec/ .

bundle exec rake redmine:plugins:test NAME=$NAME_OF_PLUGIN

