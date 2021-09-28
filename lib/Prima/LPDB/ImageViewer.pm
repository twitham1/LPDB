=head1 NAME

Prima::LPDB::ImageViewer - ImageViewer for Prima::LPDB::ThumbViewer

=head1 DESCRIPTION

Like C<Prima::ImageViewer> but with a keyboard driven interface for
LPDB.  A single window is reused to show many images over time and
overlay with metadata.

=cut

package Prima::LPDB::ImageViewer;

use strict;
use warnings;
use Prima::ImageViewer;
use Image::Magick;
use Prima::Image::Magick qw/:all/;

use vars qw(@ISA);
@ISA = qw(Prima::ImageViewer);

# 	# onMouseDown => \&iv_mousedown,
# 	# onMouseUp   => \&iv_mouseup,
# 	# onMouseMove => \&iv_mousemove,
# 	# onMouseWheel => \&iv_mousewheel,
# );

sub profile_default
{
    my $def = $_[ 0]-> SUPER::profile_default;
    my %prf = (
	size => [800, 600],
	selectable => 1,
	name => 'IV',
	valignment  => ta::Middle,
	alignment   => ta::Center,
	autoZoom => 0,
	stretch => 0,
	# borderIcons    => bi::SystemMenu | bi::TitleBar,
	# widgetClass    => wc::Dialog,
	originDontCare => 0,
	sizeDontCare   => 0,
	# taskListed     => 0,
	);
    @$def{keys %prf} = values %prf;
    return $def;
}

sub profile_check_in
{
    my ( $self, $p, $default) = @_;
    $self-> SUPER::profile_check_in( $p, $default);
}


sub init {
    my $self = shift;
    my %profile = $self->SUPER::init(@_);
    $self->{thumbviewer} = $profile{thumbviewer}; # object to return focus to
    return %profile;
}

sub viewimage
{
    my ($self, $filename) = @_;
    my $i = Image::Magick->new;
    my $e = $i->Read($filename);
    if ($e) {
    	warn $e;      # opts are last-one-wins, so we override colors:
    	$i = Image::Magick->new(qw/magick png24 size 320x320/,
    				qw/background red fill white gravity center/);
    	$i->Read("caption:$e");	# put error message in the image
    }
    $i->AutoOrient;		# automated rot fix via EXIF!!!

    $self->image(magick_to_prima($i));
    $self->{fileName} = $filename;
    warn "focused: ", $::application->get_focused_widget;
    $self->selected(1);
    $self->focused(1);
    $self->status;
}

sub on_close {
    my $owner = $_[0]->{thumbviewer};
    $owner->selected(1);
    $owner->focused(1);
    $owner->owner->restore;
    $owner->owner->select;
}
sub on_keydown
{
    my ( $self, $code, $key, $mod) = @_;

    warn "my keydown: @_";
    if ($key == kb::Escape) {	# return focus to caller
	my $owner = $self->{thumbviewer};
	$owner->selected(1);
	$owner->focused(1);
	$owner->owner->restore;
	$owner->owner->select;
    }

    return if $self->{stretch};

    return unless grep { $key == $_ } (
	kb::Left, kb::Right, kb::Down, kb::Up
    );

    my $xstep = int($self-> width  / 5) || 1;
    my $ystep = int($self-> height / 5) || 1;

    my ( $dx, $dy) = $self-> deltas;

    $dx += $xstep if $key == kb::Right;
    $dx -= $xstep if $key == kb::Left;
    $dy += $ystep if $key == kb::Down;
    $dy -= $ystep if $key == kb::Up;
    $self-> deltas( $dx, $dy);
}

my $ico = Prima::Icon-> create;
$ico = 0 unless $ico-> load( 'hand.gif');

sub status
{
    my($self) = @_;
    my $w = $self->owner;
    my $img = $self->image;
    my $str;
    if ($img) {
	$str = $self->{fileName};
	$str =~ s/([^\\\/]*)$/$1/;
	$str = sprintf("%s (%dx%dx%d bpp)", $1,
		       $img-> width, $img-> height, $img-> type & im::BPP);
    } else {
	$str = '.Untitled';
    }
    $w->text($str);
    $w->name($str);
}

# sub iv_mousedown
# {
# 	my ( $self, $btn, $mod, $x, $y) = @_;
# 	return if $self-> {drag} || $btn != mb::Right;
# 	$self-> {drag}=1;
# 	$self-> {x} = $x;
# 	$self-> {y} = $y;
# 	$self-> {wasdx} = $self-> deltaX;
# 	$self-> {wasdy} = $self-> deltaY;
# 	$self-> capture(1);
# 	$self-> pointer( $ico) if $ico;
# }

# sub iv_mouseup
# {
# 	my ( $self, $btn, $mod, $x, $y) = @_;
# 	return unless $self-> {drag} && $btn == mb::Right;
# 	$self-> {drag}=0;
# 	$self-> capture(0);
# 	$self-> pointer( cr::Default) if $ico;
# }

# sub iv_mousemove
# {
# 	my ( $self, $mod, $x, $y) = @_;
# 	return unless $self-> {drag};
# 	my ($dx,$dy) = ($x - $self-> {x}, $y - $self-> {y});
# 	$self-> deltas( $self-> {wasdx} - $dx, $self-> {wasdy} + $dy);
# }

# sub iv_mousewheel
# {
# 	my ( $self, $mod, $x, $y, $z) = @_;
# 	$z = (abs($z) > 120) ? int($z/120) : (($z > 0) ? 1 : -1);
# 	my $xv = $self-> bring(($mod & km::Shift) ? 'VScroll' : 'HScroll');
# 	return unless $xv;
# 	$z *= ($mod & km::Ctrl) ? $xv-> pageStep : $xv-> step;
# 	if ( $mod & km::Shift) {
# 		$self-> deltaX( $self-> deltaX - $z);
# 	} else {
# 		$self-> deltaY( $self-> deltaY - $z);
# 	}
# }

1;

=pod

=back

=head1 SEE ALSO
L<Prima::ThumbViewer>, L<LPDB>

=head1 AUTHOR

Timothy D Witham <twitham@sbcglobal.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2013-2022 Timothy D Witham.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
