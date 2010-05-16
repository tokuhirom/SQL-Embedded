package SQL::Embedded;
use strict;
use warnings;
use 5.012000;
our $VERSION = '0.01';
use parent qw(Exporter);

use Carp ();
use DBI;
use PadWalker; # TODO: remove deps for PadWalker

require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

our @EXPORT_OK = qw/dbh/;

# entry point from xs
# TODO: もっとコンパイル時にがんばる。
sub _run_exec {
    my ($class, $query) = @_;
    if ($query =~ m{^EXEC\s+(\S+\s+[^;]*)}) {
        my $query = $1;
        my ($suffix, @params) = _quote_vars($query, 2);
        __PACKAGE__->_sql_prepare_exec($suffix, @params);
    } else {
        Carp::confess("fatal error in SQL::Embedded: $query");
    }
}

sub _run_do {
    my ($class, $query) = @_;
    if ($query =~ m{^(INSERT|UPDATE|DELETE|REPLACE)\s+([^;]*)}) {
        my ($op, $query) = ($1, $2);
        my ($suffix, @params) = _quote_vars($query, 2);
        __PACKAGE__->_sql_prepare_exec("$op $suffix", @params);
    } else {
        Carp::confess("fatal error in SQL::Embedded: $query");
    }
}

sub _run_select {
    my ($class, $query) = @_;
    if ($query =~ m{^(?:SELECT(\s+ROW|)(\s+AS\s+HASH|))\s+([^;]*)}) {
        my ($row, $as_hash, $query) = ($1, $2, $3);
        my ($suffix, @params) = _quote_vars($query, 2);
        if ($row) {
            __PACKAGE__->_sql_selectrow($as_hash, "SELECT $suffix", @params);
        } else {
            __PACKAGE__->_sql_selectall($as_hash, "SELECT $suffix", @params);
        }
    } else {
        Carp::confess("fatal error in SQL::Embedded: $query");
    }
}

sub _quote_vars {
    my ($src, $level) = @_;
    my $out = '';
    my $my = PadWalker::peek_my($level); # This is just a hack, silly.
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
        ) or Carp::carp(DBI->errstr);
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

sub _sql_prepare_exec {
    my ($klass, $sql, @params) = @_;
    my $pe = __PACKAGE__->dbh->{PrintError};
    local __PACKAGE__->dbh->{PrintError} = undef;
    my $sth = __PACKAGE__->dbh->prepare($sql);
    unless ($sth) {
        Carp::carp(__PACKAGE__->dbh->errstr) if $pe;
        return;
    }
    unless ($sth->execute(@params)) {
        Carp::carp(__PACKAGE__->dbh->errstr) if $pe;
        return;
    }
    $sth;
}

sub _sql_selectall {
    my ($klass, $as_hash, $sql, @params) = @_;
    my $pe = __PACKAGE__->dbh->{PrintError};
    local __PACKAGE__->dbh->{PrintError} = undef;
    my $rows = __PACKAGE__->dbh->selectall_arrayref(
        $sql,
        $as_hash ? { Slice => {} } : {},
        @params,
    );
    unless ($rows) {
        Carp::carp(__PACKAGE__->dbh->errstr) if $pe;
        return;
    }
    wantarray ? @$rows : $rows->[0];
}

sub _sql_selectrow {
    my ($klass, $as_hash, $sql, @params) = @_;
    my $pe = __PACKAGE__->dbh->{PrintError};
    local __PACKAGE__->dbh->{PrintError} = undef;
    my $rows = __PACKAGE__->dbh->selectall_arrayref(
        $sql,
        $as_hash ? { Slice => {} } : {},
        @params,
    );
    unless ($rows) {
        Carp::carp(__PACKAGE__->dbh->errstr) if $pe;
        return;
    }
    return @$rows ? %{$rows->[0]} : ()
        if $as_hash;
    @$rows ? wantarray ? @{$rows->[0]} : $rows->[0][0] : ();
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
