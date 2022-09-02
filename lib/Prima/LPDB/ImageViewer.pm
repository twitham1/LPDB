=head1 NAME

Prima::LPDB::ImageViewer - ImageViewer for Prima::LPDB::ThumbViewer

=head1 DESCRIPTION

Like C<Prima::ImageViewer> but with a keyboard driven interface for
C<LPDB>.  A single window is reused to show many images over time and
overlay with metadata.

=cut

# TODO: add 9 touch/mouse click zones like from picasagallery

package Prima::LPDB::ImageViewer;

use strict;
use warnings;
use Prima::ImageViewer;
use Prima::Edit;		# for ExifTool metadata window
use Prima::LPDB::Fullscreen;	# could someday promote to Prima?

use vars qw(@ISA);
@ISA = qw(Prima::ImageViewer Prima::LPDB::Fullscreen);

sub profile_default
{
    my $def = $_[ 0]-> SUPER::profile_default;
    my %prf = (
	size => [1600, 900],
	selectable => 1,
	name => 'IV',
	valignment  => ta::Middle,
	alignment   => ta::Center,
	autoZoom => 1,
	stretch => 0,
	timer => undef,
	seconds => 4,
	buffered => 1,		# undecided on which is better...
	popupItems => [
	    ['~Escape back to Thumb Gallery' =>
	     sub { $_[0]->key_down(0, kb::Escape) } ],
	    [],
	    ['@info', '~Information', 'i', ord 'i' => sub { $_[0]->status }],
	    ['@overlay', '~Overlay Images', 'o', ord 'o' => sub {  $_[0]->repaint }],
	    ['exiftool', 'Meta~Data Window', 'd', ord 'd' => 'metadata'],
	    [],
	    ['@slideshow', '~Play/Pause Slide Show', 'p',  ord 'p' => 'slideshow'],
	    ['faster', 'Fas~ter Show', "Ctrl+Shift+F", km::Ctrl | km::Shift | ord('F') => 'delay'],
	    ['slower', '~Slower Show', "Ctrl+Shift+B", km::Ctrl | km::Shift | ord('B') => 'delay'],
	    [],
	    ['fullscreen', '~Full Screen', 'f', ord 'f' =>
	     sub { $_[0]->fullscreen($_[0]->popup->toggle($_[1]) )} ],
	    ['bigger', '~Zoom In', 'z', ord 'z' =>
	     sub { $_[0]->bigger }],
	    ['smaller', 'Zoom ~Out', 'q', ord 'q' =>
	     sub { $_[0]->smaller }],
	    ['*@autozoom', '~Auto Zoom', 'Enter', kb::Enter, 'autozoom' ],
	],
	);
    @$def{keys %prf} = values %prf;
    return $def;
}

sub init {
    my $self = shift;
    my %profile = $self->SUPER::init(@_);
    my($w, $h) = $self->size;
    my @opt = qw/Prima::Label autoHeight 1/; # transparent 1/; causes more repaints!!!

    $self->{thumbviewer} = $profile{thumbviewer}; # object to return focus to

    $self->{exif} = new Image::ExifTool; # for collecting picture metadata
    $self->{exif}->Options(FastScan => 1); # , DateFormat => $conf->{datefmt});

    $self->insert('Prima::LPDB::Fullscreen', window => $self->owner);

    # my $pad = $self->{pad} = sv::XScrollbar; # too small
    # warn "scrollbar x=", sv::XScrollbar, " y=", sv::YScrollbar;
    my $pad = $self->{pad} = 20; # pixels between edge and text, > scrollbar

    $self->insert(@opt, name => 'NW', growMode => gm::GrowLoY,
		  top => $h - $pad, left => $pad);
    $self->insert(@opt, name => 'NE', growMode => gm::GrowLoY|gm::GrowLoX,
		  top => $h - $pad, right => $w - $pad,
    		 alignment => ta::Right);
    $self->insert(@opt, name => 'N', growMode => gm::GrowLoY|gm::XCenter,
		  top => $h - $pad,
		  alignment => ta::Center);

    $self->insert(@opt, qw/name CENTER text/ => ' ', growMode => gm::Center);

    $self->insert(@opt, name => 'SW', left => $pad, bottom => $pad);
    $self->insert(@opt, name => 'SE', growMode => gm::GrowLoX,
		  bottom => $pad, right => $w - $pad,
		  transparent => 1, # nice to see image through this big box
		  alignment => ta::Right);
    $self->insert(@opt, name => 'S', growMode => gm::XCenter, bottom => $pad,
		  alignment => ta::Center);

    $self->buffered(1);
    return %profile;
}

sub picture { $_[0]->{picture} || undef }
sub viewimage
{
    my ($self, $picture) = @_;
    my $filename = $picture->pathtofile or return;
    if (my $i = Prima::Image->load($filename)) {
	if (my $rot = $picture->rotation) {
	    $i->rotate(-1 * $rot);
	}
	$self->image($i);
    } else {		    # generate image containing the error text
	my $e = "$@";
	warn "$filename: $e";
	my @s = (800, 450);
	my $b = $s[0] / 10;
	my $i = Prima::Icon->new(
	    width  => $s[0],
	    height => $s[1],
	    type   => im::bpp8,
	    );
	$i->begin_paint;
	$i->color(cl::Red);
	$i->bar(0, 0, @s);
	$i->color(cl::White);
	$i->rectangle($b/2, $b/2, $s[0] - $b/2, $s[1] - $b/2);
	$i->font({size => 15, style => fs::Bold});
	$i->draw_text("ERROR!\n$filename\n$e",
		      $b, $b, $s[0] - $b, $s[1] - $b,
		      dt::Center|dt::VCenter|dt::Default);
	$i->end_paint;
	$self->image($i);
    }
    if ($self->popup->checked('overlay')) {
	$self->alignment($self->alignment == ta::Left ? ta::Right : ta::Left);
	$self->valignment($self->valignment == ta::Top ? ta::Bottom : ta::Top);
    } else {
	$self->valignment(ta::Middle);
	$self->alignment(ta::Center);
    }
    $self->{picture} = $picture;
    $self->{fileName} = $filename;
    $self->popup->checked('autozoom', 1);
    $self->apply_auto_zoom;
    $self->status;
}

sub on_paint { # update metadata label overlays, later in front of earlier
    my($self, $canvas) = @_;

    # PS: I've read somewhere that ist::Quadratic produces best
    # visual results for the scaled-down images, while ist::Sinc
    # and ist::Gaussian for the scaled-up. /dk = Dmitry Karasik
    $self->{scaling} = $self->zoom > 1 ? ist::Gaussian : ist::Quadratic;
    # $self->{scaling} = ist::Box; # fastest, but square pixels

#    warn "painting $self: ", $self->picture->pathtofile;
    $self->SUPERon_paint(@_);	# hack!!! see below!!!
    my $th = $self->{thumbviewer};
    my $x = $th->focusedItem + 1;
    my $y = $th->count;
    my($w, $h) = $self->size;
    if ($self->autoZoom and $y > 1) {
	my $each = $w / $y; # TODO: move to a new frame progress object
	$self->color(cl::LightGreen);
	$self->lineWidth(10);
	$self->lineEnd(le::Round);
	$self->polyline([$each * ($x - 1), $h - 5, $each * $x, $h - 5]);
	$self->polyline([$each * ($x - 1), 5, $each * $x, 5]);
	my($x, $y) = $th->xofy($th->focusedItem);
	if ($y > 1) {
	    $each = $h / $y;
	    $self->polyline([5, $h - $each * ($x - 1), 5, $h - $each * $x]);
	    # $self->polyline([$w - 5, $h - $each * ($x - 1), $w - 5, $h - $each * $x]);
	}
	    $self->color(cl::Fore);
    }
    $self->status(1);	      # update zoom label in case zoom changed
}

sub on_close {
    my $owner = $_[0]->{thumbviewer};
    $owner or return;
    $owner->owner->select;
}

sub autozoom {
    my($self, $which) = @_;
    $which and
	$self->autoZoom($self->popup->checked('autozoom'));
    if ($self->autoZoom) {
	$self->apply_auto_zoom;
    } else {
	$self->zoom(1);		# scroll to center:
	my @sz = $self->image->size;
	my @ar = $self->get_active_area(2);
	$self->deltaX($sz[0]/2 - $ar[0]/2);
	$self->deltaY($sz[1]/2 - $ar[1]/2);
    }
    $self->repaint;
    $self->autoZoom;
}

sub bigger {
    my($self) = @_;
    $self->autoZoom(0);
    $self->popup->checked('autozoom', 0);
    $self->zoom($self->zoom * 1.2);
}
sub smaller {
    my($self) = @_;
    $self->autoZoom(0);
    $self->popup->checked('autozoom', 0);
    $self->zoom($self->zoom / 1.2);
}

sub on_keydown
{
    my ( $self, $code, $key, $mod) = @_;
#    warn "keydown: @_";
    if ($key == kb::Enter) {
	return;			# now in sub autozoom
    }
    if ($key == kb::Escape) {	# return focus to caller
	$self->popup->checked('slideshow', 0);
	$self->slideshow;	# stop any show
	my $owner = $self->{thumbviewer};
	$owner->owner->select;
	return;
    }
    if ($code == ord 'm' or $code == ord '?' or $code == 13) { # popup menu
	my @sz = $self->size;
	if ($self->popup->checked('slideshow')) {
	    $self->popup->checked('slideshow', 0);
	    $self->slideshow;
	}
	$self->popup->popup(50, $sz[1] - 50); # near top left
	return;
    }
   if ($code == 9) {		# ctrl-i = info toggle, in menu
	$self->key_down(ord 'i');
    }
    # if ($key == kb::F11) {
    #	warn "f11 hit";
    #	$self->fullscreen(!$self->fullscreen);
    # }

    return if $self->{stretch};

    my $c = $code & 0xFF;
    return unless $c >= ord '0' and $c <= ord '9'
	or grep { $key == $_ } (
	kb::Left, kb::Right, kb::Down, kb::Up,
    );

    if ($self->autoZoom) {	# navigate both windows
	my $th = $self->{thumbviewer};
	$th->key_down($code, $key);
	my $idx = $th->focusedItem;
	my $this = $th->{items}[$idx];
	if ($this->isa('LPDB::Schema::Result::Path')) {
	    # warn "this node is a path $idx";
	    #    my ($self, $canvas, $idx, $x1, $y1, $x2, $y2, $sel, $foc, $pre, $col) = @_;
	    # Prima::LPDB::ThumbViewer::draw_path($self, $self, $idx, 5, 5, 200, 200, 0, 0, 0, 0);
	    # $self->draw_path($self, $idx, 5, 5, 200, 200, 0, 0, 0, 0);
	    $self->key_down($code, kb::Escape);
	} else {
	    $th->key_down(-1, kb::Enter); # don't re-raise myself
	}
	$self->clear_event;
	return;
    }
    $self->right if $key == kb::Right;
    $self->left	if $key == kb::Left;
    $self->down	if $key == kb::Down;
    $self->up	if $key == kb::Up;
}
sub right{my @d=$_[0]->deltas; $_[0]->deltas($d[0] + $_[0]->width/5, $d[1])}
sub left {my @d=$_[0]->deltas; $_[0]->deltas($d[0] - $_[0]->width/5, $d[1])}
sub up   {my @d=$_[0]->deltas; $_[0]->deltas($d[0], $d[1] - $_[0]->width/5)}
sub down {my @d=$_[0]->deltas; $_[0]->deltas($d[0], $d[1] + $_[0]->width/5)}

sub on_mousewheel {
    my($self, $mod, $x, $y, $z) = @_;
    if ($mod & km::Ctrl) {
	$z > 0 ? $self->bigger : $self->smaller;
    } elsif ($mod & km::Shift) {
	$self->autoZoom
	    ? $self->key_down(0, $z > 0 ? kb::Up : kb::Down)
	    : $z > 0 ? $self->left : $self->right;
    } else {
	$self->autoZoom
	    ? $self->key_down(0, $z > 0 ? kb::Left : kb::Right)
	    : $z > 0 ? $self->up : $self->down;
    }
    return;
}

sub status {
    my($self, $quick) = @_;
    my $win = $self->owner;
    my $img = $self->image;
    my $str;
    if ($img) {
	my $play = $self->popup->checked('slideshow') ? 'Play: ' : '';
	$str = $self->{fileName};
	$str =~ s/([^\\\/]*)$/$1/;
	$str = sprintf("%s%s (%dx%dx%d bpp)", $play, $1,
		       $img->width, $img->height, $img->type & im::BPP);
    } else {
	$str = '.Untitled';
    }
    $win->text($str);
    $win->name($str);
    $self->CENTER->hide;	# play/stop indicator
    my $th = $self->{thumbviewer};
    my $x = $th->focusedItem + 1;
    my $y = $th->count;
    my($w, $h) = $self->size;
    if ($self->popup->checked('info')) {
	$self->NW->show;
	$self->NE->show;
	$self->N->show;
	$self->SW->show;
	$self->SE->show;
	$self->S->show;
    } else {
	$self->NW->hide;
	$self->NE->hide;
	$self->N->hide;
	$self->SW->hide;
	$self->SE->hide;
	$self->S->hide;
	return;
    }
    my $im = $self->image or return;
    $im = $self->picture or return;
    $self->NW->text(sprintf("%.0f%% of %dx%d=%.2f",
			    $self->zoom * 100,
			    $im->width, $im->height,
			    $im->width / $im->height));
    $quick and return;		# only zoom has changed, all else remains same:
    $self->N->text($im->basename);
    $self->NE->text(sprintf '%.1fMP %.0fKB, %.0f%% = %d / %d',
			   $im->width * $im->height / 1000000,
			   $im->bytes / 1024,
			   $x / $y * 100, $x, $y);
    $self->NE->right($w - $self->{pad}); # hack!!! since growMode doesn't handle size changing
    my $info = $self->{exif}->ImageInfo($im->pathtofile);
    # use Data::Dumper;
    # warn "info $im: ", Dumper $info;
    my @info;
    my $make = $info->{Make} || '';
    push @info, $make if $make;
    (my $model = $info->{Model} || '') =~ s/$make//g; # redundant
    push @info, $model if $model;
    push @info, "$info->{ExposureTime}s"	if $info->{ExposureTime};
    push @info, $info->{FocalLength}		if $info->{FocalLength};
    push @info, "($info->{FocalLengthIn35mmFormat})"
	if $info->{FocalLengthIn35mmFormat};
    push @info, "f/$info->{FNumber}"		if $info->{FNumber};
    push @info, "ISO: $info->{ISO}"		if $info->{ISO};
    push @info, $info->{Flash}			if $info->{Flash};
    push @info, $info->{Orientation} if
	$info->{Orientation} and $info->{Orientation} =~ /Rotate/;
    ($x, $y) = $th->xofy($th->focusedItem);
    my $path = $im->dir->directory;
    $path .= " : $x / $y";
    $self->S->text($im->caption ? join "\n",
			  $im->caption, $path : $path);
    $self->SE->text(join "\n", @info);
    $self->SE->right($w - $self->{pad}); # hack!!! since growMode doesn't handle size changing
    $self->SW->text(scalar localtime $im->time);
}

sub delay {
    my($self, $name) = @_;
    $self->{seconds} ||= 4;
    $name =~ /faster/ and $self->{seconds} /= 2;
    $name =~ /slower/ and $self->{seconds} *= 2;
    $self->slideshow;
}
sub slideshow {
    my($self) = @_;
    $self->{timer} ||= Prima::Timer->create(
	timeout => 3000,	# milliseconds
	onTick => sub {
	    $self->autoZoom or return;
	    $self->key_down(0, kb::Right );
	    $self->CENTER->hide;
	}
	);
    $self->{seconds} ||= 4;
    my $sec = $self->{seconds};
    if ($self->popup->checked('slideshow') and $self->autoZoom) {
	$self->CENTER->text(">> PLAY @ $sec seconds >>");
	$self->CENTER->show;
	$self->{timer}->timeout($sec * 1000);
	$self->{timer}->start;
    } else {
	$self->CENTER->text("[[ STOP @ $sec seconds ]]");
	$self->CENTER->show;
	$self->{timer}->stop;
    }
}

sub metadata {			# exiftool -G in a window
    my($self) = @_;
    $self->picture or return;
    my $file = $self->picture->pathtofile or return;
    $file =~ s/(\W)/\\$1/g;
    my $out = `exiftool -G $file`;
    $out or warn "exiftool $file returned no output" and return;
    my $w = Prima::Window-> create(
	packPropagate => 0,
	text          => $file,
	onDestroy     => sub { $self->owner->select },
	size => [ $self->owner->size ],
	# menuItems => [
	popupItems => [
	    ['~Escape back to Image' => 'Escape' => kb::Escape => sub { $_[0]->close } ],
	]);
    $w->insert('Prima::Edit',
	       pack		=> { expand => 1, fill => 'both'},
	       textRef		=> \$out,
	       font		=> { name => 'Courier' },
	       readOnly		=> 1,
	       syntaxHilite	=> 1,
	       hiliteNumbers	=> cl::Fore, # disable most hilighting
	       hiliteQStrings	=> cl::Fore,
	       hiliteQQStrings	=> cl::Fore,
	       hiliteChars	=> [], # database related items:
	       hiliteIDs	=> [[qw(Width Height Size Orientation Subject
				     Keywords Date Time Original Created
				     Name Directory Caption Abstract)],
				    cl::LightBlue],
	       hiliteREs	=> ['(\[\w+\])' => cl::LightRed,
				    '( : )' => cl::LightGreen,
	       ],
	);
}

# !!! hack !!! this copy from SUPER tweaked only to support image
# !!! {overlay} mode.  This option should be in SUPER instead.
sub SUPERon_paint
{
	my ( $self, $canvas) = @_;
	my @size   = $self-> size;

	$self-> rect_bevel( $canvas, Prima::rect->new(@size)->inclusive,
		width  => $self-> {borderWidth},
		panel  => 1,
		fill   => $self-> {image} ? undef : $self->backColor,
	);
	return 1 unless $self->{image};

	my @r = $self-> get_active_area( 0, @size);
	$canvas-> clipRect( @r);
	$canvas-> translate( @r[0,1]);
	my $imY  = $self-> {imageY};
	my $imX  = $self-> {imageX};
	my $z = $self-> {zoom};
	my $imYz = int($imY * $z);
	my $imXz = int($imX * $z);
	my $winY = $r[3] - $r[1];
	my $winX = $r[2] - $r[0];
	my $deltaY = ($imYz - $winY - $self-> {deltaY} > 0) ? $imYz - $winY - $self-> {deltaY}:0;
	my ($xa,$ya) = ($self-> {alignment}, $self-> {valignment});
	my ($iS, $iI) = ($self-> {integralScreen}, $self-> {integralImage});
	my ( $atx, $aty, $xDest, $yDest);

	if ( $self->{stretch}) {
		$atx = $aty = $xDest = $yDest = 0;
		$imXz = $r[2] - $r[0];
		$imYz = $r[3] - $r[1];
		goto PAINT;
	}

	if ( $imYz < $winY) {
		if ( $ya == ta::Top) {
			$aty = $winY - $imYz;
		} elsif ( $ya != ta::Bottom) {
			$aty = int(($winY - $imYz)/2 + .5);
		} else {
			$aty = 0;
		}
		unless ($self->popup->checked('overlay')) {
		    $canvas-> clear( 0, 0, $winX-1, $aty-1) if $aty > 0;
		    $canvas-> clear( 0, $aty + $imYz, $winX-1, $winY-1) if $aty + $imYz < $winY;
		}
		$yDest = 0;
	} else {
		$aty   = -($deltaY % $iS);
		$yDest = ($deltaY + $aty) / $iS * $iI;
		$imYz = int(($winY - $aty + $iS - 1) / $iS) * $iS;
		$imY = $imYz / $iS * $iI;
	}

	if ( $imXz < $winX) {
		if ( $xa == ta::Right) {
			$atx = $winX - $imXz;
		} elsif ( $xa != ta::Left) {
			$atx = int(($winX - $imXz)/2 + .5);
		} else {
			$atx = 0;
		}
		unless ($self->popup->checked('overlay')) {
		    $canvas-> clear( 0, $aty, $atx - 1, $aty + $imYz - 1) if $atx > 0;
		    $canvas-> clear( $atx + $imXz, $aty, $winX - 1, $aty + $imYz - 1) if $atx + $imXz < $winX;
		}
		$xDest = 0;
	} else {
		$atx   = -($self-> {deltaX} % $iS);
		$xDest = ($self-> {deltaX} + $atx) / $iS * $iI;
		$imXz = int(($winX - $atx + $iS - 1) / $iS) * $iS;
		$imX = $imXz / $iS * $iI;
	}

PAINT:
	$canvas-> clear( $atx, $aty, $atx + $imXz, $aty + $imYz)
	    if $self-> {icon} and ! $self->popup->checked('overlay');

	if ( $self-> {scaling} != ist::Box && ( $imXz != $imX || $imYz != $imY ) ) {
		my (
			$xFrom, $yFrom,
			$xDestLen, $yDestLen,
			$xLen, $yLen
		) = (
			0, 0,
			$imXz, $imYz,
			$imXz, $imYz
		);
		if ( $iS > $iI ) {
			# scaling kernel may need pixels beyond the cliprect
			if ( $xDest >= $iI) {
				$xDest -= $iI;
				$imXz  += $iS;
				$imX   += $iI;
				$xFrom += $iS;
			}
			if ( $xDest + $imX <= $self->{imageX} - $iI ) {
				$imX   += $iI;
				$imXz  += $iS;
			}
			if ( $yDest >= $iI ) {
				$yDest -= $iI;
				$imYz  += $iS;
				$imY   += $iI;
				$yFrom += $iS;
			}
			if ( $yDest + $imY <= $self->{imageY} - $iI ) {
				$imY   += $iI;
				$imYz  += $iS;
			}
		}
		my $i = $self->{image}->extract( $xDest, $yDest, $imX, $imY );
		$i->scaling( $self->{scaling} );
		$i->size( $imXz, $imYz );
		return $canvas-> put_image_indirect(
			$i,
			$atx, $aty,
			$xFrom, $yFrom,
			$xDestLen, $yDestLen,
			$xLen, $yLen,
			rop::CopyPut
		);
	}

	return $canvas-> put_image_indirect(
		$self-> {image},
		$atx, $aty,
		$xDest, $yDest,
		$imXz, $imYz, $imX, $imY,
		rop::CopyPut
	);
}

1;

=pod

=head1 SEE ALSO
L<Prima::ThumbViewer>, L<LPDB>

=head1 AUTHOR

Timothy D Witham <twitham@sbcglobal.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2013-2022 Timothy D Witham.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
