#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 29;
use Data::Dumper;
use vars qw/$CLASS/;

*CLASS = \'Package::Watchdog::Util';

use_ok( $CLASS );

{
    package Test::Package;
    use Package::Watchdog::Util;

    our @ACCESSORS = qw/itemA itemB itemC/;
    build_accessors( @ACCESSORS );

    sub new { return bless( {}, shift )}
    sub inherit { 1 }
}

{
    package Test::Package::A;
    use base 'Test::Package';

    sub x { 'x' };
    sub y { 'y' };
    sub z { 'z' };
}

my $one = Test::Package->new;

is_deeply(
    [ sort( get_all_subs( 'Test::Package::A' ))],
    [qw/ x y z /],
    "get_all_subs returns all subs"
);

is_deeply(
    [ sort( get_all_subs( $CLASS )) ],
    [ sort qw/ build_accessors expand_subs combine_subs get_all_subs copy_sub copy_subs set_sub /],
    "Got correct list of subs"
);

can_ok( $one, $_ ) for get_all_subs( $CLASS );

# Make sure accessors are built.
can_ok( $one, $_ ) for @Test::Package::ACCESSORS;

is_deeply(
    [ sort @{ combine_subs( ['a' .. 'f'], [ 'd' .. 'k'] )} ],
    [ sort 'a' .. 'k' ],
    "Combine to lists of subs, removing duplicates"
);

is_deeply(
    [ sort @{ expand_subs( 'Test::Package::A' ) }],
    [ 'x' .. 'z' ],
    "No subs specified defaults to all"
);

is_deeply(
    [ sort @{ expand_subs( 'Test::Package::A', [] )}],
    [ 'x' .. 'z' ],
    "Empty list defaults to all"
);

is_deeply(
    [ sort @{ expand_subs( 'Test::Package::A', [ '*' ] )} ],
    [ 'x' .. 'z' ],
    "Asterisk pulls in all"
);

is_deeply(
    [ sort @{ expand_subs( 'Test::Package::A', [ 'a', '*' ] )} ],
    [ 'a', 'x' .. 'z' ],
    "Asterisk pulls in all, keep others"
);

is_deeply(
    [ sort @{ expand_subs( 'Test::Package::A', [ 'a' .. 'd' ] )} ],
    [ 'a' .. 'd' ],
    "Only listed"
);

is(
    copy_sub( 'Test::Package::A', 'x' ),
    \&Test::Package::A::x,
    "Copied the sub"
);


is(
    copy_sub( 'Test::Package::A', 'inherit' ),
    \&Test::Package::inherit,
    "Copied the sub from parent"
);

is_deeply(
    { copy_subs( 'Test::Package::A', [ 'x' .. 'z' ] )},
    {
        x => \&Test::Package::A::x,
        y => \&Test::Package::A::y,
        z => \&Test::Package::A::z,
    },
    "Copied all subs"
);

my $original = copy_sub( 'Test::Package::A', 'x' );
is( Test::Package::A::x(), 'x', "Original Sub works" );
is( $original->(), 'x', "Original Sub works" );

set_sub( 'Test::Package::A', 'x', sub { 'a' } );
is( Test::Package::A::x(), 'a', "Original replaced" );

set_sub( 'Test::Package::A', 'x', sub { 'b' } );
is( Test::Package::A::x(), 'b', "Replaced again" );

set_sub( 'Test::Package::A', 'x', $original );
is( Test::Package::A::x(), 'x', "Restored" );

set_sub( 'Test::Package::A', 'x', undef );
ok( ! defined( &Test::Package::A::x ), "no sub anymore");

set_sub( 'Test::Package::A', 'y' );
ok( ! defined( &Test::Package::A::y ), "no sub anymore");


