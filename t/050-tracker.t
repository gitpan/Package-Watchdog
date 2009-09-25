#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 14;
use Test::Exception;

my $CLASS = 'Package::Watchdog::Tracker';

use_ok( $CLASS );

#{{{ Tracker
{
    package My::Tracker;
    use strict;
    use warnings;

    use Package::Watchdog::Util;

    my @ACCESSORS = qw/to_track/;
    build_accessors( @ACCESSORS );

    use base 'Package::Watchdog::Tracker';

    sub init {
        my $self = shift;
        $self->to_track( [ @_ ] );
        return $self;
    }

    sub track {
        my $self = shift;
        push( @{ $self->tracked }, My::Trackable->new( $_, $self )) for @{ $self->to_track };
        return $self;
    }
}
#}}}
#{{{ Trackable
{
    package My::Trackable;
    use strict;
    use warnings;

    use Package::Watchdog::Util;

    my @ACCESSORS = qw/trackers data/;
    build_accessors( @ACCESSORS );

    sub new {
        my $class = shift;
        my ( $data, $tracker ) = @_;
        my $self = bless({ data => $data, trackers => [ $tracker ]}, $class );
        return $self;
    }

    sub remove_tracker {
        my $self = shift;
        my ( $tracker ) = @_;
        $self->trackers([ grep { $_ and $tracker and $_ != $tracker } @{ $self->trackers }]);
        return $self;
    }
}
#}}}

dies_ok { $CLASS->track } 'track needs to be overriden';
dies_ok { $CLASS->new } 'track needs to be overriden';

can_ok( $CLASS, 'tracked' );

isa_ok( my $one = My::Tracker->new( 'a', 'b' ), $CLASS );

is_deeply( $one->to_track, [ 'a', 'b' ], "Test class constructed properly" );

is( @{ $one->tracked }, 2, "Trackable's for both 'a' and 'b'" );
isa_ok( $_, 'My::Trackable' ) for @{ $one->tracked };
is_deeply( $_->trackers, [ $one ], "Trackables have the tracker" ) for @{ $one->tracked };

my $trackables = $one->tracked;

$one->untrack;

is_deeply( $_->trackers, [], "Trackables no longer have the tracker" ) for @$trackables;
is_deeply( $one->tracked, [], "Not tracking anything" );
