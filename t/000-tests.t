#!/usr/bin/perl;
use strict;
use warnings;

use vars qw/$tmp $one/;

use Test::More tests => 55;
use Test::Exception;

use_ok 'Package::Watchdog';
Package::Watchdog->import( @Package::Watchdog::EXPORT_OK );

BEGIN {
    package Fake::Parent;
    sub parent { 'parent' };
}

sub redefine_fake_package {
    for my $sub ( all_subs_in_package( 'Fake::Package::' )) {
        no strict 'refs';
        undef( *{'Fake::Package::' . $sub} );
    }
    for my $sub ( all_subs_in_package( 'My::Package::' )) {
        no strict 'refs';
        undef( *{'My::Package::' . $sub} );
    }
    die( "Fake::Package still defined!\n" ) if all_subs_in_package( 'Fake::Package::' );
    {
        eval <<EOT;
            package Fake::Package;

            use base 'Fake::Parent';

            sub realsub { "realsub" };
            sub realsubb { "realsubb" };
            sub test_params { return [\@_] }


            package My::Package;
            sub watch_real { Fake::Package::realsub }
            sub watch_parent { Fake::Package->parent }
            sub watch_innocent { 'innocent' }
            sub watch_params { Fake::Package::test_params( 'a', 'b' ) };
EOT
        die( $@ ) if $@;
    }
}

redefine_fake_package();
is( Fake::Package::realsub(), "realsub", "Original sub works." );

my $FAKE = 'Fake::Package::';


is( copy_original_sub( $FAKE, 'realsub' )->(), 'realsub', "Copy original sub" );
my %original = copy_original_subs( $FAKE, [ 'realsub', 'realsubb' ] );
is( $original{ 'realsub' }->(), "realsub", "realsub copied" );
is( $original{ 'realsubb' }->(), "realsubb", "realsubb copied" );

is_deeply(
    # Turn into hash to prevent order issues.
    { map { $_ => 1 } all_subs_in_package( $FAKE )},
    { realsubb => 1, realsub => 1, test_params => 1 },
    "Found all subs",
);

ok( $tmp = replace_sub( $FAKE, 'realsub', sub { 'replaced' } ), "Replace completes.");
is( $tmp->(), "realsub", "returned original" );
is( Fake::Package::realsub(), "replaced", "replacement was a success." );

redefine_fake_package();
is( Fake::Package::realsub(), "realsub", "Original sub works." );

dies_ok { react(
    forbid => 'a',
    forbid_sub => 'a',
    watch => 'a',
    watched_sub => 'a'
) } "react dies by default";
like( $@, qr/Watchdog: Attempted to use a::a from within a::a\n/, "Correct Message" );

lives_ok { react(
    forbid => 'a',
    forbid_sub => 'a',
    watch => 'a',
    watched_sub => 'a',
    'warn' => 1
) } "react warn lives";

is(
    react(
        forbid => 'a',
        forbid_sub => 'a',
        watch => 'a',
        watched_sub => 'a',
        react => sub {
            is_deeply(
                { @_, react => undef },
                {
                    forbid => 'a',
                    forbid_sub => 'a',
                    watch => 'a',
                    watched_sub => 'a',
                    message => "Watchdog: Attempted to use a::a from within a::a\n",
                    react => undef,
                },
                "reaction sub gets params"
            );
            'reacted'
        }
    ),
    'reacted',
    "Custom Reaction"
);

redefine_fake_package();

is_deeply(
    [
        get_forbidden_subs(
            forbid_subs => [ 'a', 'b' ]
        )
    ],
    [ 'a', 'b' ],
    "Got correct list of subs to forbid w/ list."
);

is_deeply(
    [ sort(
        get_forbidden_subs(
            forbid => 'Fake::Package'
        )
    )],
    [ sort( 'realsub', 'realsubb', 'test_params' )],
    "Got correct list of subs to forbid w/ none specified."
);

is_deeply(
    [ sort(
        get_forbidden_subs(
            forbid_subs => [ 'a', 'b' ],
            forbid => 'Fake::Package',
            forbid_all => 1,
        )
    )],
    [sort( 'a', 'b', 'realsub', 'realsubb', 'test_params' )],
    "Got correct list of subs to forbid w/ all and list."
);

my @params = ( 'a' .. 'b' );
my %baseargs = (
    forbid => 'Fake::Package',
    forbid_pkg => 'Fake::Package::',
    watch => 'My::Package',
    watch_pkg => 'My::Package::',
    watched_sub => 'fakesub',
);


my $sub = gen_watched_sub(
    'fakesub',
    sub {
        is_deeply( [@_], [@params], "Got correct params" );
        return Fake::Package::realsub();
    },
    react => sub {
        my %params = @_;
        return [ 'reacted', $params{ original_sub }->() ]
    },
    %baseargs
);

is( Fake::Package::realsub(), 'realsub', "realsub works" );
is( Fake::Package->parent, 'parent', "Parent works" );
is_deeply( $sub->( @params ), ['reacted', 'realsub' ], "reacted to restricted realsub() call" );
is( Fake::Package::realsub(), 'realsub', "realsub still works" );
is( Fake::Package->parent, 'parent', "Parent still works" );

$sub = gen_watched_sub(
    'fakesub',
    sub {
        is_deeply( [@_], [@params], "Got correct params" );
        return Fake::Package->parent();
    },
    react => sub {
        my %params = @_;
        return [ 'reacted', $params{ original_sub }->() ]
    },
    %baseargs,
    forbid_subs => [ 'parent' ],
    forbid_all => 1,
);

is( Fake::Package::realsub(), 'realsub', "realsub works" );
is( Fake::Package->parent, 'parent', "Parent works" );
is_deeply( $sub->( @params ), ['reacted', 'parent' ], "reacted to restricted parent call" );
is( Fake::Package::realsub(), 'realsub', "realsub still works" );
is( Fake::Package->parent, 'parent', "Parent still works" );

delete $baseargs{ watched_sub };

is( My::Package::watch_real(), 'realsub', 'watch_real works' );
watch_sub(
    'watch_real',
    %baseargs,
    react => sub { 'react' },
);
is( My::Package::watch_real(), 'react', 'watch_real reacts' );

is( My::Package::watch_parent(), 'parent', 'watch_parent works' );
watch_sub(
    'watch_parent',
    %baseargs,
    react => sub { 'react' },
);
is( My::Package::watch_real(), 'react', 'watch_parent reacts' );

redefine_fake_package();

dies_ok { add_watchdog() } 'need minimum arguments';
like( $@, qr/Minimum arguemtns are 'watch' and 'forbid'\n/, "Correct error message" );

dies_ok { add_watchdog( react => 'a' ) } 'react must be a sub';
like( $@, qr/Parameter 'react' must be a coderef!\n/, "Correct error message" );

dies_ok {
    add_watchdog(
        watch => 'My::Package',
        forbid => 'Fake::Package',
        watch_subs => [ 'a' ],
    );
} "can't watch undefined sub";
like( $@, qr/a is not defined in package: My::Package/, "Correct error message" );

add_watchdog(
    watch => 'My::Package',
    forbid => 'Fake::Package',
);

dies_ok { My::Package::watch_real() } "watched sub dies";
like( $@, qr/Watchdog: Attempted to use Fake::Package::realsub from within My::Package::watch_real/, "Correct error message" );

lives_ok { My::Package::watch_parent() } "watch parent lived";
lives_ok { My::Package::watch_innocent() } "watched innocent lives";

redefine_fake_package();
add_watchdog(
    watch => 'My::Package',
    forbid => 'Fake::Package',
    forbid_subs => [ 'parent' ]
);

dies_ok { My::Package::watch_parent() } "watched parent dies";
like( $@, qr/Watchdog: Attempted to use Fake::Package::parent from within My::Package::watch_parent/, "Correct error message" );

lives_ok { My::Package::watch_real() } "unwatched real lived";
lives_ok { My::Package::watch_innocent() } "unwatched innocent lives";

redefine_fake_package();
add_watchdog(
    watch => 'My::Package',
    forbid => 'Fake::Package',
    forbid_subs => [ 'parent' ],
    forbid_all => 1,
);

dies_ok { My::Package::watch_real() } "watched sub dies";
like( $@, qr/Watchdog: Attempted to use Fake::Package::realsub from within My::Package::watch_real/, "Correct error message" );

dies_ok { My::Package::watch_parent() } "watched parent dies";
like( $@, qr/Watchdog: Attempted to use Fake::Package::parent from within My::Package::watch_parent/, "Correct error message" );

lives_ok { My::Package::watch_innocent() } "unwatched innocent lives";

redefine_fake_package();
add_watchdog(
    watch => 'My::Package',
    forbid => 'Fake::Package',
    react => sub {
        my %params = @_;
        if ( $params{ watch_params }->[0] ) {
            return $params{ original_sub }->( @{ $params{ forbid_params }} )
        }
        return 'reacted badly';
    },
);

is( My::Package::watch_params( ), 'reacted badly', "condition bad, react!" );
is_deeply( My::Package::watch_params( 1 ), [ 'a', 'b' ], "condition good, watch approves of access" );



