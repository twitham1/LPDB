=head1 NAME

Prima::LPDB::Fullscreen - Toggle a window to full screen

=head1 DESCRIPTION

This enhances L<Prima::Window> to know about all the screens of the
display, mapping them into our coordinate system relative to the
primary screen.  Then it provides fullscreen capability to the screen
we are on or the closest screen.

=cut

# Maybe improve this and promote to Prima::Fullscreen, or even merge
# into Prima::Window so that all windows can know about all screens.

package Prima::LPDB::Fullscreen;

use strict;
use warnings;
use Prima;
use Prima::Classes;

use vars qw(@ISA);
@ISA = qw(Prima::Window);

=pod

=over

=item virtual_screens

Returns set of [X,Y,WIDTH,HEIGHT,DIST,ON] identifying screen locations
and the window's relation to them.  X and Y are reported relative to
the lower left corner of the primary screen which is our coordinate
system.  DIST is the distance from screen center to window center.  ON
is a boolean 1 only when the center of the window is on that screen.

WARNING: may not be perfect for Prima < 1.66, see source code.

See also: C<Prima::Application::get_monitor_rects>

=cut

# Try to shift arbitrary screen rectangles to my coordinate system,
# which is always relative to the primary screen.  Prima 1.66 always
# returns primary screen first. Prior to that I try to search for it:
#
# Primary must match my application size so I first grep for matching
# size, then select the one closest to 0,0.  This may or may not be
# right for random screen layouts.  In particular this breaks with
# vertical layout with primary at the top under Windows 10 as lower is
# at 0,0 instead.  -twitham, 2022/09
sub virtual_screens {
    my($winx, $winy) = $_[0]->origin;
    my($winw, $winh) = $_[0]->size;
    my($wcx,  $wcy) = ($winx + $winw / 2, $winy + $winh / 2);
    my($appw, $apph) = $::application->size;
    my $rects = $::application->get_monitor_rects;
    my $primary = $Prima::VERSION >= 1.66
	? $rects->[0]		# primary always first since 1.66
	: (sort { abs $a->[0] + abs $a->[1] <=>
		      abs $b->[0] + abs $b->[1] }
	   grep { $_->[2] == $appw && $_->[3] == $apph }
	   @$rects)[0];
    my($x1, $y1) = @$primary[0,1];
    my $virt;
    for my $screen (@$rects) {
	my($x, $y, $w, $h) = @$screen;
	next unless $w and $h;	# I get a bogus 0x0 screen under X11!
	$x -= $x1; $y -= $y1; # now relative to primary, like all windows
	my($cx, $cy) = ($x + $w / 2, $y + $h / 2);
	my($dx, $dy) = ($wcx - $cx , $wcy - $cy);
	my $dist = int(sqrt($dx * $dx + $dy * $dy));
	push @$virt, [$x, $y, $w, $h, $dist,
		      $wcx >= $x && $wcx < $x + $w &&
		      $wcy >= $y && $wcy < $y + $h];
    }
    return $virt;
}

=pod

=item closest_screen

Returns the virtual rect of the screen the window is on, or the
closest screen if not on any screen.  X and Y are relative to the
primary screen.

See also: C<virtual_screens>, C<fullscreen>

=cut

sub closest_screen {
    my($win) = @_;
    my $all = $win->virtual_screens;
    my $on = (grep { $_->[-1] } @$all)[0]; # on a screen
    return [ (@$on)[0,1,2,3] ]
	if $on;
    my $close = (sort { $a->[-2] <=> $b->[-2] } @$all)[0];
    return [ (@$close)[0,1,2,3] ] # near a screen
	if $close;
    return [0, 0, $::application->size]; # shouldn't get here
}

# NOTES on going fullscreen:

# In X11 we can only guarantee fullscreen by creating a
# non-WM-manageable widget.  This is portable, but we cannot bring
# dialogs forward, so we must deal with it by turning the fullscreen
# mode off -DK, from fotofix

# But if non-WM-manageable, then user loses control.  I need to be
# able to Alt-tab to any other app and Alt-tab back to the fullscreen.
# So I prefer to keep it a normal window but match the screen size.
# Some WM's make this difficult.  So far I have a optional hack that
# works for XFCE, see bin/fullscreen.  -twitham, from LPDB/lpgallery

=pod

=item fullscreen BOOLEAN, -1 = toggle

Returns 1 if the window is occupying a full screen, 0 otherwise.  1
will make the window fullscreen while 0 will restore it to normal.  -1
toggles full screen.  Full screen is on the screen of the center of
the window or the closest screen.

WARNING: may not work on all Window Managers, see workaround hacks in
the source code.

See also: C<virtual_screens>, C<closest_screen>

=cut

sub fullscreen		     # 0 = normal, 1 = fullscreen, -1 = toggle
{
    my($self, $fs) = @_;
    $self->{fullscreen} ||= 0;
    return $self->{fullscreen} unless defined $fs;
    return if $self->{fullscreen} == $fs;
    $fs = !$self->{fullscreen} if $fs < 0;
    $self->{fullscreen} = $fs;

    if ($fs) {
	$self->{window_rect} = [ $self->rect ];
	my($x, $y, $w, $h) = @{$self->closest_screen};
	$y++			# XFCE moves Y of 0 but not 1
	    if $self->{addY1};
	$h -= $::application->get_system_value(sv::YMenu)
	    if $self->menuItems; # show menu bar (if any) over window
	$self-> set(
	    origin => [$x, $y],
	    size   => [$w, $h],
	    ($self->{NoIcons} ? (borderIcons => 0) : ()),
	    ($self->{NoBorder} ? (borderStyle => bs::None) : ()),
	    );
	$self-> bring_to_front;
    } else {
	$self-> set(
	    rect        => $self->{window_rect},
	    borderIcons => bi::All,
	    borderStyle => bs::Sizeable,
	    );
    }
    return $self->{fullscreen};
}

=pod

=back

=head1 SEE ALSO

L<Prima::Window>

=head1 AUTHOR

Timothy D Witham <twitham@sbcglobal.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2022 Timothy D Witham.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;				# Fullscreen.pm ends here
