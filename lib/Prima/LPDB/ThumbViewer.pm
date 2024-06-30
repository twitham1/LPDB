=head1 NAME

Prima::LPDB::ThumbViewer - Browse a tree of image thumbnails from LPDB

=head1 DESCRIPTION

The heart of C<lpgallery>, this class connects
C<Prima::LPDB::TileViewer> to an C<LPDB> database, presenting its
paths and pictures in a keyboard- driven interactive thumbnail
browser.  It also [re]creates a C<Prima::LPDB::ImageViewer> to display
a selected picture.

=cut

package Prima::LPDB::ThumbViewer;
use strict;
use warnings;
use POSIX qw/strftime/;
use Time::HiRes qw(gettimeofday tv_interval); # for profiling
use LPDB::VFS;
use LPDB::Thumbnail;
use Prima::FrameSet;
use Prima::Label;
use Prima::MsgBox;
use Prima::EventHook;		# for remote control key aliases
use Prima::LPDB::TileViewer;	# could someday promote to Prima?
use Prima::LPDB::ImageViewer;
use Prima::LPDB::Fullscreen;	# could someday promote to Prima?
use Prima::LPDB::PointerHider;	# could someday promote to Prima?

use vars qw(@ISA);
@ISA = qw(Prima::LPDB::TileViewer);

my $lv;
sub profile_default
{
    my $def = $_[ 0]-> SUPER::profile_default;
    my %prf = (
	# hiliteBackColor	=> 0x74EE15, # neon green
	# hiliteBackColor	=> 0xFFE700, # neon yellow
	# hiliteBackColor	=> 0xF000FF, # neon magenta
	# hiliteBackColor	=> cl::Magenta,
	popupItems => [
	    ['escape' => '~Escape back to Thumb Viewer', sub {}],
	    ['navto' => 'Navigate to this image in' => [
		 # replaced by on_selectitem
		 ['/[Folders]/' => '/[Folders]/' => 'goto'],
	     ]],
	    [],
	    ['AND Filters' => [
		 ['clear'	=> 'Clear All Filters' => sub {
		     map { $_[0]->popup->checked($_, 1) }
		     qw/bothfiles bothshapes unlimited/;
		     map { $_[0]->popup->checked($_, 0) }
		     qw/tags captions/;
		     $_[0]->goto($_[0]->current);
		  }],
		 [],
		 ['*(bothfiles'	=> 'Both Files:'    => 'sorter'],
		 ['pictures'	=> 'Still Pictures' => 'sorter'],
		 [')videos'	=> 'Motion Videos'  => 'sorter'],
		 [],
		 ['*(bothshapes'=> 'Both Shapes:' => 'sorter'],
		 ['portrait'	=> 'Portrait'	  => 'sorter'],
		 [')landscape'	=> 'Landscape'	  => 'sorter'],
		 [],
		 ['@tags'	=> 'Tags'	=> 'sorter'],
		 ['@captions'	=> 'Captions'	=> 'sorter'],
		 [],
		 ['*(unlimited'	=> 'Unlimited or latest:' => 'sorter'],
		 ['year10'	=> '10 Years'	=> 'sorter'],
		 ['year5'	=> '5 Years'	=> 'sorter'],
		 ['year2'	=> '2 Years'	=> 'sorter'],
		 ['year1'	=> '1 Year'	=> 'sorter'],
		 ['quarter'	=> '1 Quarter'	=> 'sorter'],
		 [')month'	=> '1 Month'	=> 'sorter'],
	     ]],
	    ['Sort' => [
		 ['Paths' => [
		      ['*(pname'=> 'Name (default)'	=> 'sorter'],
		      ['pfirst'	=> 'Begin Time'		=> 'sorter'],
		      ['pmid'	=> 'Middle Time'	=> 'sorter'],
		      ['plast'	=> 'End Time'		=> 'sorter'],
		      [')prnd'	=> 'Random'		=> 'sorter'],
		      [],
		      ['*(pasc'	=> 'Ascending (default)' => 'sorter'],
		      [')pdsc'	=> 'Descending'		=> 'sorter'],
		  ]],
		 ['Gallery Groups' => [
		      ['(gname'	=> 'Name'			=> 'sorter'],
		      ['*gfirst' => 'Begin Time (default)'	=> 'sorter'],
		      ['glast'	=> 'End Time'			=> 'sorter'],
#['grnd'	=> 'Random'	=> 'sorter'], # !!! currently doesn't work, as it breaks the groups, same as skip:
		      [')gskip'	=> 'Ungrouped'			=> 'sorter'],
		      [],
		      ['*(gasc'	=> 'Ascending (default)'	=> 'sorter'],
		      [')gdsc'	=> 'Descending'			=> 'sorter'],
		  ]],
		 ['Images' => [
		      ['(inone'	=> 'Fast (database order)'	=> 'sorter'],
		      ['iname'	=> 'Name'			=> 'sorter'],
		      ['*itime'	=> 'Time (default)'		=> 'sorter'],
		      ['isize'	=> 'Size'			=> 'sorter'],
		      [')irnd'	=> 'Random'			=> 'sorter'],
		      [],
		      ['*(iasc'	=> 'Ascending (default)'	=> 'sorter'],
		      [')idsc'	=> 'Descending'			=> 'sorter'],
		  ]],
		 ['Mixed Folders' => [
		      ['*(galsfirst' => 'Galleries First (default)' => 'sorter'],
		      [')picsfirst'  => 'Images First'		    => 'sorter'],
		  ]],

	     ]],
	    ['Random Stack Centers' => [
		 ['*@csel'	=> 'Selection (default)'	=> sub {}],
		 [],
		 ['(cnone'	=> 'No Others'			=> sub {}],
		 ['corder'	=> 'In Order'			=> sub {}],
		 ['*)crandom'	=> 'Random (default)'		=> sub {}],
		 [],
		 ['(c250', '4 per second',   sub { $_[0]->{cycler}->timeout(250)}],
		 ['c333' , '3 per second',   sub { $_[0]->{cycler}->timeout(333)}],
		 ['*c500', '2 per second (default)', sub { $_[0]->{cycler}->timeout(500)}],
		 ['c1000', '1 per second',   sub { $_[0]->{cycler}->timeout(1000)}],
		 ['c2000', '1 per 2 seconds', sub { $_[0]->{cycler}->timeout(2000)}],
		 ['c3000', '1 per 3 seconds', sub { $_[0]->{cycler}->timeout(3000)}],
		 [')c4000','1 per 4 seconds', sub { $_[0]->{cycler}->timeout(4000)}],
		 ]],
	    ['*@croppaths', 'Crop ~Gallery Stacks', 'g', ord 'g', sub { $_[0]->repaint }],
	    ['@cropimages', 'Crop Images',  'n', ord 'n', sub { $_[0]->repaint }],
	    ['*@videostack','Stack ~Videos','v', ord 'v', sub { $_[0]->repaint }],
	    ['@buffered', 'Hide Screen Updates', sub { $_[0]->buffered($_[2]) }],
	    [],
	    ['fullscreen',  '~Full Screen', 'f', ord 'f', sub { $_[0]->owner->fullscreen(-1) }],
	    ['smaller',     'Zoom Out',     'a', ord 'a', sub { $_[0]->smaller }],
	    ['bigger',      'Zoom In',      's', ord 's', sub { $_[0]->bigger }],
	    [],
	    ['galprev', 'Previous Gallery', 'u', ord 'u', 'galprev'],
	    ['galprev', 'Next Gallery',     'o', ord 'o', 'galnext'],
	    ['help', '~Help', 'h', ord 'h', sub { $::application->open_help("file://$0") }],
	    ['quit', '~Quit', 'q', ord 'q', sub { $::application->close }],
	]);
    @$def{keys %prf} = values %prf;
    return $def;
}
{				# key aliases that push other keys
    my %keymap = (
	ord 'i'		=> [0, kb::Up], # home row arrows around u/o prev/next
	ord 'j'		=> [0, kb::Left],
        ord 'k'		=> [0, kb::Down],
        ord 'l'		=> [0, kb::Right],
	kb::F11		=> [ord 'f'], # fullscreen toggle
	kb::Menu	=> [ord 'm'], # modern media control keys
	kb::BrowserHome	=> [ord 'n'], # info
	kb::BrowserBack	=> [0, kb::Escape],
	kb::MediaPlay	=> [ord 'p'],
	kb::MediaPrevTrack => [ord 'u'], # prev gal
	kb::MediaNextTrack => [ord 'o'], # next gal
	ord('B') - 64	=> [ord 'a'], # Ctrl-B = Back (ARC-1100)
	kb::AudioRewind	=> [ord 'a'],
	ord('F') - 64	=> [ord 's'], # Ctrl-F = Forward
	kb::AudioForward => [ord 's'],
	ord('T') - 64	=> [ord 'g'], # Ctrl-T = Crop (yellow)
	kb::Return	=> -1,	      # no-op, different than:
	ord('M') - 64	=> [ord 'm'], # Ctrl-M = Menu (blue)
	ord('I') - 64	=> [ord 'n'], # Ctrl-I = Info (green)
	# ord 'E' - 64	=> [ord 'm'], # Ctrl-E = ???? (red)
	);
    sub hook {
	my ( $my_param, $object, $event, @params) = @_;
	# warn "Object $object received event $event @params\n";
	if ($event eq 'KeyDown') {
	    my ($code, $key, $mod) = @params;
	    if (my $k = ($keymap{$key} || $keymap{$code} || 0)) {
		$k > 0 or return 1;
		# warn "hitting @$k";
		$object->key_down(@$k);
		return 0;
	    }
	}
	return 1;
    }
    sub keyaliases {
	Prima::EventHook::install( \&hook,
			       param    => {},
			       object   => $::application,
			       # event    => [qw(KeyDown Menu Popup)],
			       event    => [qw(KeyDown)],
			       children => 1
	    );
    }
}
sub lpdb { $_[0]->{lpdb} }
sub vfs { $_[0]->{vfs} }
sub thumb { $_[0]->{thumb} }
sub init {
    my $self = shift;
    my(%hash) = @_;
    my %profile = $self->SUPER::init(@_);
    $self->{lpdb} = $hash{lpdb} or die "lpdb object required";
    $self->{vfs} = new LPDB::VFS($self->{lpdb});
    $self->{thumb} = new LPDB::Thumbnail($self->{lpdb});
    $self->{viewer} = undef;
    $self->{firstlast} = '';	# cache of first/last viewed
    $self->{cwd} = '/';

    # This appears to speed up thumbnail generation, but it might
    # deadlock more than 1 run at a time, a case I never have
    $self->{timer} = Prima::Timer->create(
	timeout => 5000,	# milliseconds
	onTick => sub {
	    # warn "tick!\n";
	    $self->{lpdb}->{tschema}->txn_commit;
	    $self->{lpdb}->{tschema}->txn_begin;
	}
	);
    $self->{lpdb}->{tschema}->txn_begin;
    $self->{timer}->start;

    $self->{cycler} = Prima::Timer->create( # stack center cycler
	timeout => 500,		# milliseconds
	onTick => sub { $self->stackcenter },
	);
    $self->{cycler}->start;

    $self->insert('Prima::LPDB::PointerHider');

    $self->packForget; # to get packs around the perimeter of the SUPER widget

    my $top = $self->owner->insert('Prima::Label',
				   name => 'NORTH',
				   text => '',
				   transparent => 1, # hack, using label as container
				   pack => { side => 'top', fill => 'x', pad => 5 }
	);
    $top->insert('Prima::Label',
		 name => 'NW',
		 pack => { side => 'left' },
		 text => 'Hit ~M for Menu',
		 hint => 'Escape to parent',
		 onMouseClick => sub { $self->hitkey(kb::Escape) },
	);
    $top->insert('Prima::Label',
		 name => 'NE',
		 pack => { side => 'right' },
		 text => 'Enter = select / Escape = back',
		 hint => 'Q = Zoom Out',
		 onMouseClick => sub { $self->hitkey(ord 'a') },
	);
    $top->insert('Prima::Label',
		 name => 'N',
		 pack => { side => 'top' },
		 text => 'Use arrow keys to navigate',
		 hint => 'Scroll Up',
		 onMouseClick => sub { $self->hitkey(kb::Up) },
	);
    $self->pack(expand => 1, fill => 'both'); # pack SUPER in the center

    my $bot = $self->owner->insert('Prima::Label', name => 'SOUTH', text => '',
				   transparent => 1, # hack, using label as container
				   pack => { side => 'bottom', fill => 'x', pad => 5 });
    $bot->insert('Prima::Label',
		 name => 'SW',
		 pack => { side => 'left' },
		 text => 'beginning date and time',
		 hint => 'M = Menu',
		 onMouseClick => sub { $self->hitkey(ord 'm') },
	);
    $bot->insert('Prima::Label',
		 name => 'SE',
		 pack => { side => 'right' },
		 text => 'end time or image statistics',
		 hint => 'Z = Zoom In',
		 onMouseClick => sub { $self->hitkey(ord 's') },
	);
    $bot->insert('Prima::Label',
		 name => 'S',
		 pack => { side => 'bottom' },
		 text => 'file location',
		 hint => 'Scroll Down',
		 onMouseClick => sub { $self->hitkey(kb::Down) },
	);

    $self->items($self->children('/'));
    $self->focusedItem(0);
    $self->repaint;
    $self->select;
    $self->keyaliases;
    return %profile;
}

sub on_create {
    my($self) = @_;
    if (my $code = $self->lpdb->conf('thumbviewer')) {
	&{$code}($self);
    }
    if (my $last = $self->bookmark('LAST')) { # restore last location
    	warn "restoring last position $last";
    	$self->goto($last);
    }
    Prima::StartupWindow::unimport;
}

sub icon {		    # my application icon: stack of 3 "images"
    my $size = 160;
    my $ot = $size / 3;		# one third
    my $tt = $size * 2 / 3;	# two thirds
    my $i = Prima::Icon->new(
	width => $size,
	height => $size,
	type   => im::bpp4,
	);
    $i->begin_paint;
    $i->color(cl::Black);
    $i->bar(0, 0, $size, $size);
    $i->color(cl::Blue);
    $i->bar(0, $size, $tt, $ot);
    $i->color(cl::Red);
    $i->bar($ot/2, $tt+$ot/2, $tt+$ot/2, $ot/2);
    $i->color(cl::Green);
    $i->bar($ot, $tt, $size, 0);
    $i->end_paint;
    # $i->save("icon.png");	# prove img/mask are right
    # my($a, $b) = $i->split;
    # $a->save("img.png");
    # $b->save("mask.png");
    # $::application->icon($i);
    return $i;
}

sub hitkey {
    my($self, $key) = @_;
    $self->key_down($key, $key);
}

sub sorter {	    # applies current sort/filter via children of goto
    my($self) = @_;
    $self->goto($self->current);
}

sub children {			# return children of given text path
    my($self, $parent) = @_;
    $parent ||= '/';
    # warn "children of $parent";
    my $m = $self->popup;
    my @sort;		      # menu sort options to database order_by
    if ($m->checked('gname')) {
	push @sort,
	{ ($m->checked('gdsc') ? '-desc' : '-asc') => 'dir.directory' };
    } elsif ($m->checked('gfirst')) {
	push @sort,
	{ ($m->checked('gdsc') ? '-desc' : '-asc') => 'dir.begin' },
	{ '-asc' => 'dir.directory' };
    } elsif ($m->checked('glast')) {
	push @sort,
	{ ($m->checked('gdsc') ? '-desc' : '-asc') => 'dir.end' },
	{ '-asc' => 'dir.directory' };
    }				# else gskip sorts by files only:
    if ($m->checked('inone')) {	# DB order implies none of the above
	@sort = ();
    } elsif ($m->checked('itime')) {
	push @sort,
	{ ($m->checked('idsc') ? '-desc' : '-asc') => 'me.time' };
    } elsif ($m->checked('iname')) {
	push @sort,
	{ ($m->checked('idsc') ? '-desc' : '-asc') => 'me.basename' }
    } elsif ($m->checked('isize')) {
	push @sort,
	{ ($m->checked('idsc') ? '-desc' : '-asc') => 'me.bytes' }
    } elsif ($m->checked('irnd')) {
	push @sort, { '-asc' => 'RANDOM()' }
    }
    my $filter = $self->{filter} = []; # menu filter options to database where

    $m->checked('tags') and push @$filter,
	tag_id => { '!=', undef };
    $m->checked('captions') and push @$filter,
	caption => { '!=', undef };

    $m->checked('portrait') and push @$filter,
	width => { '<', \'height' }; # string ref for literal SQL
    $m->checked('landscape') and push @$filter,
	width => { '>', \'height' }; # string ref for literal SQL

    $m->checked('pictures') and push @$filter,
	duration => { '=', undef };
    $m->checked('videos') and push @$filter,
	duration => { '!=', undef };

    map { $m->checked("year$_") and push @$filter, time =>
	  { '>', time - $_ * 365.25 * 86400 } } qw/1 2 5 10/;
    $m->checked('quarter') and push @$filter,
	time => { '>', time - 90 * 86400 };
    $m->checked('month') and push @$filter,
	time => { '>', time - 31 * 86400 };

    use Data::Dumper;
    local $Data::Dumper::Terse = 1;
    (my $string = Dumper($parent, \@sort, $filter)) =~ s/\n//g;
    $string =~ s/ +//g;

    # my($path, $file, $dur) = $self->vfs->pathpics($parent, \@sort, \@$filter);
    my($path, $file, $dur);	# cache lookups for faster redos
    if ($self->lpdb->conf('noupdate') # but no cache when updating
	&& $self->{cache}{$string}) {
	warn "hit! on $string";
    } else {
	warn "miss! on $string";
	$self->{cache}{$string} =
	    [ $self->vfs->pathpics($parent, \@sort, \@$filter) ];
    }
    ($path, $file, $dur) = (@{$self->{cache}{$string}});

    $self->{duration} = $dur;
    $self->{galleries} = 0;
    $self->{galleries} = $file->[-1][1] if @$file > 0;
    my @path =			# sort paths per menu selection
    	$m->checked('pname')  ? sort { $a->path cmp $b->path } @$path :
	$m->checked('pfirst') ? sort { $a->time(0) <=> $b->time(0) } @$path :
	$m->checked('pmid')   ? sort { $a->time(1) <=> $b->time(1) } @$path :
	$m->checked('plast')  ? sort { $a->time(2) <=> $b->time(2) } @$path :
	$m->checked('prnd')   ? sort { rand(1) <=> rand(1) } @$path : @$path;
    @path = reverse @path if $m->checked('pdsc');
    return [ $m->checked('picsfirst') ? (@$file, @path) : (@path, @$file) ];
}

sub duration {			# total video duration
    return $_[0]->{duration} || 0;
}

sub item {	    # return the path or picture object at given index
    my($self, $index, $gallery) = @_;
    my $this = $self->{items}[$index];
    $this or warn "index $index not found" and return;
    if ('ARRAY' eq ref $this) {	# [ file_id, dir_number ]
	return $gallery ? $this->[1]
	    : $self->vfs->picture($this->[0]);
    }
    elsif ($this->isa('LPDB::Schema::Result::Path')) {
	return $gallery ? -1 : $this;
    }				# else picture lookup, slower:
    return;
}

sub gallery {		      # return the gallery number of the image
    my($self, $idx) = @_;
    $idx >= 0 or return $self->{galleries};
    return $self->item($idx, 1);
}

sub profile {
    my($self, $msg) = @_;
    $self->lpdb->conf('profile') or return;
    $msg or
	$self->{tm} = [gettimeofday] and return;
    my $str =  "\tseconds: " . tv_interval($self->{tm}) . " $msg\n";
    $self->{tm} = [gettimeofday];
    warn $str;
}

sub goto {			# goto path//file or path/path
    my($self, $path) = @_;
    # warn "goto: $path";
    $path =~ m{(.*/)/(.+/?)} or	   # path // pathtofile
	$path =~ m{(.*/)(.+/?)} or # path / basename
	do {
	    if ($path eq '/') {
		my $out = message("Do you really want to exit?",
				  mb::Yes|mb::No, { defButton => mb::No });
		$::application->close if $out & mb::Yes;
#		warn "user said $out";
	    } else {		# shouldn't happen!
		warn "bad path $path";
	    }
	    return;
    };
    my $file;
    ($path, $file) = ($1, $2);
    $self->cwd($path);	       # this says "filter, sort, please wait"
    $self->profile;
    $self->items($self->children($path)); # this blocks on the DB
    $self->profile("in DB");
    $self->focusedItem(-1);
    #$self->repaint;
    $self->focusedItem(0);
    my $n = $self->count;
    unless ($n) {
	$self->owner->NORTH->N
	    ->text('No Results, check ~Menu -> AND Filters or hit Escape!');
	$self->owner->NORTH->NW->text('');
	$self->owner->NORTH->NE->text('');
    }
    unless ($file eq 'FIRST') {
	my $id = $file =~ /^\d+$/ ? $file    # go direct to file_id
	    : $self->vfs->id_of_path($file); # lookup id of image file
	$id ||= 0;
	warn "\tid of $path / $file = $id" if $self->lpdb->conf('debug');
	for (my $i = 0; $i < $n; $i++) { # select myself in parent
	    if ($id) {
		if ($self->{items}[$i][0] == $id) { # quickly find image index
		    $self->focusedItem($i);
		    last;
		}
	    } elsif ($self->item($i)->pathtofile eq $file) { # or matching path
		$self->focusedItem($i);
		last;
	    }
	}
    }
    $self->profile("locating in page");
}

sub current {			# path to current selected item
    my($self) = @_;
    $self->focusedItem < 0 and return $self->cwd || '/';
    my $idx = $self->focusedItem;
    my $this = $self->item($idx);
    $self->cwd . ($this->basename =~ m{/$} ? $this->basename
		  : '/' . $self->{items}[$idx][0]);
}

sub _trimfile { (my $t = $_) =~ s{//.*}{}; $t }

sub on_selectitem { # update metadata labels, later in front of earlier
    my ($self, $idx, $state) = @_;
    $idx = $idx->[0];
    my $x = $idx + 1;
    my $y = $self->count;
    my $p = sprintf '%.0f', $x / $y * 100;
    my $this = $self->item($idx);
    my $id = 0;			# file_id of image only, for related
    my $owner = $self->owner;
    $owner->NORTH->NW->text($self->cwd);
    $owner->NORTH->NW->backColor($self->lpdb->conf('noupdate')
				 ? cl::Back : $self->hiliteBackColor);
    my $progress = "$p%  $x / $y";
    $owner->NORTH->NE->backColor(@{$self->{filter}}
				 ? $self->hiliteBackColor : cl::Back);
    if ($this->isa('LPDB::Schema::Result::Path')) {
	$this->path =~ m{(.*/)(.+/?)};
	$owner->NORTH->N->text($2);
	$owner->NORTH->NE->text(" $progress ");
	$self->{filter} and $this->{filter} = $self->{filter};
	my @p = $this->stack;
	my $span = $p[2] ? $p[2]->time - $p[0]->time : 1;
	my $len =		# timespan of selection
	    $span > 3*365*86400 ? sprintf('%.0f years',  $span /365.25/86400)
	    : $span > 90 *86400 ? sprintf('%.0f months', $span/30.4375/86400)
	    : $span > 48 * 3600 ? sprintf('%.0f days',   $span / 86400)
	    : $span >      3600 ? sprintf('%.0f hours',  $span / 3600)
	    : $span >        60 ? sprintf('%.0f minutes', $span / 60)
	    : '1 minute';
	my $n = $this->picturecount;
	my $p = $n > 1 ? 's' : '';
	$owner->SOUTH->S->text(" $n image$p in $len " .
			       (@{$self->{filter}} ? '(filtered) ' : ''));
	$owner->SOUTH->S->backColor(@{$self->{filter}}
				    ? $self->hiliteBackColor : cl::Back);
	$owner->SOUTH->SE->text($p[2] ? scalar localtime $p[2]->time
				: '  ');
	$owner->SOUTH->SW->text($p[0] ? scalar localtime $p[0]->time
				: 'Check ~Menu -> AND Filters!');
    } elsif ($this->isa('LPDB::Schema::Result::Picture')) {
	my($x, $y) = $self->xofy($idx);
	$owner->NORTH->N->text($this->basename);
	$owner->NORTH->NE->text(sprintf ' %d / %d  %d / %d  %s ', $x, $y,
				$self->gallery($idx), $self->gallery(-1),
				$progress);
	$owner->SOUTH->S->text($this->dir->directory);
	$owner->SOUTH->SE->text(sprintf ' %.2f %dx%d %.1fMP %.0fKB ',
				$this->width / $this->height,
				$this->width , $this->height,
				$this->width * $this->height / 1000000,
				$this->bytes / 1024);
	$owner->SOUTH->SW->text(scalar(localtime $this->time) . ' ');
	$id = $this->file_id;
    }
    my $me = $self->current;
    $self->popup->submenu('navto',
			  [ map { [ $me eq $_ ? "*$_" : $_,
				    _trimfile($_), 'goto' ] }
			    $self->vfs->related($me, $id) ]);
}

sub xofy {	      # find pic position in current gallery directory
    my($self, $me) = @_;
    my $max = $self->count;
    my $this = $self->{items}[$me];
    'ARRAY' eq ref $this or return (0, 0);
    my $dir = $this->[1];
    my $first = $me;
    while ($first > -1
	   and 'ARRAY' eq ref $self->{items}[$first]
	   and $self->{items}[$first][1] == $dir) {
	$first--;
    }
    my $last = $me;
    while ($last < $max
	   and 'ARRAY' eq ref $self->{items}[$last]
	   and $self->{items}[$last][1] == $dir) {
	$last++;
    }
    $last--;
    my $x = $me - $first;
    my $y = $last - $first;
    # warn "$first -> $me -> $last == ($x of $y)";
    return $x, $y;
}

sub galprev {
    my($self) = @_;
    my $idx = $self->focusedItem;
    my($x, $y) = $self->xofy($idx);
    $idx -= $x;			# last image of prev gal
    ($x, $y) = $self->xofy($idx);
    $idx -= ($y - 1);		# first image of prev gal
    $idx < 0 and $idx = 0;
    $self->focusedItem($idx);
}
sub galnext {
    my($self) = @_;
    my($idx, $end) = ($self->focusedItem, $self->count);
    my($x, $y) = $self->xofy($idx);
    $idx += 1 + ($y - $x);	# first image of next gal
    $idx > $end and $idx = $end;
    $self->focusedItem($idx);
}

sub cwd {
    my($self, $cwd) = @_;
    $cwd and $self->{cwd} = $cwd;
    if ($cwd) {
	my $str = '';
	my $tmp = $self->vfs->pathobject($cwd);
	$tmp and $tmp = $tmp->picturecount and $str = " $tmp images";
	$self->owner->NORTH->NW->text("Filtering, sorting, grouping$str...");
	$self->owner->NORTH->N->text('');
	$self->owner->NORTH->NE->text('...PLEASE WAIT!');
	$self->owner->NORTH->repaint;
	$::application->yield;
    }
    return $self->{cwd} || '/';
}

sub on_mouseclick
{
    my($self, $btn, $mod, $x, $y, $dbl) = @_;
    $btn == mb::Middle
	and $self->key_down(0, kb::Escape);
    return if $btn != mb::Left || !$dbl;
    my $item = $self->point2item($x, $y);
    if ($item == $self->focusedItem) {
	$self->key_down(0, kb::Enter);
    } else {
	$self->focusedItem($item);
    }
}

sub on_keydown			# code == -1 for remote navigation
{
    my ($self, $code, $key, $mod) = @_;
    #    warn "keydown  @_";
    my $idx = $self->focusedItem;
    if (($key == kb::Enter || $code == ord 'p') && $idx >= 0) {
	my $this = $self->item($idx);
	# warn $self->focusedItem, " is entered\n";
	if ($this->isa('LPDB::Schema::Result::Path')) {
	    $self->goto($this->path . "FIRST");
	} elsif ($this->isa('LPDB::Schema::Result::Picture')) {
	    # show picture in other window and raise it unless remote
	    $self->viewer($code == -1 ? 1 : 0)->IV->viewimage($this);
	    if ($code == ord 'p') { # play show from here
		$self->viewer->IV->popup->checked('slideshow', 1);
		$self->viewer->IV->slideshow;
	    }
	}
	return;
    } elsif ($key == kb::Escape) { # back up to parent
	$self->goto($self->cwd);
	return;
    }
    if ($code == ord 'm') {	# popup menu
	my @sz = $self->size;
	$self->popup->popup(50, $sz[1] - 50); # near top left
	return;
    }
    $self->SUPER::on_keydown($code, $key, $mod);
}
sub on_drawitem
{
    my $self = shift;
    my $this = $self->item($_[1]) or return;
    if ($this->isa('LPDB::Schema::Result::Path')) {
	$self->draw_path(@_);
    } elsif ($this->isa('LPDB::Schema::Result::Picture')) {
	$self->draw_picture(@_);
    }
}

# replace the center picture of a path stack with random one
sub stackcenter {		# called by {cycler} timer
    my($self) = @_;
    my $canvas = $self->{canvas} or return;
    my $cwd = $self->{cwd};	   # using internals here not methods
    my $first = $self->{topItem};  # could be method
    my $last = $self->{lastItem};  # internal to Lists.pm, no method
    my $key = "$cwd $first $last"; # view change detector
    if ($self->{firstlast} ne $key) { # update the in-view cache
	my @path;		      # paths needing centers
	for (my $i = $first; $i <= $last; $i++) {
	    my $this = $self->item($i);
	    ref $this or next;
	    $this->isa('LPDB::Schema::Result::Picture') and
		$this->duration and push @path, $i and next;
	    $this->isa('LPDB::Schema::Result::Path') or next;
	    $this->picturecount > 2 or next;
	    push @path, $i;
	}
	# warn "paths in view: @path";
	$self->{firstlast} = $key;  # view change detector
	$self->{pathsnow} = \@path; # cache
	$self->{corder} = 0;
    }
    my $n = @{$self->{pathsnow}};
    $n or return;

    my %idx;			# indexes to replace
    if ($self->popup->checked('csel')) {
	my $cur = $self->{focusedItem};
	if ($cur > -1) {
	    my $item = $self->item($cur);
	    $idx{$cur} = 1
		if $item->isa('LPDB::Schema::Result::Path');
	    $idx{$cur} = 1
		if $item->isa('LPDB::Schema::Result::Picture')
		and $item->duration;
	}
    }
    if ($n and $self->popup->checked('corder')) {
	$idx{$self->{pathsnow}[$self->{corder}++]} = 1;
	$self->{corder} = 0
	    if $self->{corder} >= $n;
    } elsif ($n and $self->popup->checked('crandom')) {
	$idx{$self->{pathsnow}[int rand $n]} = 1;
    }				# else cnone
    my @s = $self->size;
    for my $idx (keys %idx) {	# 1 or 2
	my $this = $self->item($idx) or next;
	my $im;
	if ($this->isa('LPDB::Schema::Result::Path')) {
	    my($pic) = $this->random;
	    $pic or next;
	    $im = $self->{thumb}->get($pic->file_id);
	} elsif (my $dur = $this->duration) {
	    $im = $self->{thumb}->put($this->file_id, -1);
	}
	$im or next;
	$self->begin_paint;
	$self->_draw_thumb($im, 2, $canvas,
			   $idx, $self->item2rect($idx, @s),
			   $idx == $self->{focusedItem});
	$self->end_paint;
	$idx == $self->{focusedItem} or next;
	my $me;
	if ($self->{viewer}
	    and Prima::Object::alive($self->{viewer})
	    and $me = $self->{viewer}->IV
	    and $me->focused
	    and my $canvas = $me->{canvas}) {
	    my($W, $H) = $me->size;
	    my($w, $h) = $im->size;
	    $me->begin_paint;
	    $self->_draw_thumb($im, 2, $canvas, 1,
			       $W/2-$w*2, $H/2-$h*2, $W/2+$w*2, $H/2+$h*2);
	    $me->end_paint;
	}
    }
}

# source -> destination, preserving aspect ratio
sub _draw_thumb { # pos 0 = full box, pos 1,2,3 = picture stack in 2/3 box
    my ($self, $im, $pos, $canvas, $idx, $x1, $y1, $x2, $y2, $sel, $foc, $pre, $col) = @_;
    $im or return;
    my $image = $pos < 1; # negative is video stack, 1,2,3 is path stack
    $pos = abs $pos;
    $self->{canvas} ||= $canvas; # for middle image rotator (stackcenter)
    my $back = $self->gallery($idx) || 0;
    my $bk = $sel ? $self->hiliteBackColor
	: $back == -1 ? cl::Blue # picture collection background
	: $back % 2 ? cl::Gray	 # toggle background per gallery
	: cl::Back;
    $bk = $self->prelight_color($bk) if $pre;
    $canvas->backColor($bk);
    $canvas->clear($x1, $y1, $x2, $y2) if $pos < 2; # 2 and 3 should stack
    $canvas->color($sel ? $self->hiliteColor : cl::Fore);

    my $dw = $x2 - $x1;
    my $b = $sel || $foc || $pre ? 0 : $dw / 30; # border
    $dw *= 2/3 if $pos;		# 2/3 size for picture stack
    my $dh = $y2 - $y1;
    $dh *= 2/3 if $pos;
    $dw -= $b * 2;
    $dh -= $b * 2;
    my($sw, $sh) = ($im->width, $im->height);
    my @out;
    my $src = $sw / $sh;	# aspect ratios
    my $dst = $dw / $dh;
    my $sx = my $sy = my $dx = my $dy = 0;
    # this copy is used for rectangle overlay in crop mode
    my($DX, $DY, $DW, $DH) = ($dx, $dy, $dw, $dh);
    if ($src > $dst) {		# image wider than cell: pad top/bot
	$DY = ($DH - $DW / $src) / 2;
	$DH = $DW / $src;
    } else {		      # image taller than cell: pad left/right
	$DX = ($DW - $DH * $src) / 2;
	$DW = $DH * $src;
    }
    if (!$image and $self->popup->checked('croppaths') or
	$image and $self->popup->checked('cropimages')) {
	if ($src > $dst) {    # image wider than cell: crop left/right
	    $sx = ($sw - $sh * $dst) / 2;
	    $sw = $sh * $dst;
	} else {		# image taller than cell: crop top/bot
	    $sy = ($sh - $sw / $dst) / 2;
	    $sh = $sw / $dst;
	}
    } else {			# pad source to destination
	($dx, $dy, $dw, $dh) = ($DX, $DY, $DW, $DH);
    }
    my ($x, $y) = (
	$pos   == 0 ? ($x1 + $b + $dx, $y1 + $b + $dy) # full picture
	: $pos == 1 ? ($x1 + $b, $y2 - $b - $dh) # North West
	: $pos == 2 ? (($x1 + $x2)/2 - $dw/2, ($y1 + $y2)/2 - $dh/2) # center
	: $pos == 3 ? ($x2 - $b - $dw, $y1 + $b) # South East
	: ($x1, $y1));		# should never happen
    $canvas->put_image_indirect($im, $x, $y, $sx, $sy, $dw, $dh, $sw, $sh,
				$self->rop)
	or warn "put_image failed: $@";
    if (!$pos and !$b) {       # overlay rectangle on focused pictures
	$canvas->lineWidth(3);
        my ($x, $y, $w, $h);
        if ($self->popup->checked('cropimages')) { # show aspect rectangle
	    $canvas->color(cl::LightRed); # cropped portion
	    $canvas->rectangle($x1 + $DX, $y1 + $DY,
			       $x1 + $DX + $DW, $y1 + $DY + $DH);
	    $canvas->color(cl::Fore);
        }
        # TODO: fix this!!! It is right only for square thumbs:
        ($x, $w) = $DY ? ($DY, $DH) : ($DX, $DW);
        ($y, $h) = $DX ? ($DX, $DW) : ($DY, $DH);
        $canvas->rectangle($x1 + $x, $y1 + $y,
			   $x1 + $x + $w, $y1 + $y + $h);
    }
    return $b;
}

sub draw_path {
    my ($self, $canvas, $idx, $x1, $y1, $x2, $y2, $sel, $foc, $pre, $col) = @_;
    my ($thumb, $im);
    my $path = $self->item($idx);
    my $b = 0;			# border size
    my @where = (1, 2, 3);
    my($first, $last);
    $self->{filter} and $path->{filter} = $self->{filter};
    $canvas->color(cl::Back);
    $canvas->bar($x1, $y1, $x2, $y2); # clear the tile
    $canvas->color(cl::Fore);
    for my $pic ($path->stack) {
	my $where = shift @where;
	$pic or next;
	my $im = $self->{thumb}->get($pic->file_id);
	$im or next;
	$first or $first = $pic;
	$last = $pic;
	$b = $self->_draw_thumb($im, $where, $canvas, $idx, $x1, $y1,
				$x2, $y2, $sel, $foc, $pre, $col);
    }
    $canvas->textOpaque(!$b);
    $b += 5;			# now text border
    my $n = $path->picturecount;
    my $str = $path->path;
    $str =~ m{(.*/)(.+/?)};
    $canvas->draw_text("$2\n$n", $x1 + $b, $y1 + $b, $x2 - $b, $y2 - $b,
		       dt::Right|dt::Top|dt::Default);
    $str = $first ? strftime("%b %d %Y", localtime $first->time) : 'FILTERED OUT!';
    my $end = $last ? strftime("%b %d %Y", localtime $last->time) : '';
    $str eq $end or $str .= "\n$end";
    $canvas->draw_text($str, $x1 + $b, $y1 + $b, $x2 - $b, $y2 - $b,
		       dt::Left|dt::Bottom|dt::Default);
    $canvas->rect_focus( $x1, $y1, $x2, $y2 ) if $foc;
}

sub draw_picture {
    my ($self, $canvas, $idx, $x1, $y1, $x2, $y2, $sel, $foc, $pre, $col) = @_;
    my $pic = $self->item($idx) or return;
    my $dur = $pic->hms;
    my $b;			# video stack at 5%, 50%, 95% of time:
    if ($dur and $self->popup->checked('videostack')) {
	for my $pos (1, 3, 0) {	# pos 2 is stored at cid 0, don't duplicate it
	    my $im = $self->{thumb}->get($pic->file_id, $pos);
	    $im or return;
	    $b = $self->_draw_thumb($im, -1 * ($pos || 2), $canvas, $idx,$x1,
				    $y1, $x2, $y2, $sel, $foc, $pre, $col);
	}
    } else {			# one picture
	my $im = $self->{thumb}->get($pic->file_id);
	$im or return;
	$b = $self->_draw_thumb($im, 0, $canvas, $idx, $x1, $y1, $x2, $y2,
				$sel, $foc, $pre, $col);
    }

    $b += 10;			# now text border
    my @border = ($x1 + $b, $y1 + $b, $x2 - $b, $y2 - $b);
    $canvas->textOpaque(1);
    if ($self->popup->checked('cropimages')) { # wide / portrait flags
	my $str = $pic->width > 1.8 * $pic->height ? '==='
	    : $pic->width < $pic->height ? '||' : '';
	$str and
	    $canvas->draw_text($str, @border,
			       dt::Right|dt::Top|dt::Default);
    }
    if ($dur) {
	$canvas->draw_text(">> $dur >>",  @border,
			   dt::Center|dt::Top|dt::Default);
    }
    if ($sel and !$pic->caption) { # help see selection by showing text
    	my $str = strftime('  %b %d %Y  ', localtime $pic->time);
    	$canvas->draw_text($str, @border,
    			   dt::Center|dt::Bottom|dt::Default);
    }

    $canvas->textOpaque($b == 10); # highlight caption of selection
    $pic->caption and
	$canvas->draw_text($pic->caption, $x1 + $b, $y1 + $b, $x2 - $b, $y2 - $b,
			   dt::Center|dt::Bottom|dt::Default); # dt::VCenter
    $canvas->rect_focus( $x1, $y1, $x2, $y2 ) if $foc;
}

sub bookmark {			# key / value store for GUI bookmarks
    my($self, $name, $value) = @_;
    defined $name or return;
    my $schema = $self->{lpdb}->{tschema};
    my $row;
    if (defined $value) {
	$row = $schema->resultset('BookMark')->find_or_create(
	    { name => $name });
	$row->value($value);
	$row->update;
	$schema->txn_commit;
	$schema->txn_begin;
    }
    $row or $row = $schema->resultset('BookMark')->find(
	{ name => $name });
#    warn "$name $value $row";
    return $row ? $row->value : undef;
}

sub on_close {
    my($self) = @_;
    $self or return;
    my $last = $self->current;
#    warn "$$ saving $last";
    $self->bookmark('LAST', $last);
#    warn "trying to refocus";
    $self->owner->select; # restore focus to original window, else no focus!
    $self->owner->focus;
}

# sub on_destroy {
#     warn "$$ ENDING";
#     &on_close;
# }

# TODO, move this to ImageViewer or ImageWindow or somewhere?

sub viewer {		 # reuse existing image viewer, or recreate it
    my($self, $noraise) = @_;
#    warn "viewer: $self, $noraise";
    my $iv;
    if ($self and $self->{viewer} and
	Prima::Object::alive($self->{viewer})) {
	$self->{viewer}->restore
	    if $self->{viewer}->windowState == ws::Minimized;
    } else {
	my $w = $self->{viewer} = Prima::LPDB::Fullscreen->create(
	    text => 'Image Viewer',
	    size => [1600, 900],
	    );
	$w->insert(
	    'Prima::LPDB::ImageViewer',
	    name => 'IV',
	    thumbviewer => $self,
	    pack => { expand => 1, fill => 'both' },
	    # growMode => gm::Client,
	    );
	$w->repaint;
	my $conf = $main::conf || {}; # set by main program
	if ($conf->{imageviewer}) {   # optional startup configuration
	    &{$conf->{imageviewer}}($self->{viewer}->IV);
	}
    }
    # $self->{viewer}->select;
    $noraise or $self->{viewer}->bring_to_front;
    $self->{viewer}->repaint;
    $self->{viewer};
}

1;

=pod

=head1 SEE ALSO

L<lpgallery>, L<Prima::LPDB::TileViewer>, L<Prima::LPDB::ImageViewer>,
L<LPDB>


=head1 AUTHOR

Timothy D Witham <twitham@sbcglobal.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2013-2024 Timothy D Witham.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
