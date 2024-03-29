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
        my %seen;
        for my $call ( @{ $self->tracker->stack }) {
            my ( $watch, $watch_context ) = @$call;

            my $react = $watch->react;
            next if $seen{ $react }++;
            my $fatal = $react eq 'die' ? 'fatal' : undef;

            my $context = {
                watch => $watch,
                %$watch_context,
                forbidden => $self,
                forbidden_params => [ @_ ],
                forbid => $self->tracker,
            };

            if ( ref( $react )) {
                $watch->do_react( %$context );
            }
            else {
                $watch->warn( $context, $fatal );
                croak( 'At least one watch with a die reaction has been triggered.' )
                    if $fatal;
            }
        }

        my $want = wantarray();
        my @out = proper_return( $want, $self->original, @_ );
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
