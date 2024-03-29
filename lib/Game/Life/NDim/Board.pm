package Game::Life::NDim::Board;

# Created on: 2010-01-04 18:52:38
# Create by:  Ivan Wills
# $Id$
# $Revision$, $HeadURL$, $Date$
# $Revision$, $Source$, $Date$

use Moose;
use warnings;
use feature qw/:5.10/;
use version;
use Carp qw/croak cluck/;
use List::Util qw/max/;
use Data::Dumper qw/Dumper/;
use English qw/ -no_match_vars /;
use Game::Life::NDim::Life;
use Game::Life::NDim::Dim;
use Params::Coerce ();

use overload '""' => \&to_string;

our $VERSION     = version->new('0.0.1');
our @EXPORT_OK   = qw//;
our %EXPORT_TAGS = ();

has items => (
    is    => 'rw',
    isa   => 'ArrayRef',
    lazy_build  => 1,
);

has dims => (
    is       => 'ro',
    isa      => 'Game::Life::NDim::Dim',
    required => 1,
);

has cursor => (
    is     => 'rw',
    isa    => 'Game::Life::NDim::Dim',
);

has types => (
    is       => 'rw',
    isa     => 'HashRef',
    default => sub {{ 0 => 0.6, 1 => 0.4 }},
);

has wrap => (
    is       => 'rw',
    isa     => 'Bool',
    default => 0,
);

has verbose => (
    is       => 'rw',
    isa     => 'Bool',
    default => 0,
);

around new => sub {
    my ($new, $class, %params) = @_;

    if (ref $params{dims} eq 'ARRAY') {
        $params{dims} = Game::Life::NDim::Dim->new($params{dims});
    }

    my $self = $new->($class, %params);

    $self->reset;
    $self->seed(%params) if $params{rand};
    #$self->cursor(Game::Life::NDim::Dim->new([]));
    for (@{ $self->dims }) {
        push @{ $self->cursor }, 0;
    }

    return $self;
};

sub _build_items {
    my ($self, %params) = @_;

    $self->types = $params{types} if $params{types};

    my $items = [];
    my $lives = 0;

    my $builder;
    $builder = sub {
        my ($items, $dims, $pos) = @_;
        my $count = $dims->[0];

        for my $i ( 0 .. $count - 1 ) {
            if ( @{$dims} == 1 ) {
                $items->[$i] = Game::Life::NDim::Life->new(
                    position => Game::Life::NDim::Dim->new([ @{ $pos }, $i ]),
                    board    => $self
                );
                $lives++;
            }
            else {
                $items->[$i] = [];
                my $sub_dims = [ @{ $dims }[ 1 .. @{ $dims } - 1 ] ];
                my $sub_pos  = [ @{ $pos }, $i ];
                my $sub_items = $items->[$i];
                $builder->($sub_items, $sub_dims, $sub_pos);
            }
        }
    };
    $builder->($items, $self->dims, []);

    return $items;
}

sub seed {
    my ($self, %params) = @_;

    $self->types = $params{types} if $params{types};

    my $i = 0;
    while ( ref (my $life = $self->next_life()) ) {
        $life->seed($self->types);
    }
    $self->reset;

    return $self;
}

sub reset {
    my ($self) = @_;
    my @cursor;

    for (@{ $self->dims }) {
        push @cursor, 0;
    }

    $cursor[-1] = -1;

    $self->cursor(Game::Life::NDim::Dim->new(\@cursor));

    return $self;
}

sub next_life {
    my ($self) = @_;
    my $max_dim;

    return if !$self->cursor->increment($self->dims);

    my $life = $self->items;

    my @pos;
    for my $i ( 0 .. @{ $self->dims } - 1 ) {
        if ( ! exists $self->cursor->[$i] ) {
            die "here?\n";
            $self->cursor->[$i] = 0;
        }
        my $pos = $self->cursor->[$i];
        push @pos, $pos;
        if ( ref $life eq 'ARRAY' && @{ $life }  < $pos + 1 ) {
            $life->[$pos] =
                $i < @{ $self->cursor } - 1 ? []
                :                             Game::Life::NDim::Life->new(board => $self, position => $self->cursor);
        }
        $life = $life->[$pos];
    }

    return $life;
}

sub set_life {
    my ($self, $life) = @_;

    my $curr = $self->items;

    for my $i ( @{ $self->cursor } ) {
        if ( ref $curr->[$i] eq 'ARRAY' ) {
            $curr = $curr->[$i];
        }
        else {
            $curr->[$i] = $life;
        }
    }

    return $self;
}

sub get_life {
    my ($self, $position) = @_;

    my $item = $self->items;
    my $min  = $self->wrap ? -1 : 0;
    die if !defined $min;

    for my $i (@{ $position } ) {
        croak "Cannot get game position from $position $i >= $min " if $i < $min || !exists $item->[$i];
        $item = $item->[$i];
    }

    return $item;
}

sub to_string {
    my ($self) = @_;

    die "The dimension of this game is to large to sensibly convert to a string\n" if @{ $self->dims } > 3;

    my $spacer = ( 10 >= max (@{$self->dims}, scalar @{$self->dims}) ) ? ' ' : '';

    my $out = '';
    my @outs;
    $self->reset;
    my $i = 0;
    my $level = 0;
    while ( ref ( my $life = $self->next_life() ) ) {
        if ( @{$self->cursor} > 2 && $self->cursor->[0] != $level) {
            $out .= "\n";
            $level = $self->cursor->[0];
            push @outs, $out;
            $out = '';
        }
        $out .= $life;
        $out .= $self->cursor->[-1] == $self->dims->[-1] ? "\n" : $spacer;
        $i++;
    }
    $self->reset;

    if (@outs) {
        $out .= "\n";
        $level = $self->cursor->[0];
        push @outs, $out;
        $out = '';
        my @lines;
        for my $level (@outs) {
            my $i = 0;
            for my $line (split /\n/, $level) {
                $lines[$i] ||= '';
                $lines[$i] .= "    $line";
                $i++;
            }
        }
        return join "\n", @lines, '';
    }

    #return "Board:\n" . $out . "\nCount = $i\n";
    return $out;
}

1;

__END__

=head1 NAME

Game::Life::NDim::Board - <One-line description of module's purpose>

=head1 VERSION

This documentation refers to Game::Life::NDim::Board version 0.0.1.


=head1 SYNOPSIS

   use Game::Life::NDim::Board;

   # Brief but working code example(s) here showing the most common usage(s)
   # This section will be as far as many users bother reading, so make it as
   # educational and exemplary as possible.


=head1 DESCRIPTION

A full description of the module and its features.

May include numerous subsections (i.e., =head2, =head3, etc.).


=head1 SUBROUTINES/METHODS

=head2 C<seed (  )>

=head2 C<reset (  )>

=head2 C<next_life (  )>

=head2 C<get_life (  )>

=head2 C<set_life (  )>

=head2 C<to_string (  )>

=head2 C<_build_items (  )>

=head1 DIAGNOSTICS

A list of every error and warning message that the module can generate (even
the ones that will "never happen"), with a full explanation of each problem,
one or more likely causes, and any suggested remedies.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the module, including
the names and locations of any configuration files, and the meaning of any
environment variables or properties that can be set. These descriptions must
also include details of any configuration language used.

=head1 DEPENDENCIES

A list of all of the other modules that this module relies upon, including any
restrictions on versions, and an indication of whether these required modules
are part of the standard Perl distribution, part of the module's distribution,
or must be installed separately.

=head1 INCOMPATIBILITIES

A list of any modules that this module cannot be used in conjunction with.
This may be due to name conflicts in the interface, or competition for system
or program resources, or due to internal limitations of Perl (for example, many
modules that use source code filters are mutually incompatible).

=head1 BUGS AND LIMITATIONS

A list of known problems with the module, together with some indication of
whether they are likely to be fixed in an upcoming release.

Also, a list of restrictions on the features the module does provide: data types
that cannot be handled, performance issues and the circumstances in which they
may arise, practical limitations on the size of data sets, special cases that
are not (yet) handled, etc.

The initial template usually just has:

There are no known bugs in this module.

Please report problems to Ivan Wills (ivan.wills@gmail.com).

Patches are welcome.

=head1 AUTHOR

Ivan Wills - (ivan.wills@gmail.com)
<Author name(s)>  (<contact address>)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 Ivan Wills (14 Mullion Close, Hornsby Heights, NSW Australia 2077).
All rights reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.  This program is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
