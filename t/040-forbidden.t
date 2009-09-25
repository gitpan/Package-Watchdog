#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 56;
use Test::Exception;
use Package::Watchdog::Util;

my $CLASS = 'Package::Watchdog::Sub::Forbidden';

{
    package Test::Package;
    sub a { 'a' }
    sub b { 'b' }
    sub c { 'c' }
    sub array { qw/a b c/ }
    sub fatal { die("I died") }
    sub params { return @_ }

    package Test::Forbid;
    sub new { bless( {}, shift (@_ ) ) }
    sub watched { Test::Watched->new }
    sub params { ['watched_params'] }

    package Test::Watched;
    sub new { bless( {}, shift (@_ ) ) }
    sub trackers {[Test::Watch->new, Test::Watch->new]};

    package Test::Watch;
    our %RAN;
    my $ID = 1;
    our $REACT = 'die';
    sub new {
        my $class = shift;
        bless( { id => $ID++ }, $class )
    }
    sub id { shift->{ id } }
    sub warn { $RAN{ shift->id }{ 'warn' } = [@_] }
    sub do_react { 
        my $self = shift;
        $REACT->();
        $RAN{ $self->id }{ 'do_react' } = { @_ };
    }
    sub react { $REACT }
}

use_ok $CLASS;
can_ok( $CLASS, 'trackers' );

my ( $one, $two );

my $original = copy_sub( 'Test::Package', 'a' );

$one = $CLASS->new( 'Test::Package', 'a', Test::Forbid->new );
$two = $CLASS->new( 'Test::Package', 'a', Test::Forbid->new );
is( $one, $two, "Only one instance" );
ok( \&Test::Package::a != $original, "Sub replaced" );

dies_ok { $one->new_sub->( 'forbidden_params' )} 'Die when there is a react with die';
like( $@, qr/At least one watch with a die reaction has been triggered/, "correct death message" );

is_deeply(
    \%Test::Watch::RAN,
    {
        1 => { warn => [
            bless( { id => 1 }, 'Test::Watch'),
            {
                forbid => Test::Watched->new,,
                watch => bless( { id => 1 }, 'Test::Watch' ),
                forbidden => $one,
                forbidden_params => [ 'forbidden_params' ],
            },
            'fatal'
        ]},

        2 => { warn => [
            bless( { id => 2 }, 'Test::Watch'),
            {
                forbid => Test::Watched->new,,
                watch => bless( { id => 2 }, 'Test::Watch' ),
                forbidden => $one,
                forbidden_params => [ 'forbidden_params' ],
            },
            'fatal'
        ]},

        3 => { warn => [
            bless( { id => 3 }, 'Test::Watch'),
            {
                forbid => Test::Watched->new,,
                watch => bless( { id => 3 }, 'Test::Watch' ),
                forbidden => $one,
                forbidden_params => [ 'forbidden_params' ],
            },
            'fatal'
        ]},

        4 => { warn => [
            bless( { id => 4 }, 'Test::Watch'),
            {
                forbid => Test::Watched->new,,
                watch => bless( { id => 4 }, 'Test::Watch' ),
                forbidden => $one,
                forbidden_params => [ 'forbidden_params' ],
            },
            'fatal'
        ]},
    },
    "Correct stuff was run."
);

$Test::Watch::REACT = 'warn';
%Test::Watch::RAN = ();
lives_ok { $one->new_sub->( 'forbidden_params' )} 'Live without a die reaction';

is_deeply(
    \%Test::Watch::RAN,
    {
        5 => { warn => [
            bless( { id => 5 }, 'Test::Watch'),
            {
                forbid => Test::Watched->new,,
                watch => bless( { id => 5 }, 'Test::Watch' ),
                forbidden => $one,
                forbidden_params => [ 'forbidden_params' ],
            },
        ]},

        6 => { warn => [
            bless( { id => 6 }, 'Test::Watch'),
            {
                forbid => Test::Watched->new,,
                watch => bless( { id => 6 }, 'Test::Watch' ),
                forbidden => $one,
                forbidden_params => [ 'forbidden_params' ],
            },
        ]},

        7 => { warn => [
            bless( { id => 7 }, 'Test::Watch'),
            {
                forbid => Test::Watched->new,,
                watch => bless( { id => 7 }, 'Test::Watch' ),
                forbidden => $one,
                forbidden_params => [ 'forbidden_params' ],
            },
        ]},

        8 => { warn => [
            bless( { id => 8 }, 'Test::Watch'),
            {
                forbid => Test::Watched->new,,
                watch => bless( { id => 8 }, 'Test::Watch' ),
                forbidden => $one,
                forbidden_params => [ 'forbidden_params' ],
            },
        ]},
    },
    "Correct stuff was run."
);

$Test::Watch::REACT = sub { 1 };
%Test::Watch::RAN = ();
lives_ok { $one->new_sub->( 'forbidden_params' )} 'Live without a die reaction';

is_deeply(
    \%Test::Watch::RAN,
    {
        9 => { do_react => {
            forbid => Test::Watched->new,,
            watch => bless( { id => 9 }, 'Test::Watch' ),
            forbidden => $one,
            forbidden_params => [ 'forbidden_params' ],
        }},

        10 => { do_react => {
            forbid => Test::Watched->new,,
            watch => bless( { id => 10 }, 'Test::Watch' ),
            forbidden => $one,
            forbidden_params => [ 'forbidden_params' ],
        }},

        11 => { do_react => {
            forbid => Test::Watched->new,,
            watch => bless( { id => 11 }, 'Test::Watch' ),
            forbidden => $one,
            forbidden_params => [ 'forbidden_params' ],
        }},

        12 => { do_react => {
            forbid => Test::Watched->new,,
            watch => bless( { id => 12 }, 'Test::Watch' ),
            forbidden => $one,
            forbidden_params => [ 'forbidden_params' ],
        }},
    },
    "Correct stuff was run."
);

$one->restore;
is( \&Test::Package::a, $original, "Sub restored" );

for $Test::Watch::REACT ( 'warn', sub { 1 }) {
    for my $sub ( qw/a b c array params/ ) {
        $original = copy_sub( 'Test::Package', $sub );
        $one = $CLASS->new( 'Test::Package', $sub, Test::Forbid->new );
        no strict 'refs';
        ok( \&{ 'Test::Package::' . $sub } != $original, "Sub replaced" );
        is_deeply( 
            [ &{ 'Test::Package::' . $sub }( 'a', 'b' ) ],
            [ $original->( 'a', 'b' ) ],
            "Original ( $sub() ) Returns on $Test::Watch::REACT"
        );
        $one->restore;
    }
}

for $Test::Watch::REACT ( 'die', sub { die } ) {
    for my $sub ( qw/a b c array params/ ) {
        $original = copy_sub( 'Test::Package', $sub );
        $one = $CLASS->new( 'Test::Package', $sub, Test::Forbid->new );
        no strict 'refs';
        ok( \&{ 'Test::Package::' . $sub } != $original, "Sub replaced" );
        dies_ok { &{ 'Test::Package::' . $sub }( 'a', 'b' ) } "Dies on $Test::Watch::REACT";
        $one->restore;
    }
}

for $Test::Watch::REACT ( 'warn', sub { 1 } ) {
    $original = copy_sub( 'Test::Package', 'fatal' );
    $one = $CLASS->new( 'Test::Package', 'fatal', Test::Forbid->new );
    no strict 'refs';
    ok( \&{ 'Test::Package::' . 'fatal' } != $original, "Sub replaced" );
    dies_ok { &{ 'Test::Package::' . 'fatal' }( 'a', 'b' ) } "Fatal sub still dies on $Test::Watch::REACT";
    $one->restore;
}
