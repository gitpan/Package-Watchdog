#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use Test::Exception;

use Package::Watchdog::Util;

my $CLASS = 'Package::Watchdog::Sub::Watched';
our @stack;

{
    package Test::Package;
    sub a { 'a' }
    sub b { 'b' }
    sub c { 'c' }
    sub array { qw/a b c/ }
    sub fatal { die("I died") }
    sub params { return @_ }
    sub get_stack { return [ @main::stack ]}
}

use_ok $CLASS;

my ( $one, $two );

my $original = copy_sub( 'Test::Package', 'a' );

$one = $CLASS->new(
    'Test::Package',
    'a',
    bless(
        { name => 'a', stack => \@stack },
        'Package::Watchdog::Tracker'
    )
);
ok( \&Test::Package::a != $original, "Replaced" );
is( $one->new_sub->(), $original->(), "new_sub returns original sub return value" );

$two = $CLASS->new(
    'Test::Package',
    'a',
    bless(
        { name => 'b', stack => \@stack },
        'Package::Watchdog::Tracker'
    )
);
is( $two->new_sub->(), $original->(), "new_sub returns original sub return value" );
ok( \&Test::Package::a != $original, "Still replaced" );

is( $one, $two, "Only one instance of a sub override" );

$original = copy_sub( 'Test::Package', 'fatal' );
$one = $CLASS->new(
    'Test::Package',
    'fatal',
    bless(
        { name => 'a', stack => \@stack },
        'Package::Watchdog::Tracker'
    )
);
ok( \&Test::Package::fatal != $original, "Replaced" );
dies_ok { Test::Package::fatal() } "overriden function that dies still dies";
like( $@, qr/I died/, "Correct death message" );

$original = copy_sub( 'Test::Package', 'array' );
$one = $CLASS->new(
    'Test::Package',
    'array',
    bless(
        { name => 'a', stack => \@stack },
        'Package::Watchdog::Tracker'
    )
);
ok( \&Test::Package::array != $original, "Replaced" );
is_deeply( [ $one->new_sub->() ], [ $original->() ], "new_sub returns original sub return value" );

my $tracker = bless(
    { name => 'a', stack => \@stack },
    'Package::Watchdog::Tracker'
);
$one = $CLASS->new( 'Test::Package', 'params', $tracker );
is_deeply(
    [ $one->new_sub->( ['x'], 'a' .. 'z' )],
    [['x'], 'a' .. 'z'],
    "Correct Return"
);

done_testing;
