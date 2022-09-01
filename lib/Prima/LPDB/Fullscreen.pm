=head1 NAME

Prima::LPDB::Fullscreen - Try to toggle a window to full screen

=head1 DESCRIPTION

This approach to fullscreen keeps the window borders but displays them
off-screen.  It may or may not work with random window managers.
Tested only on xfce on Ubuntu 20.04 where panel hiding is required in
panel preferences.

=cut

package Prima::LPDB::Fullscreen;
use strict;
use warnings;
use Prima::Classes;


use vars qw(@ISA);
@ISA = qw(Prima::Component);

sub fullscreen {
    # my($win, $which) = @_;
    my($self, $which) = @_;
    my $win = $self->owner;
    my @d = $::application->size;		      # desktop size
    my @f = ($win->frameSize, $win->frameOrigin);     # frame size/pos
    my @w = ($win->size, $win->origin);		      # window size/pos
    my $full = $d[0] == $w[0] && $d[1] == $w[1];      # full screen now?
    my $to = $which || '';			      # target
    warn "$win is\t@w framed by\t@f,  full=$full, to=$to";
    defined $which
	or return $full;
    if ($which) {		# going to fullscreen
	$full and return 1;
	$self->{where} = \@f;	# remember size/origin to return to
	# my $x = $f[0] - $w[0];
	# my $y = $f[1] - $w[1];
	# this loses Alt-tab control on xfce:
	# $win->borderStyle(bs::None);
	# $win->borderIcons(0);
	# # $win->frameSize($d[0] + $x, $d[1] + $y);
	# $y = $f[3] - $w[3] + 1;
	# $win->frameOrigin(-$x, $y);
	# $y = -100;
	# do {
	#     $win->frameOrigin(-$x, $y);
	#     my @t = $win->origin;
	#     warn "frame at $x $y, yields origin @t";
	#     $y++;
	# } while (($win->origin)[1] && $y < 100);
	# $win->onTop(0);
	# without this, xfce taskbar overlays my fullscreen:
	# (until I configured his preferences to "hide = intelligent")
	# $win->onTop(1);
	# on xfce/ubuntu, 0,0 is not right but 0,1 is close:
	$win->origin(0, 1);
	$win->size(@d);
	# $win->onTop(1);
	return 1;
    } elsif ($self->{where}) {	# restore orignal frame
	# $win->onTop(0);
	# $win->borderIcons(bi::All);
	# $win->borderStyle(bs::Sizeable);
	$win->frameSize((@{$self->{where}})[0,1]);
	$win->frameOrigin((@{$self->{where}})[2,3]);
	return 0;
    }
}

1;
