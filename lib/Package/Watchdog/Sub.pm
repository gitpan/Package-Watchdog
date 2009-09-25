package Package::Watchdog::Sub;
use strict;
use warnings;
use Package::Watchdog::Util;
use Carp;

#{{{ POD

=pod

=head1 NAME

Package::Watchdog::Sub - Base object for managing overriden subroutines.

=head1 DESCRIPTION

Only once instance of a class based on this one can exist per package and sub.
Each instance manages exactly one sub. When the instance is created it
overrides the subroutine with a new one. The instance will expire when the
original sub is restored.

=head1 ACCESSORS

The following accessors methods are automatically generated using
Package::Watchdog::Util::build_accessors().

=over 4

=item package()

Name of the package the sub is in.

=item sub()

Name of the sub being managed.

=item trackers()

List of the Package::Watchdog::Tracker objects that are tracking the sub.

=back

=head1 METHODS

=over 4

=cut

#}}}

my @ACCESSORS = qw/package sub original trackers/;
build_accessors( @ACCESSORS );

=item _instance( $class, $package, $sub )

Get/Set the current instance of $class built for $package::$sub. FOR INTERNAL
USE ONLY!

=cut

our %INSTANCES;
sub _instance {
    my ( $class, $package, $sub ) = splice( @_, 0, 3);
    $INSTANCES{ $class }{ $package }{ $sub } = shift( @_ ) if @_;
    return $INSTANCES{ $class }{ $package }{ $sub };
}

=item $sub_ref = new_sub()

Must be overriden by a subclass. Should return a replacement sub for the sub
being managed.

=cut

sub new_sub {
    my $self = shift;
    croak( (ref $self ) . " must override new_sub()" );
}

=item $sub_ref = _new_sub()

FOR INTERNAL USE ONLY

Wraps the sub from new_sub() in additional logic to ensure the original sub is
restored after an exception.

=cut

sub _new_sub {
    my $self = shift;
    my $new_sub = $self->new_sub;
    return sub {
        my @return = ( eval { $new_sub->( @_ ) } );
        if ( $@ ) {
            $self->restore();
            croak( $@ );
        }
        return unless @return;
        return $return[0] if @return == 1;
        return @return;
    }
}

=item init( $self, @params )

Called by new() after object construction. Passed $self and extra parameters
from new(). Should be overriden by a subclass for extar construction work.

=cut

sub init { 1 };

=item $obj = $class->new( $package, $sub, $tracker, @params )

Constructs a new instance, or returns the existing instance of $class managing
$package::$sub. In the case of an existing instance the tracker is appended to
the list of trackers. @params is passed to init().

init() is called both for new instances and existing.

=cut

sub new {
    my $class = shift;
    my ( $package, $sub, $tracker, @params ) = @_;
    my $self = $class->_instance( $package, $sub );
    unless ($self) {
        $self = $class->_instance(
            $package,
            $sub,
            bless(
                {
                    'package' => $package,
                    'sub' => $sub,
                },
                $class
            ),
        );
        $self->do_override;
    }

    $self->add_tracker( $tracker );
    $self->init( @params );

    return $self;
}

=item do_override()

INTERNAL USE ONLY!

Replaces the managed sub with _new_sub(). Will refuse to run if the instance
has expired. Automatically called by new(), you should NEVER need to runthis
yourself.

=cut

sub do_override {
    my $self = shift;
    my $current = (ref $self)->_instance( $self->package, $self->sub );
    die( "Cannot run do_override on expired instance" )
        unless $current and $self == $current;
    $self->original( copy_sub( $self->package, $self->sub ));
    set_sub(
        $self->package,
        $self->sub,
        $self->_new_sub,
    );
    return $self;
}

=item restore()

Restore the original subroutine and expire this instance.

=cut

sub restore {
    my $self = shift;
    set_sub(
        $self->package,
        $self->sub,
        $self->original,
    );
    (ref $self)->_instance( $self->package, $self->sub, undef );
    return $self;
}

=item add_tracker( $tracker )

Add a tracker to the list of trackers.

=cut

sub add_tracker {
    my $self = shift;
    my ( $tracker ) = @_;

    $self->trackers( [] ) unless $self->trackers;
    push( @{ $self->trackers }, $tracker ) 
        unless grep { $_ and $tracker and $_ == $tracker } @{ $self->trackers };

    return $self;
};

=item remove_tracker( $tracker )

Remove a tracker from the list. Must pass in a reference to the tracker that
should be removed.

Instance will expire and restore original sub when all trackers have been
removed.

You should never need to call this yourself, it is usually called by a tracker
itself.

=cut

sub remove_tracker {
    my $self = shift;
    my ( $tracker ) = @_;
    $self->trackers([ grep { $_ != $tracker } @{ $self->trackers }]);
    $self->restore() unless @{ $self->trackers };
    return $self;
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
