use inc::Module::Install;
name 'SQL-Keyword';
all_from 'lib/SQL/Keyword.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
