#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 21;
use Test::Exception;

use Package::Watchdog::Util;

my $CLASS = 'Package::Watchdog::Sub::Watched';

BEGIN {
    use Package::Watchdog::Tracker::Forbid;

    {
        package Temp;
        use strict;
        use warnings;

        our %TESTS = ( new => 0, unforbid => 0 );

        sub new {
            my $class = shift;
            $TESTS{ new } = [ @_ ];
            return bless( ['Temp'], $class );
        }

        sub untrack { $TESTS{ unforbid }++; 1 };
    }

    #Replace Forbid
    *Package::Watchdog::Tracker::Forbid:: = *Temp::;

    is_deeply( Package::Watchdog::Tracker::Forbid->new, ['Temp'], "Overrode forbid" );
}

{
    package Test::Package;
    sub a { 'a' }
    sub b { 'b' }
    sub c { 'c' }
    sub array { qw/a b c/ }
    sub fatal { die("I died") }
    sub params { return @_ }
}

use_ok $CLASS;
can_ok( $CLASS, 'trackers' );

my ( $one, $two );

my $original = copy_sub( 'Test::Package', 'a' );

$one = $CLASS->new( 'Test::Package', 'a', ['WatchA'] );
ok( \&Test::Package::a != $original, "Replaced" );
is( $one->new_sub->(), $original->(), "new_sub returns original sub return value" );

$two = $CLASS->new( 'Test::Package', 'a', ['WatchB'] );
is( $two->new_sub->(), $original->(), "new_sub returns original sub return value" );
ok( \&Test::Package::a != $original, "Still replaced" );

is( $one, $two, "Only one instance of a sub override" );
is_deeply( $one->trackers, [ ['WatchA'], ['WatchB'] ], "Correct Watches" );

$one->remove_tracker( $one->trackers->[0] );
is_deeply( $one->trackers, [ ['WatchB'] ], "Correct Watches" );
ok( \&Test::Package::a != $original, "Still replaced" );

$one->remove_tracker( $one->trackers->[0] );
is_deeply( $one->trackers, [ ], "Correct Watches" );
ok( \&Test::Package::a == $original, "Restored" );

$original = copy_sub( 'Test::Package', 'fatal' );
$one = $CLASS->new( 'Test::Package', 'fatal', ['WatchA'] );
ok( \&Test::Package::fatal != $original, "Replaced" );
dies_ok { Test::Package::fatal() } "overriden function that dies still dies";
like( $@, qr/I died/, "Correct death message" );

$original = copy_sub( 'Test::Package', 'array' );
$one = $CLASS->new( 'Test::Package', 'array', ['WatchA'] );
ok( \&Test::Package::array != $original, "Replaced" );
is_deeply( [ $one->new_sub->() ], [ $original->() ], "new_sub returns original sub return value" );


$Temp::TESTS{ unforbid } = 0,
my $tracker = ['WatchA'];
$one = $CLASS->new( 'Test::Package', 'params', $tracker );
is_deeply( [ $one->new_sub->( ['x'], 'a' .. 'z' )], [['x'], 'a' .. 'z'], "Correct Params" );
use Data::Dumper;
is_deeply(
    $Temp::TESTS{ new },
    [
        $one,
        {
            watches => $one->trackers,
            original_watched => $one->original,
            watched_params => [ ['x'], 'a' .. 'z' ],
            watched => $one,
            watched_package => $one->package,
            watched_sub => $one->sub,
        }
    ],
    "Got correct params hash in forbid class."
);
is( $Temp::TESTS{ unforbid }, 1, "unforbid was run" );
