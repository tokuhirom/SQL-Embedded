use strict;
use warnings;
use Test::Requires 'DBD::SQLite';
BEGIN {$ENV{FILTER_SQL_DBI} = 'dbi:SQLite:';};
use SQL::Embedded;
use Test::More tests => 3;
use Data::Dumper;

my $pi = SELECT 3.14;;
is $pi->[0], 3.14;

EXEC CREATE TABLE t (v int not null);;

note "insert";
my $v = 12345;
INSERT INTO t (v) VALUES ($v);;
INSERT INTO t (v) VALUES (67890);;

my $k = SELECT ROW COUNT(*) FROM t;;
if ($k == 1) {
    print "1 row in table\n";
}

my @h = SELECT AS HASH * FROM t;;
is $h[0]->{v}, 12345;
is $h[1]->{v}, 67890;

