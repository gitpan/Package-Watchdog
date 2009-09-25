#!/usr/bin/perl
use strict;
use warnings;
use vars qw/$CLASS/;
use Data::Dumper;

use Test::More tests => 19;

*CLASS = \'Package::Watchdog::List';

use_ok( $CLASS );

isa_ok( my $one = $CLASS->new, $CLASS );

is_deeply(
    [ $one->packages ],
    [],
    "No packages yet"
);

is_deeply(
    $one->subs( 'a' ),
    [],
    "No subs for package"
);

is( $one->push( 'a', [ 'a' .. 'd'] ), $one, "Push returns object" );
is_deeply(
    [ $one->packages ],
    [ 'a' ],
    "package pushed"
);

is_deeply(
    [ sort @{ $one->subs( 'a' )}],
    [ 'a' .. 'd' ],
    "Got correct subs for package"
);

is( $one->push( 'a', [ 'a' .. 'g'] ), $one, "Push returns object" );
is_deeply(
    [ sort @{ $one->subs( 'a' )}],
    [ 'a' .. 'g' ],
    "Got correct subs for package"
);

isa_ok( $one = $CLASS->new( b => [ 'a' .. 'z' ]), $CLASS );
is_deeply(
    [ sort @{ $one->subs( 'b' )}],
    [ 'a' .. 'z' ],
    "Got correct subs for package"
);

is( $one->clear, $one, "clear returns object" );

is_deeply(
    [ $one->packages ],
    [],
    "No packages"
);

is_deeply(
    $one->subs( 'b' ),
    [],
    "No subs for package"
);

$one = $CLASS->new(
    a => [ 'a' .. 'd' ],
    b => [ 'a' .. 'd' ],
    c => [ 'a' .. 'g' ]
);
$one->merge_in(
    $CLASS->new(
        a => [ 'c' .. 'g' ],
        b => [ 'c' .. 'g' ],
        d => [ 'a' .. 'g' ]
    )
);

is_deeply(
    [ sort $one->packages ],
    [ 'a' .. 'd' ],
    "Package list joined"
);

is_deeply(
    [ sort @{ $one->subs( $_ )}],
    [ 'a' .. 'g' ],
    "Correct list for $_"
) for sort $one->packages;
