package Package::Watchdog;
use strict;
use warnings;
use Carp;
use Package::Watchdog::List;
use Package::Watchdog::Tracker::Watch;
use Package::Watchdog::Util;

#{{{ POD

=pod

=head1 NAME

Package::Watchdog - Forbid subs in one package from accessing subs in another package, directly or otherwise.

=head1 DESCRIPTION

A watchdog object will 'watch' several packages and subs in their namespaces.
The watchdog has a list of packages and their subs that should be considered
off-limits to the packages being watched. If their is a violation, ie a watched
package sub accesses a forbidden package sub, the watchdog will react. A
watchdog can react by dying, issuing a warning, or running a custom subroutine.

=head1 SYNOPSYS

First we set some example packages:

    {
        # This packages subs will be forbidden
        package My::Package;
        use strict;
        use warnings;
        sub a { 'a' };
        sub b { 'b' };
        sub c { 'c' };

        # The next packages will be watches for violations
        # Note, every one calls a sub in the forbidden package

        package My::WatchA;
        use strict;
        use warnings;
        sub a { My::Package::a() };
        sub b { My::Package::a() };
        sub c { My::Package::a() };
        # ignore for now.
        sub d { My::Package::d() };

        package My::WatchB;
        use strict;
        use warnings;
        sub a { My::Package::a() };
        sub b { My::Package::a() };
        sub c { My::Package::a() };
    }

Now we set up the watchdog:

    $wd = Package::Watchdog->new()
        # All subs in My::WatchA are included in the watch since none are specified
        ->watch( package => 'My::WatchA', name => 'watch a' )
        # Only sub a() in My::WatchB will be included in the watch
        ->watch( package => 'My::WatchB', subs => [ 'a' ], name => 'watch b')
        # A second watcher will be placed on My::WatchA sub a()
        ->watch( package => 'My::WatchA', subs => [ 'a' ], name => 'watch c')
        # All subs will be forbidden if none are listed.
        ->forbid( 'My::Package' );

The subs in My::Package are only forbidden to My::WatchA and My::WatchB, when
called outside those packages My::Package susb still work normally.

The following will all die after a warning:

    My::WatchA::a();
    My::WatchA::b();
    My::WatchA::c();

The following still work:

    My::Package::a();
    My::Package::b();
    My::Package::c();

This will die with a warning:

    *My::Package::d = sub { 'd' };
    My::WatchA::d();

Package::Watchdog was smart enough to detect that a new sub was defined in
My::Package. Since no subs were listed all will be included, event he new one.

*CAVEAT* if we had defined the new sub in My::Package after calling
My::WatchA::d then it will not be found in time to be forbidden. For example,
this will not die or provide a warninig:

    #Works fine :-(
    *My::WatchA::d = sub {
        *My::Package::d = sub { 'd' };
        My::Package::d();
    };
    My::WatchA::d();

You can make the watchdog bark, but not bite. If you create the watchdog with
'warn' as a parameter then violations will generate warnings, but will not die.

    my $wd = Package::Watchdog->new( 'warn' );

You can also create a custom reaction to violations.  Please see the custom
reaction section for more information. The original sub will be run after the
custom reaction unless the custom reaction dies.

    # Custom reaction
    my $wd = Package::Watchdog->new( sub { ... } );

You can also provide different reactions for each watch:

    $wd = Package::Watchdog->new()
        ->watch( package => 'My::WatchA', react => 'warn' )
        ->watch( package => 'My::WatchB', react => 'die' )
        ->watch( package => 'My::WatchC', react => sub { ... } );

The watchdog can be killed by calling the kill() method. Alternately it can fall out of scope and be destroyed. The following are all ways to kill the watchdog:

    $wd->kill();
    $wd = undef; #When no other references to the watchdog exist.


    {
        my $wd2 = Package::Watchdog->new();
        # $wd2 is in effect
    }
    # $wd2 is dead.

=head1 CUSTOM REACTIONS

Custom reactions are anonymous subs.

    my $react = sub {
        my %params = @_;
        ... do stuff ...
    };

The custom react sub will be passed the following:

    %params = (
        watch => Package::Watchdog::Tracker::Watch, # The watch that was triggered
        watched => Package::Watchdog::Sub::Watched, # The class that manages the watched sub that was called.
        watched_params => [ Params with which the watched sub was called ],
        forbid => Package::Watchdog::Tracker::Forbid, # The class that manages the forbidden subs.
        forbidden => Package::Watchdog::Sub::Forbidden, # The class that manages the forbidden sub that was called.
        forbidden_params => [ Params with which the forbidden sub was called ],
    );

It is safe to die within your custom reaction. The forbidden sub will run normally unless the custom reaction dies.

=head1 NOTES AND CAVEATS

=over 4

=item Inherited subs

When Package::Watchdog obtains a list of all subs in a package, inherited subs
are not included.

=item Subs defined after a watched sub is called.

Package::Watchdog works by overriding watched subs in such a way that when
called they override forbidden subs. Once the forbidden subs are overriden the
original watched sub is called and allowed to continue as normal.

The forbidden subs are all overriden at once the moment you call a watched sub.
As a result new subs added to the forbidden package afterthe watched sub is
called will not be forbidden.

=item Subs redefined after a watched sub is called.

When the watched sub exits all forbidden subs will be returned to their
pre-watched state. If you override a sub manually inside a watched sub, your
override will be reset when the watched sub returns.

=back

=head1 ACCESSORS

The following accessors methods are automatically generated using
Package::Watchdog::Util::build_accessors(). These are listed purely for
documentation purposes. They are not for use by the user.

=over 4

=item react()

=item watches()

=item forbids()

=back

=head1 METHODS

Unless otherwise specified methods all return the watchdog object and are chainable.

=over 4

=cut

#}}}

our $VERSION = 0.08;

my @ACCESSORS = qw/react watches forbids/;
build_accessors( @ACCESSORS );

=item new( $reaction )

Create a new watchdog object.

$reaction must be one of 'die', 'warn', or a coderef (sub { ... })

=cut

sub new {
    my $class = shift;
    my ( $react ) = @_;

    die( "React must be one of 'die', 'warn', or a coderef." )
        if $react && $react ne 'die'
                  && $react ne 'warn'
                  && ( ref $react && ref $react ne 'CODE' );

    my $self = bless(
        {
            react => $react || 'die',
            watches => [],
            forbids => Package::Watchdog::List->new(),
        },
        $class
    );

    return $self;
}

=item watch( package => $package, subs => [ ... ], react => $react, name => $name )

Start watching the specified subs in the specified package. If subs is omited
or contains '*' then all package subs will be watched.

=cut

sub watch {
    my $self = shift;
    my $watch = Package::Watchdog::Tracker::Watch->new(
        react => $self->react,
        @_,
        forbid => $self->forbids,
    );
    push @{ $self->watches } => $watch;
    return $self;
}

=item forbid( $package, $subs )

Forbid the specified subs in the specified package. The second argument should
be an arrayref.

=cut

sub forbid {
    my $self = shift;
    my ( $package, $subs, $override_proto ) = @_;
    $self->forbids->push( $package, $subs, $override_proto );
    return $self;
}

=item unwatch()

*Unimplemented.*

=cut

sub unwatch {
    my $self = shift;
    die( "Not yet implemented." );
    return $self; #I know pointless atm.
}

=item unforbid()

*Unimplemented.*

=cut

sub unforbid {
    my $self = shift;
    die( "Not yet implemented." );
    return $self; #I know pointless atm.
}

=item kill()

Will make the watchdog inefective, removes all watches and forbids.

=cut

sub kill {
    my $self = shift;
    $_->untrack for grep { $_ } @{ $self->watches };
    $self->forbids->clear if $self->forbids;
    return $self;
}

sub DESTROY {
    shift->kill();
}

1;

__END__

=back

=head1 AUTHORS

Chad Granum L<chad@opensourcery.com>

=head1 COPYRIGHT

Copyright (C) 2009 OpenSourcery, LLC

Package-Watchdog is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your option) any
later version.

Package-Watchdog is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
Street, Fifth Floor, Boston, MA 02110-1301 USA.

Package-Watchdog is packaged with a copy of the GNU General Public License.
Please see docs/COPYING in this distribution.
