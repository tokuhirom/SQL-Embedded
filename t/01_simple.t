use strict;
use warnings;
use Test::Requires 'DBD::SQLite';
BEGIN {$ENV{FILTER_SQL_DBI} = 'dbi:SQLite:';};
use SQL::Keyword;
use Test::More tests => 1;
use Data::Dumper;

EXEC CREATE TABLE t (v int not null);;

my $pi = SELECT 3.14 as pi;
is $pi->{pi}, 3.14;

