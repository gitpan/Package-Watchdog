package Package::Watchdog::Sub::Forbidden;
use strict;
use warnings;
use Package::Watchdog::Util;
use base 'Package::Watchdog::Sub';
use Carp;

#{{{ POD

=pod

=head1 NAME

Package::Watchdog::Sub::Forbidden - Object to manage a forbidden sub.

=head1 DESCRIPTION

Inherits methods from Package::Watchdog::Sub.

=head1 METHODS

=over 4

=item new_sub()

Returns the sub reference that will replace the original forbidden sub.

=cut

#}}}

sub new_sub {
    my $self = shift;

    return sub {
        my @sets;
        for my $forbid ( @{ $self->trackers } ) {
            for my $watch ( @{ $forbid->watched->trackers }) {
                push @sets => {
                    forbid => $forbid,
                    watch => $watch,
                    forbidden => $self,
                    forbidden_params => [ @_ ],
                };
            }
        }

        my @warns = grep { $_->{watch}->react eq 'warn' } @sets;
        my @dies = grep { $_->{watch}->react eq 'die' } @sets;
        my @reacts = grep { ref( $_->{watch}->react )} @sets;
        $_->{watch}->warn( $_ ) for @warns;
        $_->{watch}->warn( $_ , 'fatal' ) for @dies;

        $_->{ watch }->do_react( %$_ ) for @reacts;

        croak( "At least one watch with a die reaction has been triggered." ) if @dies;

        return $self->original->( @_ );
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
