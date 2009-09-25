#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 16;
use Test::Exception;
use Package::Watchdog::Tracker::Watch;
use Package::Watchdog::Sub::Watched;
use Package::Watchdog::List;

my $CLASS = 'Package::Watchdog::Tracker::Forbid';

{
    package Fake::Watch;
    use strict;
    use warnings;

    sub x { 'x' }
    sub y { 'y' }

    package Fake::Forbid::A;
    use strict;
    use warnings;

    sub a { 'a' }

    package Fake::Forbid::B;
    use strict;
    use warnings;

    sub b { 'b' }
    sub c { 'c' }
}

use_ok( $CLASS );
can_ok( $CLASS, qw/params watched/ );



my $watch = Package::Watchdog::Tracker::Watch->new(
    package => 'Fake::Watch',
    subs => [ 'x' ],
    forbid => Package::Watchdog::List->new(
        'Fake::Forbid::A' => [ 'a' ]
    ),
);

my $watch2 = Package::Watchdog::Tracker::Watch->new(
    package => 'Fake::Watch',
    forbid => Package::Watchdog::List->new(
        'Fake::Forbid::B' => [ '*' ]
    ),
);

my $watched = $watch->tracked->[0];
my $one = $CLASS->new($watched, [ 'a' .. 'z' ]);

is_deeply( $one->watched, $watched, "Watched was saved" );
is_deeply( $one->params, [ 'a' .. 'z' ], "Params was saved" );

is( @{ $one->watched->trackers }, 2, "2 watchers" );
is( @{ $one->tracked }, 3, "Tracking 3 forbidden subs" );
isa_ok( $_, "Package::Watchdog::Sub::Forbidden" ) for @{ $one->tracked };
is_deeply( $_->trackers, [ $one ], "Object is a tracker" ) for @{ $one->tracked };

my $tracked = $one->tracked;

$one->untrack;

is_deeply( $one->tracked, [], "Tracked list cleared" );
is_deeply( $_->trackers, [], "Object is no longer a tracker" ) for @$tracked;
