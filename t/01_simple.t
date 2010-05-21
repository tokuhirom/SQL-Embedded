use strict;
use warnings;
use Test::Requires 'DBD::SQLite';
BEGIN {$ENV{FILTER_SQL_DBI} = 'dbi:SQLite:';};
use SQL::Embedded;
use Test::More tests => 7;
use Data::Dumper;

my $pi = SELECT 3.14;;
is $pi->[0], 3.14;

EXEC CREATE TABLE t (v int not null);;

note "insert";
my $v = 12345;
INSERT INTO t (v) VALUES ($v);;
INSERT INTO t (v) VALUES (67890);;
INSERT INTO t (v) VALUES (54443);;

my $k = SELECT ROW COUNT(*) FROM t;;
if ($k == 1) {
    print "1 row in table\n";
}

{
    my @h = SELECT AS HASH * FROM t;;
    is $h[0]->{v}, 12345;
    is $h[1]->{v}, 67890;
    is $h[2]->{v}, 54443;
}

{
    my @a = SELECT * FROM t;;
    is $a[0]->[0], 12345;
    is $a[1]->[0], 67890;
    is $a[2]->[0], 54443;
}

{
    my $v = 67890;
    my @a = SELECT * FROM t WHERE v=$v;;
    is scalar(@a), 1;
    is $a[0]->[0], 67890;
}

{
    my @v = (67890, 12345);
    my @a = SELECT * FROM t WHERE v IN @v;;
    is scalar(@a), 1;
    is $a[0]->[0], 67890;
    is $a[1]->[0], 12345;
}

