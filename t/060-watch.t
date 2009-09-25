#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 25;
use Test::Exception;
use Test::Warn;
use Package::Watchdog::List;

my $CLASS = 'Package::Watchdog::Tracker::Watch';

{
    package Fake;
    use strict;
    use warnings;

    sub a { 'a' }
    sub b { 'b' }
}

use_ok( $CLASS );
can_ok( $CLASS, qw/subs package forbid react name/ );

dies_ok { $CLASS->new() } 'Must specify a package to watch';
like( $@, qr/Must specify a package to watch/, "Correct message" );

dies_ok { $CLASS->new( package => 'fake' ) } 'Must provide a Package\::Watchdog\::List for param \'forbid\'';
like( $@, qr/Must provide a Package\::Watchdog\::List for param 'forbid'/, "Correct message" );

dies_ok {
    $CLASS->new(
        package => 'fake',
        forbid => Package::Watchdog::List->new(),
        react => 'xxx'
    )
} 'Param \'react\' must be either \'die\', \'warn\', or a coderef.';
like( $@, qr/Param 'react' must be either 'die', 'warn', or a coderef./, "Correct message" );

my $one = $CLASS->new(
    package => 'Fake',
    forbid => Package::Watchdog::List->new(),
);

is( $one->react, 'die', "Default react is die" );
is_deeply( $one->subs, [ 'a', 'b' ], "all subs for Fake package");
is( $one->package, 'Fake', "Saved package" );
isa_ok( $one->forbid, 'Package::Watchdog::List' );

is( @{ $one->tracked }, 2, "Tracking 2 subs" );
isa_ok( $_, 'Package::Watchdog::Sub::Watched' ) for @{ $one->tracked };

is_deeply( $_->trackers, [ $one ], "Object is a tracker" ) for @{ $one->tracked };

my $tracked = $one->tracked;

$one->untrack;

is( @{ $one->tracked }, 0, "Tracking 0 subs" );
is_deeply( $_->trackers, [], "Object is not a tracker" ) for @$tracked;

$one = $CLASS->new(
    package => 'My::Package',
    subs => [ 'a', 'b' ],
    forbid => Package::Watchdog::List->new(
        'Package::A' => [],
        'Package::B' => [],
        'Package::C' => [],
    ),
    react => 'die',
);

is( $one->name, 'My::Package[a,b]-[Package::A,Package::B,Package::C]=die', "Somewhat useful name generated" );

{
    package Fake::Forbidden;
    use strict;
    use warnings;

    sub new { bless( {}, shift (@_ ) ) }
    sub sub { 'ForbiddenSub' }
    sub package { 'Forbidden::Package' }

    package Fake::Forbid;
    use strict;
    use warnings;

    sub new { bless( {}, shift (@_ ) ) }
    sub watched { Fake::Watched->new }
    sub params {[ 'a' .. 'z' ]}

    package Fake::Watched;
    use strict;
    use warnings;

    sub new { bless( {}, shift (@_ ) ) }
    sub sub { 'WatchedSub' }
    sub package { 'Watched::Package' }
}

is(
    $one->gen_warning({ forbidden => Fake::Forbidden->new, forbid => Fake::Forbid->new }),
    'Watchdog warning: sub Forbidden::Package::ForbiddenSub was called from within Watched::Package::WatchedSub - '
        . $one->name,
    "Generated useful warning",
);

is(
    $one->gen_warning({ forbidden => Fake::Forbidden->new, forbid => Fake::Forbid->new }, 'fatal'),
    'Watchdog fatal: sub Forbidden::Package::ForbiddenSub was called from within Watched::Package::WatchedSub - '
        . $one->name,
    "Generated useful warning - leveled",
);

warnings_like { $one->warn({ forbidden => Fake::Forbidden->new, forbid => Fake::Forbid->new }) } [ qr/Watchdog warning: sub Forbidden::Package::ForbiddenSub was called from within Watched::Package::WatchedSub/ ], "warns properly";

my %params;

$one = $CLASS->new(
    package => 'My::Package',
    subs => [ 'a', 'b' ],
    forbid => Package::Watchdog::List->new(
        'Package::A' => [],
        'Package::B' => [],
        'Package::C' => [],
    ),
    react => sub { %params = @_ },
);

my $tmp = Fake::Forbid->new;
$one->do_react( forbid => $tmp, x => 'x', y => 'y' );

is_deeply(
    \%params,
    {
        forbid => $tmp,
        x => 'x',
        y => 'y',
        watch => $one,
        watched => $tmp->watched,
        watched_params => $tmp->params,
    },
    "Proper params are passed to react sub"
);
