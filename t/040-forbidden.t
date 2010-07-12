#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Package::Watchdog::Util;

my $CLASS = 'Package::Watchdog::Sub::Forbidden';
our @STACK;

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
    sub stack { \@main::STACK }

    package Test::Watched;
    sub new { bless( {}, shift (@_ ) ) }

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
    sub stack { \@main::STACK }
}

use_ok $CLASS;

my ( $one, $two );

my $original = copy_sub( 'Test::Package', 'a' );

$one = $CLASS->new( 'Test::Package', 'a', Test::Forbid->new );
$two = $CLASS->new( 'Test::Package', 'a', Test::Forbid->new );
is( $one, $two, "Only one instance" );
ok( \&Test::Package::a != $original, "Sub replaced" );

push @STACK => [ Test::Watch->new(), { watched => Test::Watched->new } ];
dies_ok { $one->new_sub->( 'forbidden_params' )} 'Die when there is a react with die';
like(
    $@,
    qr/At least one watch with a die reaction has been triggered/,
    "correct death message"
);

is_deeply(
    \%Test::Watch::RAN,
    {
        1 => { warn => [
            $STACK[0]->[0],
            {
                watch => $STACK[0]->[0],
                watched => $STACK[0]->[1]->{ watched },
                forbid => Test::Watched->new,
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
        1 => { warn => [
            $STACK[0]->[0],
            {
                watch => $STACK[0]->[0],
                watched => $STACK[0]->[1]->{ watched },
                forbid => Test::Watched->new,
                forbidden => $one,
                forbidden_params => [ 'forbidden_params' ],
            },
            undef,
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
        1 => { do_react => {
            watch => $STACK[0]->[0],
            watched => $STACK[0]->[1]->{ watched },
            forbid => Test::Watched->new,,
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

done_testing;
