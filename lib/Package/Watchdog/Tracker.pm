package Package::Watchdog::Tracker;
use strict;
use warnings;
use Carp;
use Package::Watchdog::Util;

#{{{ POD

=pod

=head1 NAME

Package::Watchdog::Tracker - Base class for objects that track overriden subs.

=head1 DESCRIPTION

Base class for objects that track overriden subs.

=head1 ACCESSORS

The following accessors methods are automatically generated using
Package::Watchdog::Util::build_accessors().

=over 4

=item tracked()

List of the Package::Watchdog::Sub objects that are being tracked.

=back

=head1 METHODS

=over 4

=cut

#}}}

my @ACCESSORS = qw/tracked/;
build_accessors( @ACCESSORS );

=item track()

MUST be overriden by a subclass. Called by new to start tracking.

=cut

sub track { die("subclass " . (ref shift( @_ )) . " must override track()" ) }

=item init( $self, @params )

Should be overriden by a subclass. Called by new after object construction.

=cut

sub init {
    my $self = shift;
    return $self;
}

=item new( @params )

All params are passed into init(). Creates a new instance of the tracker, also
runs track() to begin tracking subs..

=cut

sub new {
    my $class = shift;
    my @params = @_;

    my $self = bless({ tracked => [] }, $class );

    $self->init( @params );
    $self->track();

    return $self;
}

=item untrack()

Removes the tracker from all the subs being tracked. This will restore all
tracked subs that are not also tracked by another tracker. Also removes all
references to tracked subs.

Automatically called when the object falls out of scope or is otherwise
destroyed.

=cut

sub untrack {
    my $self = shift;
    $_->remove_tracker( $self ) for @{ $self->tracked };
    $self->tracked( [] );
    return $self;
}

sub DESTROY {
    my $self = shift;
    return unless $self and ref $self and ref $self eq __PACKAGE__;
    $self->untrack() if @{ $self->tracked };
}

1;

__END__

=back

=head1 AUTHORS

=over 4

=item Chad Granum L<chad@opensourcery.com>

=back

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
