use strict;
use warnings;
use Test::Requires 'DBD::SQLite';
BEGIN {$ENV{FILTER_SQL_DBI} = 'dbi:SQLite:';};
use SQL::Embedded;
use Test::More tests => 2;
use Data::Dumper;

my $pi = SELECT 3.14;;
is $pi->[0], 3.14;

EXEC CREATE TABLE t (v int not null);;

my $v = 12345;
INSERT INTO t (v) VALUES ($v);;
INSERT INTO t (v) VALUES (67890);;

if (SELECT ROW COUNT(*) FROM t; == 2) {
    ok 1, "if-stmt works";
} else {
    fail "if-stmt doesn't works";
}

