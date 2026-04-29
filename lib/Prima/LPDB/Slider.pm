=head1 NAME

Prima::LPDB::Slider - scroll bar like handle in front of other widgets

=head1 DESCRIPTION

A C<Prima::Slider> that is fully transparent except for the handle.
Handle size represents the size of one value.  For example if there
are 5 values then the handle is 20% of the slider length.

=cut

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
	    min		=> 1,
	    max		=> 1,
	    borderWidth	=> 0,
	    transparent => 1,	# show progress in front of others
	    buffered	=> 0,	# 1 shows corruption in overlay
	    autotrack	=> 0,
	    height	=> 15,
	    ticks	=> undef,
	    readOnly	=> 1,	# fix this!!!
	    vertical	=> 0,
    }
}

sub on_paint
{
    my ($self, $canvas) = @_;
    my $v = $self->{vertical};
    # warn "painting $v $self, $canvas";
    my($w, $h) = $canvas->size;
    my $min = 20;		# minimum length
    my $range = 1 + abs($self->{max} - $self->{min});
    my $val = $self->{value};
    my $wid = $v ? $w : $h;
    my $c = $wid / 2;		# centerline
    my $each = ($v ? $h - $c : $w - $c) / $range;
    my($b, $e) = ($each * ($val - 1) + $c, $each * $val);
    $e > $b + $min or $e = $b + $min; # minimum indicator length
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

=head1 SEE ALSO

L<lpgallery>, L<Prima::LPDB::ImageViewer>, L<LPDB>

=head1 AUTHOR

Timothy D Witham <twitham@sbcglobal.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2013-2026 Timothy D Witham.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
