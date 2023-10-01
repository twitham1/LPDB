=head1 NAME

Prima::LPDB::ImageViewer - ImageViewer for Prima::LPDB::ThumbViewer

=head1 DESCRIPTION

Like C<Prima::ImageViewer> but with a keyboard driven interface for
C<LPDB>.  A single window is reused to show many images over time and
overlay with metadata.

=cut

package Prima::LPDB::ImageViewer;

use strict;
use warnings;
use Prima::ImageViewer;
use Prima::Edit;		# for ExifTool metadata window
# use Prima::LPDB::Fullscreen;	# could someday promote to Prima?

use vars qw(@ISA);
@ISA = qw(Prima::ImageViewer);

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
#	zoomPrecision => 1000,	# this sometimes breaks aspect ratio
	stretch => 0,
	timer => undef,
	seconds => 4,
	buffered => 0,		# 1 is not good for overlay mode
	popupItems => [
	    ['~Escape back to Thumb Gallery', sub { $_[0]->key_down(0, kb::Escape) } ],
	    [],
	    ['(info0',	'~No Information Overlay',	'status'],
	    ['info1',	'Progress ~Markers',		'status'],
	    ['*info2',	'Brief ~Information', 'i', 0,	'status'],
	    [')info3',	'~Verbose Information',		'status'],
	    [],
	    ['@slideshow', '~Play/Pause Slide Show', 'p', ord 'p', 'slideshow'],
	    ['*@loop',     '~Loop Slide Show',       'l', ord 'l', 'slideshow'],
	    ['faster',     'F~aster Show',           'a', ord 'a', 'delay'],
	    ['slower',     '~Slower Show',           's', ord 's', 'delay'],
	    ['@autoplay',  'A~uto Play Videos',      'v', ord 'v', 'slideshow'],
	    [],
	    ['@overlay', '~Overlay Images',  'o', ord 'o', sub { $_[0]->{overlay} = $_[2]; $_[0]->repaint }],
	    ['exiftool', 'Meta~Data Window', 'd', ord 'd', 'metadata'],
	    [],
	    ['fullscreen', '~Full Screen', 'f', ord 'f', sub { $_[0]->owner->fullscreen(-1) }],
	    ['bigger',     '~Zoom In',     'z', ord 'z', sub { $_[0]->bigger }],
	    ['smaller',    'Zoom ~Out',    'q', ord 'q', sub { $_[0]->smaller }],
	    ['*@autozoom', 'Au~to Zoom', 'Enter', kb::Enter, 'autozoom' ],
	    ['help', '~Help', 'h', ord('h'), 'help'],
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

    return %profile;
}

sub picture { $_[0]->{picture} || undef }
sub viewimage
{
    my ($self, $picture) = @_;
    my $filename = $picture->pathtofile or return;
    my $i;			# image
    if (my $dur = $picture->hms and # cid 2 is high resolution:
	$i = $self->{thumbviewer}->{thumb}->get($picture->file_id, 2)) {
	$self->image($i);
	$self->popup->checked('autoplay') or
	    $self->say(">> Enter to play $dur >>");
    } elsif ($i = Prima::Image->load($filename)) {
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
    $self->autoZoom(1);
    $self->apply_auto_zoom;
    $self->status;
    if ($picture->duration and $self->popup->checked('autoplay')) {
	$self->key_down(kb::Enter, kb::Enter);
    }
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
    if ($self->autoZoom and $y > 1 and ! $self->popup->checked('info0')) {
	# TODO: move to a new frame progress object
	my $s = 6;		# size of line
	$self->lineWidth($s);
	$self->color(cl::LightGreen);
	$self->lineEnd(le::Round);
	$s /= 2;		# now position from edge
	my $each = $w / $y;
	my($b, $e) = ($each * ($x - 1), $each * $x);
	$e > $b + $s or $e = $b + $s; # minimum indicator length
	$self->polyline([$b, $h - $s, $e, $h - $s]);
	$self->polyline([$b, $s, $e, $s]);
	my($x, $y) = $th->xofy($th->focusedItem);
	if ($y > 1) {
	    $each = $h / $y;
	    my($b, $e) = ($each * ($x - 1), $each * $x);
	    $e > $b + $s or $e = $b + $s;
	    $self->polyline([$s, $h - $b, $s, $h - $e]);
	    $self->polyline([$w - $s, $h - $b, $w - $s, $h - $e]);
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

sub autozoom {			# Enter == zoom picture or play video
    my($self, $which) = @_;
    my $pic;
    if ($pic = $self->picture and $pic->duration) { # video
	my $file = $pic->pathtofile or return;
	my @cmd = qw(ffplay -fs -loglevel warning);
	$self->popup->checked('autoplay') and push @cmd, '-autoexit';
	unless (system(@cmd, $file) == 0) {
	    warn my $msg = "@cmd $file failed";
	    message($msg, mb::OK);
	}
	$self->owner->select;	# try not to lose focus
	return;
    }
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

{	   # zoom in/out on center point by calculating the new deltas
    my $factor = 1.2;
    sub bigger {
	my($self) = @_;
	$self->autoZoom(0);
	$self->popup->checked('autozoom', 0);
	my($w, $h) = $self->size;
	my($x, $y) = $self->deltas;
	my $z = $self->zoom;
	$z * $factor < 2.5 or return;
	$self->zoom($z * $factor);
	$self->deltas(($x + $w/2) * $factor - $w/2,
		      ($y + $h/2) * $factor - $h/2);
    }
    sub smaller {
	my($self) = @_;
	$self->autoZoom(0);
	$self->popup->checked('autozoom', 0);
	my($w, $h) = $self->size;
	my($x, $y) = $self->deltas;
	my $z = $self->zoom;
	$z / $factor > 0.09 or return;
	$self->zoom($z / $factor);
	$self->deltas(($x + $w/2) / $factor - $w/2,
		      ($y + $h/2) / $factor - $h/2);
    }
}

sub on_keydown
{
    my ( $self, $code, $key, $mod) = @_;
#    warn "keydown: @_";
    if ($key == kb::Enter) {
	return;			# now in sub autozoom
    }
    if ($key == kb::Escape) {	# return focus to caller
	if ($self->popup->checked('slideshow')) {
	    $self->popup->checked('slideshow', 0);
	    $self->slideshow;	# stop the show
	}
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
    if ($code == 9) {		# ctrl-i = info cycle, in menu
	$self->key_down(ord 'i');
	return;
    } elsif ($code == ord 'i') {
	$self->infocycle;
	return;
    } elsif ($code == 6) {	# ctrl-shift-f = faster remote button
	$self->key_down(ord 'a');
	return;
    } elsif ($code == 2) {	# ctrl-shift-b = slower remote button
	$self->key_down(ord 's');
	return;
    }	
    # if ($key == kb::F11) {
    # 	warn "f11 hit";
    # 	$self->fullscreen(-1);
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
	my $this = $th->item($idx);
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
sub up   {my @d=$_[0]->deltas; $_[0]->deltas($d[0], $d[1] - $_[0]->height/5)}
sub down {my @d=$_[0]->deltas; $_[0]->deltas($d[0], $d[1] + $_[0]->height/5)}

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

sub on_mouseclick {		# click/touch zones
    my($self, $button, $mod, $x, $y) = @_;
    my($w, $h) = $self->size;
    my @key = reverse([kb::Escape,	kb::Up,		ord 'q'],
		      [kb::Left,	kb::Enter,	kb::Right],
		      [ord 'm',		kb::Down,	ord 'z']);
    $button == mb::Middle
	and $self->key_down(0, kb::Escape);
    $button == mb::Left or return;
    my $key = $key[int($y / $h * 3)][int($x / $w * 3)];
    $self->key_down($key, $key);
}

sub help {			# click/touch zone documentation
    my($self) = @_;
    my($w, $h) = $self->size;
    $self->begin_paint;
    $self->color(cl::Yellow);
    $self->backColor(cl::Black);
    $self->lineWidth(3);
    my @desc = (
	"Escape\nback to Grid", "Up\nPrevious Row", "Q\nZoom Out",
	"Left\nPrevious Picture", "Enter\nToggle Zoom", "Right\nNext Picture",
	"M\nMenu Options", "Down\nNext Row", "Z\nZoom In");
    for my $y ($h * 2 / 3, $h / 3, 0) {
	for my $x (0, $w / 3, $w * 2 / 3) {
	    my $txt = shift @desc; $txt =~ s/(\w+)/<$1>/;
	    $self->draw_text($txt, $x, $y, $x + $w / 3, $y + $h / 3,
			     dt::Center | dt::VCenter | dt::NewLineBreak);
	    $self->rectangle($x, $y, $x + $w / 3, $y + $h / 3);
	}
    }
    $self->end_paint;
}

sub infocycle {		     # cycle info overlay level, used by i key
    my($self) = @_;
    my $m = $self->popup;
    if ($m->checked('info0')) {		$m->checked('info1', 1);
    } elsif ($m->checked('info1')) {	$m->checked('info2', 1);
    } elsif ($m->checked('info2')) {	$m->checked('info3', 1);
    } elsif ($m->checked('info3')) {	$m->checked('info0', 1);
    }
    $self->status;
}

sub status {	       # update window title, call info() text overlay
    my($self, $quick) = @_;
    my $win = $self->owner;
    my $img = $self->image;
    my $str;
    my $m = $self->popup;
    if ($img) {
	my $play = $m->checked('slideshow') ? 'Play: ' : '';
	$str = $self->{fileName};
	$str =~ s/([^\\\/]*)$/$1/;
	$str = sprintf('%s%s (%dx%dx%d bpp)', $play, $1,
		       $img->width, $img->height, $img->type & im::BPP);
    } else {
	$str = '.Untitled';
    }
    $win->text($str);
    $win->name($str);
    $self->CENTER->hide		# temporary message expired?
	if time > ($self->{expires} || 0);
    my $i;			# info level
    map { $i = $_ if $m->checked("info$_") } 0 .. 3;
    unless ($i > 1) {
	$self->NW->hide; $self->N->hide; $self->NE->hide;
	$self->SW->hide; $self->S->hide; $self->SE->hide;
	$self->repaint;
	return;
    }
    $self->info($quick && $quick eq '1', $i);
}

sub info {			# update text overlay, per info level
    my($self, $quick, $i) = @_;
    my $th = $self->{thumbviewer};
    my $x = $th->focusedItem + 1; # total progress, horizontal
    my $X = $th->count;
    my($w, $h) = $self->size;
    my $im = $self->picture or return;
    $self->NW->text($i == 3 ?
		    sprintf('%.0f%% of %dx%d=%.2f',
			    $self->zoom * 100,
			    $im->width, $im->height,
			    $im->width / $im->height)
		    : sprintf('%.0f%%', $self->zoom * 100));
    $self->NW->show;
    $quick and return; # only zoom has changed, all else remains same:
    my $cap = $i == 3 ? $im->basename : '';
    $cap = $im->caption . "\n$cap" if $im->caption;
    $self->N->text($cap);
    $self->N->top($h - $self->{pad}); # hack!!! since growMode doesn't handle size changing
    ($i > 1 and $cap) ? $self->N->show : $self->N->hide;
    $self->NE->text($i > 2 ?
		    sprintf '%.1fMP %.0fKB, %.0f%% %d / %d',
		    $im->width * $im->height / 1000000,
		    $im->bytes / 1024,
		    $x / $X * 100, $x, $X
		    : sprintf '%.0f%% %d / %d',
		    $x / $X * 100, $x, $X);
    $self->NE->right($w - $self->{pad}); # hack!!! since growMode doesn't handle size changing
    $self->NE->show;
    my($y, $Y) = $th->xofy($th->focusedItem); # gallery progress, vertical
    my @info;
    if ($i == 3) {
	my $info = $self->{exif}->ImageInfo($im->pathtofile);
	# use Data::Dumper;
	# warn "info $im: ", Dumper $info;
	my $make = $info->{Make} || '';
	push @info, $make if $make;
	(my $model = $info->{Model} || '') =~ s/$make//g; # redundant
	push @info, $model if $model;
	push @info, "$info->{ExposureTime}s"	if $info->{ExposureTime};
	push @info, $info->{FocalLength}	if $info->{FocalLength};
	push @info, "($info->{FocalLengthIn35mmFormat})"
	    if $info->{FocalLengthIn35mmFormat};
	push @info, "f/$info->{FNumber}"	if $info->{FNumber};
	push @info, "ISO: $info->{ISO}"		if $info->{ISO};
	push @info, $info->{Flash}		if $info->{Flash};
	push @info, $info->{Orientation}	if $info->{Orientation} and
	    $info->{Orientation} =~ /Rotate/;
	push @info, $im->hms if $im->hms;
	$self->SE->text(join "\n", @info);
	$self->SE->right($w - $self->{pad}); # hack!!! since growMode doesn't handle size changing
	$self->SE->transparent(0);	     # 1 flashes too much
	$self->SE->show;
    } elsif ($i == 2) {
	my $tmp = $th->gallery(-1) > 1 ?
	    $th->gallery($x - 1) . ' / ' . $th->gallery(-1) . ',' : '';
	$self->SE->text(($im->hms || '') . " $tmp $y / $Y ");
	$self->SE->right($w - $self->{pad}); # hack!!! since growMode doesn't handle size changing
	$self->SE->transparent(0);
	$self->SE->show;
    } else {
	$self->SE->hide;
    }
    $self->S->show;
    $i == 3 ? $self->S->text(sprintf ' %d / %d - %s - %d / %d ',
			     $th->gallery($x - 1), $th->gallery(-1),
			     $im->dir->directory, $y, $Y)
	: $self->S->hide;
    $self->SW->text(scalar localtime $im->time);
    $self->SW->show;
}

# show temporary message in center of the screen
sub say {
    my($self, $message, $seconds) = @_;
    $self->CENTER->text($message);
    $self->CENTER->show;	# hidden by ->status above after:
    $self->{expires} = time + ($seconds || 0);
    $self->repaint;
}

sub _hms {			# sec -> hh:mm:ss
    my($sec) = @_;
    return sprintf '%02d:%02d:%02d',
	$sec / 3600, $sec % 3600 / 60, $sec % 60
}
my @delay =qw/0 0.125 0.25 0.5 1 2 3 4 5 7 10 15 20 30 45 60 90 120/;
sub delay {
    my($self, $name) = @_;
    my $idx = $self->{delayidx} || 7; # default = 4 seconds
    $name =~ /faster/ and $idx--; $idx = 1 if $idx < 1;
    $name =~ /slower/ and $idx++; $idx = $#delay if $idx > $#delay;
    $self->{seconds} = $delay[$idx];
    $self->{delayidx} = $idx;
    $self->slideshow;
}
sub slideshow {
    my($self) = @_;
    $self->{timer} ||= Prima::Timer->create(
	timeout => 3000,	# milliseconds
	onTick => sub {
	    $self->autoZoom or return;
	    my $th = $self->{thumbviewer};
	    my $x = $th->focusedItem + 1;
	    my $y = $th->count;
	    if ($self->popup->checked('slideshow') and $x == $y) {
		if ($self->popup->checked('loop')) {
		    warn "looping show";
		    $self->key_down(ord '0'); # move to first
		} else {
		    warn "stopping show";
		    $self->popup->checked('slideshow', 0);
		    $self->slideshow;
		}
	    } else {		# next picture
		$self->key_down(0, kb::Right );
	    }
	}
	);
    my $sec = $self->{seconds} || 4; # set by delay above
    my $n = $self->{thumbviewer}->count;
    my $d = $self->{thumbviewer}->duration;
    my $tot = $n * $sec + $d;
    my $t = '';			# show timing information
    $d and $t = "\nVideo AutoPlay " .
	($self->popup->checked('autoplay') ? 'ON' : 'OFF');
    $t .= sprintf "\n%s picture time%s", _hms($n * $sec),
	$d ? sprintf(' %2.0f%%', $n * $sec / $tot * 100) : '';
    $d and $t .= sprintf "\n%s  video  time %2.0f%%", _hms($d),
	$d / $tot * 100;
    $d and $t .= sprintf "\n%s  total  time", _hms($tot);
    $t .= "\nLoop show " .
	($self->popup->checked('loop') ? 'ON' : 'OFF');

    if ($self->popup->checked('slideshow') and $self->autoZoom) {
	$self->say(">> ~PLAY @ $sec seconds >>$t", 3);
	$self->{timer}->timeout($sec * 1000);
	$self->{timer}->start;
	system(qw/xset s off/);	# hack!!! disable screensaver
	if (my $tmp = `xset q`) {
	    $self->{dpms} = $tmp =~ /DPMS is Enabled/i ? 1 : 0;
	    # warn "DPMS is $self->{dpms}";
	}
	$self->{dpms} and system(qw/xset -dpms/);
    } else {
	$self->say("[[ ~PAUSE @ $sec seconds ]]$t", 3);
	$self->{timer}->stop;
	system(qw/xset s default/); # hack!!! reenable screensaver
	$self->{dpms} and system(qw/xset +dpms/);
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
				    cl::LightGreen],
	       hiliteREs	=> ['(\[\w+\])' => cl::LightBlue,
				    '( : )' => cl::LightRed,
	       ],
	);
}

# !!! hack !!! this copy from SUPER tweaked only to support image
# !!! {overlay} mode.  This option should be in SUPER instead.
sub SUPERon_paint
{
	my ( $self, $canvas) = @_;
	my @size   = $self-> size;
	$self-> draw_border( $canvas, $self-> {image} ? undef : $self->backColor, @size);
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
		unless ($self->{overlay}) {
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
		unless ($self->{overlay}) {
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
	    if $self-> {icon} and ! $self->{overlay};

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
			my $ks = {
				ist::Triangle,  1,
				ist::Quadratic, 2,
				ist::Sinc,      4,
				ist::Hermite,   1,
				ist::Cubic,     2,
				ist::Gaussian,  2,
			}->{$self->{scaling}};

			if ( $xDest >= $iI * $ks) {
				$xDest -= $iI * $ks;
				$imXz  += $iS * $ks;
				$imX   += $iI * $ks;
				$xFrom += $iS * $ks;
			}
			if ( $xDest + $imX <= $self->{imageX} - $iI * $ks ) {
				$imX   += $iI * $ks;
				$imXz  += $iS * $ks;
			}
			if ( $yDest >= $iI * $ks ) {
				$yDest -= $iI * $ks;
				$imYz  += $iS * $ks;
				$imY   += $iI * $ks;
				$yFrom += $iS * $ks;
			}
			if ( $yDest + $imY <= $self->{imageY} - $iI * $ks ) {
				$imY   += $iI * $ks;
				$imYz  += $iS * $ks;
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

L<lpgallery>, L<Prima::LPDB::ThumbViewer>, L<LPDB>

=head1 AUTHOR

Timothy D Witham <twitham@sbcglobal.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2013-2022 Timothy D Witham.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
