=head1 NAME

Prima::LPDB::Slider - minimal sliding bar in front of content

=head1 DESCRIPTION

A C<Prima::Slider> that is fully transparent except for the sliding
bar, intended to display in front of the content it represents.  Bar
length represents one or more values.  For example if there are 5
values (1-5) then the bar is 20% of the slider length.  If values
(2,3) are given, then the bar is from 20% to 60% of the length.

=cut

# TODO: let readOnly=0 work, configurable colors

use strict;
use warnings;
use Prima;
use Prima::Sliders;

package Prima::LPDB::Slider;
use vars qw(@ISA);
use base qw(Prima::Slider);

sub profile_default
{
    return {
	%{$_[0]->SUPER::profile_default},
	    borderWidth	=> 0,
	    transparent => 1,	# show progress in front of others
	    buffered	=> 0,	# 1 shows corruption in overlay
	    autotrack	=> 0,
	    height	=> 15,
	    ticks	=> undef,
	    readOnly	=> 1,	# fix this????
	    vertical	=> 0,
	    end		=> 0,	# second arg to value, defaults to value
	    minlen	=> 20,	# minimum bar in pixels
    }
}

sub profile_check_in
{
    my ($self, $p, $default) = @_;
    $p->{end} //= $default->{end};
    $p->{minlen} //= $default->{minlen};
    $self->SUPER::profile_check_in($p, $default);
}

sub init
{
    my $self = shift;
    my %profile = $self-> SUPER::init(@_);
    $self->{$_} = $profile{$_} for qw(end minlen);
    return %profile;
}

sub minlen { $#_ ? $_[0]->{minlen} = $_[1] : return $_[0]->{minlen} }

sub value
{
    my($self, $b, $e) = @_;
    defined $b
	or return ($self->{value}, $self->{end});
    my($B, $E) = ($self->{value}, $self->{end});
    $self->SUPER::value($b);
    my($min, $max) = ( $self-> {min}, $self-> {max});
    $e ||= $self->{value};
    $e >= $b or $e = $b;
    $e <= $self->{max} or $e = $self->{max};
    $self->{end} = $e;
    return if $self->{value} == $B and $self->{end} == $E;
    $self->repaint;
}

sub on_paint
{
    my ($self, $canvas) = @_;
    my $v = $self->{vertical};
    # warn "painting $v $self, $canvas";
    my($w, $h) = $canvas->size;
    my $min = 20;		# minimum length
    my $val = $self->{value};
    my $end = $self->{end} || $self->{value};
    my $range = abs($self->{max} - $self->{min}) + 1;
    my $wid = $v ? $w : $h;
    my $c = $wid / 2;		# centerline
    my $each = ($v ? $h - $c : $w - $c) / ($range || 1);
    my($b, $e) = ($each * ($val - 1) + $c, $each * $end);
    $e > $b + $self->{minlen} or $e = $b + $self->{minlen};
    for my $l ($wid, $wid / 3) {      # line width
	$canvas->lineWidth($l);
	$canvas->color($l == $wid ? 0xff00ff : 0x00ff00);
	# $canvas->color($l > 6 ? $self->backColor : $self->color);
	$canvas->polyline($v ? [$c, $h - $b, $c, $h - $e]
			  :    [$b, $c     , $e, $c     ]);
    }
}

1;

=pod

=head2 Properties

=over

=item minlen INTEGER

The property manages the minimum length of the sliding bar in pixels.

Default value: 20

=back

=head2 Methods

=over

=item value INTEGER [INTEGER]

Selects an integer value between C<min> and C<max> and the
corresponding sliding bar position.  The optional second value is the
end value, defaulting to the same value as the first so that the bar
length represents one displayed value.  If the second value is 1
greater than the first, then the bar length represents two values, and
so on.

=back

=head1 SEE ALSO

L<Prima::Slider>, L<Prima::LPDB::ImageViewer>

=head1 AUTHOR

Timothy D Witham <twitham@sbcglobal.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2013-2026 Timothy D Witham.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
