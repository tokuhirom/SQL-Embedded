package SQL::Embedded;
use strict;
use warnings;
use 5.011001;
our $VERSION = '0.01';

use Carp;
use DBI;
use List::MoreUtils qw(uniq);
use PadWalker; # TODO: remove deps for PadWalker
use base qw(Exporter);

require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

# entry point from xs
# TODO: もっとコンパイル時にがんばる。
sub _run {
    my ($class, $query) = @_;
    if ($query =~ m{^(EXEC\s+(?:\S+)|SELECT(?:\s+ROW|)(?:\s+AS\s+HASH|)|INSERT|UPDATE|DELETE|REPLACE)\s+([^;]*)}) {
        my ($meth, @args) = _to_func($1, $2);
        __PACKAGE__->$meth(@args);
    } else {
        Carp::confess("fatal error in SQL::Embedded: $query");
    }
}

sub _to_func {
    my ($op, $query) = @_;
    $op = uc $op;
    my ($suffix, @params) = _quote_vars($query);
    if ($op =~ /^EXEC\s+(.*)$/) {
        return ('sql_prepare_exec', "$1 $suffix", @params);
    } elsif ($op =~ /^SELECT(\s+ROW|)(\s+AS\s+HASH|)/) {
        my $as_hash = $2 ? 1 : undef;
        if ($1) {
            return ('sql_selectrow', $as_hash, "SELECT $suffix", @params);
        } else {
            return ('sql_selectall', $as_hash, "SELECT $suffix", @params);
        }
    } else {
        return ('sql_prepare_exec', "$op $suffix", @params);
    }
}

sub _quote_vars {
    my $src = shift;
    my $out = '';
    my $my = PadWalker::peek_my(3); # This is just a hack, silly.
    my @params;
    while ($src =~ /(\$|\{)/) {
        $out .= $`;
        $src = $';
        {
            my ($var, $depth) = ($&, $& eq '$' ? 0 : 1);
            while ($src ne '') {
                if ($depth == 0) {
                    last
                        unless $src =~ /^(?:([A-Za-z0-9_]+(?:->|))|([\[\{\(]))/;
                    $src = $';
                    if ($1) {
                        $var .= $1;
                    } else {
                        $var .= $2;
                        $depth++;
                    }
                } else {
                    last unless $src =~ /([\]\}\)](?:->|))/;
                    $src = $';
                    $var .= "$`$1";
                    $depth--;
                }
            }
            $var =~ s/^{(.*)}$/$1/m;
            $out .= '?';
            push @params, ${$my->{$var}};
        }
    }
    $out .= $src;
    return $out, @params;
}

my $dbh;

if ( defined $ENV{FILTER_SQL_DBI} ) {
    $dbh = sub {
        # self rewrite and return
        $dbh = DBI->connect(
            $ENV{FILTER_SQL_DBI},
            $ENV{FILTER_SQL_DBI_USERNAME} || undef,
            $ENV{FILTER_SQL_DBI_PASSWORD} || undef,
        ) or carp DBI->errstr;
    };
}

sub dbh {
    my $klass = shift;
    if (@_) {
        $dbh = shift;
        return;    # returns undef
    }
    ref $dbh eq 'CODE' ? $dbh->() : $dbh;
}

sub sql_prepare_exec {
    my ($klass, $sql, @params) = @_;
    my $pe = __PACKAGE__->dbh->{PrintError};
    local __PACKAGE__->dbh->{PrintError} = undef;
    my $sth = __PACKAGE__->dbh->prepare($sql);
    unless ($sth) {
        carp __PACKAGE__->dbh->errstr if $pe;
        return;
    }
    unless ($sth->execute(@params)) {
        carp __PACKAGE__->dbh->errstr if $pe;
        return;
    }
    $sth;
}

sub sql_selectall {
    my ($klass, $as_hash, $sql, @params) = @_;
    my $pe = __PACKAGE__->dbh->{PrintError};
    local __PACKAGE__->dbh->{PrintError} = undef;
    my $rows = __PACKAGE__->dbh->selectall_arrayref(
        $sql,
        $as_hash ? { Slice => {} } : {},
        @params,
    );
    unless ($rows) {
        carp __PACKAGE__->dbh->errstr if $pe;
        return;
    }
    wantarray ? @$rows : $rows->[0];
}

sub sql_selectrow {
    my ($klass, $as_hash, $sql, @params) = @_;
    my $pe = __PACKAGE__->dbh->{PrintError};
    local __PACKAGE__->dbh->{PrintError} = undef;
    my $rows = __PACKAGE__->dbh->selectall_arrayref(
        $sql,
        $as_hash ? { Slice => {} } : {},
        @params,
    );
    unless ($rows) {
        carp __PACKAGE__->dbh->errstr if $pe;
        return;
    }
    return @$rows ? %{$rows->[0]} : ()
        if $as_hash;
    @$rows ? wantarray ? @{$rows->[0]} : $rows->[0][0] : ();
}

sub quote {
    my ( $klass, $v ) = @_;
    __PACKAGE__->dbh->quote($v);
}

sub mysql_insert_id {
    __PACKAGE__->dbh->{mysql_insertid};
}


1;
__END__

=head1 NAME

SQL::Embedded -

=head1 SYNOPSIS

  use SQL::Embedded;

=head1 DESCRIPTION

SQL::Embedded is

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom ASDF gmail DOT comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
