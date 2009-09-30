package Package::Watchdog::Sub::Watched;
use strict;
use warnings;
use Package::Watchdog::Tracker::Forbid;
use Package::Watchdog::Util;
use base 'Package::Watchdog::Sub';

#{{{ POD

=pod

=head1 NAME

Package::Watchdog::Sub::Watched - Object to manage a watched sub.

=head1 DESCRIPTION

Inherits methods from Package::Watchdog::Sub.

=head1 METHODS

=over 4

=item new_sub()

Returns the sub reference that will replace the original watched sub.

=cut

#}}}

sub new_sub {
    my $self = shift;

    return sub {
        my $want = wantarray();
        my $params = {
            watches => $self->trackers,
            original_watched => $self->original,
            watched_params => [ @_ ],
            watched => $self,
            watched_package => $self->package,
            watched_sub => $self->sub,
        };

        my $forbid = Package::Watchdog::Tracker::Forbid->new( $self, $params );

        my @out = eval { proper_return( $want, $self->original, @_ )};

        $forbid->untrack;

        die( $@ ) if $@;
        return @out if $want;
        return shift( @out ) if defined( $want );
        return @out if @out > 1;
        return shift( @out );
    };
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
