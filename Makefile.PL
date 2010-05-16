use inc::Module::Install;
use 5.012000;
name 'SQL-Embedded';
all_from 'lib/SQL/Embedded.pm';

requires 'DBI';
requires 'Exporter' => 5.63;
requires 'PadWalker' => 1.9;

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
