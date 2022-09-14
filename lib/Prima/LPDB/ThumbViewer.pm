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
use LPDB::Tree;
use LPDB::Thumbnail;
use Prima::LPDB::TileViewer;	# could someday promote to Prima?
use Prima::FrameSet;
use Prima::Label;
use Prima::MsgBox;
use POSIX qw/strftime/;
use Prima::LPDB::ImageViewer;
use Prima::LPDB::Fullscreen;	# could someday promote to Prima?
use Prima::LPDB::PointerHider;	# could someday promote to Prima?

use vars qw(@ISA);
@ISA = qw(Prima::LPDB::TileViewer Prima::LPDB::Fullscreen);

my $lv;
sub profile_default
{
    my $def = $_[ 0]-> SUPER::profile_default;
    my %prf = (
	popupItems => [
	    ['navto' => '~Navigate To' => [
		 # replaced by on_selectitem
		 ['/[Folders]/' => '/[Folders]/' => 'goto'],
	     ]],
	    ['~AND Filters' => [
		 ['@tags'	=> '~Tags'	=> 'sorter'],
		 ['@captions'	=> '~Captions'	=> 'sorter'],
		 [],
		 ['*(both'	=> '~Both Shapes:' => 'sorter'],
		 ['portrait'	=> '~Portrait'	=> 'sorter'],
		 [')landscape'	=> '~Landscape'	=> 'sorter'],
		 [],
		 ['*(unlimited'	=> '~Unlimited or latest:' => 'sorter'],
		 ['year10'	=> '1~0 Years'	=> 'sorter'],
		 ['year5'	=> '~5 Years'	=> 'sorter'],
		 ['year2'	=> '~2 Years'	=> 'sorter'],
		 ['year1'	=> '1 ~Year'	=> 'sorter'],
		 ['quarter'	=> '1 ~Quarter'	=> 'sorter'],
		 [')month'	=> '1 ~Month'	=> 'sorter'],
	     ]],
	    ['~Sort' => [
		 ['~Paths' => [
		      ['*(pname'=> '~Name (default)'	=> 'sorter'],
		      ['pfirst'	=> '~Begin Time'	=> 'sorter'],
		      ['pmid'	=> '~Middle Time'	=> 'sorter'],
		      ['plast'	=> '~End Time'		=> 'sorter'],
		      [')prnd'	=> '~Random'		=> 'sorter'],
		      [],
		      ['*(pasc'	=> '~Ascending (default)' => 'sorter'],
		      [')pdsc'	=> '~Descending'	=> 'sorter'],
		  ]],
		 ['~Gallery Groups' => [
		      ['(gname'	=> '~Name'			=> 'sorter'],
		      ['*gfirst' => '~Begin Time (default)'	=> 'sorter'],
		      ['glast'	=> '~End Time'			=> 'sorter'],
#['grnd'	=> '~Random'	=> 'sorter'], # !!! currently doesn't work, as it breaks the groups, same as skip:
		      [')gskip'	=> '~Ungrouped'			=> 'sorter'],
		      [],
		      ['*(gasc'	=> '~Ascending (default)'	=> 'sorter'],
		      [')gdsc'	=> '~Descending'		=> 'sorter'],
		  ]],
		 ['~Images' => [
		      ['(inone'	=> '~Fast (database order)'	=> 'sorter'],
		      ['iname'	=> '~Name'			=> 'sorter'],
		      ['*itime'	=> '~Time (default)'		=> 'sorter'],
		      ['isize'	=> '~Size'			=> 'sorter'],
		      [')irnd'	=> '~Random'			=> 'sorter'],
		      [],
		      ['*(iasc'	=> '~Ascending (default)'	=> 'sorter'],
		      [')idsc'	=> '~Descending'		=> 'sorter'],
		  ]],
		 ['~Mixed Folders' => [
		      ['*(galsfirst'	=> '~Galleries First (default)'	=> 'sorter'],
		      [')picsfirst'	=> '~Images First'	=> 'sorter'],
		  ]],

	     ]],
	    [],
	    ['~Random Stack Centers' => [
		 ['*@csel'	=> '~Selection (default)'	=> sub {}],
		 [],
		 ['(cnone'	=> '~No Others'			=> sub {}],
		 ['*corder'	=> 'In ~Order (default)'	=> sub {}],
		 [')crandom'	=> '~Random'			=> sub {}],
		 [],
		 ['(c250' => '~4 per second'   => sub { $_[0]->{cycler}->timeout(250)}],
		 ['c333'  => '~3 per second'   => sub { $_[0]->{cycler}->timeout(333)}],
		 ['*c500' => '~2 per second (default)' => sub { $_[0]->{cycler}->timeout(500)}],
		 ['c1000' => '~1 per second'   => sub { $_[0]->{cycler}->timeout(1000)}],
		 ['c2000' => '1 per 2 seconds' => sub { $_[0]->{cycler}->timeout(2000)}],
		 ['c3000' => '1 per 3 seconds' => sub { $_[0]->{cycler}->timeout(3000)}],
		 [')c4000'=> '1 per 4 seconds' => sub { $_[0]->{cycler}->timeout(4000)}],
		 ]],
	    [],
	    ['fullscreen', '~Full Screen', 'f', ord 'f' =>
	     sub { $_[0]->fullscreen($_[0]->popup->toggle($_[1]) )}],
	    ['bigger', 'Zoom ~In', 'z', ord 'z' =>
	     sub { $_[0]->bigger }],
	    ['smaller', 'Zoom ~Out', 'q', ord 'q' =>
	     sub { $_[0]->smaller }],
	    [],
	    ['*@croppaths', 'Crop ~Paths', 'Ctrl+Shift+T',
	     km::Ctrl | km::Shift | ord('t') => sub { $_[0]->repaint }],
	    ['@cropimages', '~Crop Images', 'Ctrl+E',
	     km::Ctrl | ord('e') => sub { $_[0]->repaint }],
	    [],
	    ['help', '~Help', 'h', ord('h') => sub {
		$::application->open_help("file://$0") }],
	    ['quit', '~Quit', 'Ctrl+Q', '^q' => sub { $::application->close }],
	    # ['quit', '~Quit', 'Ctrl+Q', '^q' => \&myclose ],
	]);
    @$def{keys %prf} = values %prf;
    return $def;
}
sub lpdb { $_[0]->{lpdb} }
sub tree { $_[0]->{tree} }
sub thumb { $_[0]->{thumb} }
sub init {
    my $self = shift;
    my(%hash) = @_;
    my %profile = $self->SUPER::init(@_);

    $self->{lpdb} = $hash{lpdb} or die "lpdb object required";
    $self->{tree} = new LPDB::Tree($self->{lpdb});
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
    $self->insert('Prima::LPDB::Fullscreen', window => $self->owner);

    $self->packForget; # to get packs around the perimeter of the SUPER widget

    my $top = $self->owner->insert('Prima::Label', name => 'NORTH', text => '',
				   transparent => 1, # hack, using label as container
				   pack => { side => 'top', fill => 'x', pad => 5 });
    $top->insert('Prima::Label', name => 'NW', pack => { side => 'left' },
		 text => 'Hit ~M for Menu');
    $top->insert('Prima::Label', name => 'NE', pack => { side => 'right' },
		 text => 'Enter = select / Escape = back');
    $top->insert('Prima::Label', name => 'N', pack => { side => 'top' },
		 text => $self->{notice} = 'Use arrow keys to navigate');

    $self->pack(expand => 1, fill => 'both');

    my $bot = $self->owner->insert('Prima::Label', name => 'SOUTH', text => '',
				   transparent => 1, # hack, using label as container
				   pack => { side => 'bottom', fill => 'x', pad => 5 });
    $bot->insert('Prima::Label', name => 'SW', pack => { side => 'left' },
		 text => 'beginning date and time');
    $bot->insert('Prima::Label', name => 'SE', pack => { side => 'right' },
		 text => 'end time or image statistics');
    $bot->insert('Prima::Label', name => 'S', pack => { side => 'bottom' },
		 text => 'summary');

    $self->items($self->children('/'));
    $self->focusedItem(0);
    $self->repaint;
    # $self->selected(1);
    # $self->focused(1);
    $self->select;
    return %profile;
}

sub sorter {	    # applies current sort/filter via children of goto
    my($self) = @_;
    $self->goto($self->current);
}

sub children {			# return children of given text path
    my($self, $parent) = @_;
    $self->owner->NORTH->N->text($self->{notice});
    $self->{notice} = '   filtering and sorting, PLEASE WAIT...   ';
    $self->repaint;
    $::application->yield;
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

    map { $m->checked("year$_") and push @$filter, time =>
	  { '>', time - $_ * 365.25 * 86400 } } qw/1 2 5 10/;
    $m->checked('quarter') and push @$filter,
	time => { '>', time - 90 * 86400 };
    $m->checked('month') and push @$filter,
	time => { '>', time - 31 * 86400 };

    my($path, $file) = $self->{tree}->pathpics($parent || '/', \@sort, \@$filter);
    my @path =			# sort paths per menu selection
    	$m->checked('pname')  ? sort { $a->path cmp $b->path } @$path :
	$m->checked('pfirst') ? sort { $a->time(0) <=> $b->time(0) } @$path :
	$m->checked('pmid')   ? sort { $a->time(1) <=> $b->time(1) } @$path :
	$m->checked('plast')  ? sort { $a->time(2) <=> $b->time(2) } @$path :
	$m->checked('prnd')   ? sort { rand(1) <=> rand(1) } @$path : @$path;
    @path = reverse @path if $m->checked('pdsc');
    return [ $m->checked('picsfirst') ? (@$file, @path) : (@path, @$file) ];
}

sub item {	    # return the path or picture object at given index
    my($self, $index) = @_;
    my $this = $self->{items}[$index];
    $this or warn "index $index not found" and return;
    if ($this->isa('LPDB::Schema::Result::Path')) {
	return $this;
    }				# else picture lookup:
    $self->{tree}->picture($this);
}

sub goto {  # for robot navigation (slideshow) also used by escape key
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
    $self->cwd($1);
    $self->items($self->children($1));
    $self->focusedItem(-1);
    # $self->repaint;
    $self->focusedItem(0);
    my $n = $self->count;
    for (my $i = 0; $i < $n; $i++) { # select myself in parent
	if ($self->item($i)->pathtofile eq $2) {
	    $self->focusedItem($i);
	    last;
	}
    }
    # $self->repaint;
}

sub current {			# path to current selected item
    my($self) = @_;
    $self->focusedItem < 0 and return $self->cwd || '/';
    my $this = $self->item($self->focusedItem);
    $self->cwd . ($this->basename =~ m{/$} ? $this->basename
		  : '/' . $this->pathtofile);
}

sub _trimfile { (my $t = $_) =~ s{//.*}{}; $t }

sub on_selectitem { # update metadata labels, later in front of earlier
    my ($self, $idx, $state) = @_;
    my $x = $idx->[0] + 1;
    my $y = $self->count;
    my $p = sprintf '%.0f', $x / $y * 100;
    my $this = $self->item($idx->[0]);
    my $id = 0;			# file_id of image only, for related
    my $owner = $self->owner;
    $owner->NORTH->NW->text($self->cwd);
    my $progress = "$p% $x / $y";
    @{$self->{filter}} and $progress = "[ $progress ]";
    $owner->NORTH->NE->text($progress);
    if ($this->isa('LPDB::Schema::Result::Path')) {
	$this->path =~ m{(.*/)(.+/?)};
	$owner->NORTH->N->text($2);
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
	$owner->SOUTH->S->text("$n image$p in $len" .
			       (@{$self->{filter}} ? ' (filtered)' : ''));
	$owner->SOUTH->SE->text($p[2] ? scalar localtime $p[2]->time
				: '  ');
	$owner->SOUTH->SW->text($p[0] ? scalar localtime $p[0]->time
				: 'Check ~Menu -> AND Filters!');
    } elsif ($this->isa('LPDB::Schema::Result::Picture')) {
	my($x, $y) = $self->xofy($idx->[0]);
	$owner->NORTH->N->text($this->basename);
	$owner->SOUTH->S->text($this->dir->directory . " $x / $y");
	$owner->SOUTH->SE->text(sprintf '%dx%d=%.2f  %.1fMP %.0fKB',
				$this->width , $this->height,
				$this->width / $this->height,
				$this->width * $this->height / 1000000,
				$this->bytes / 1024);
	$owner->SOUTH->SW->text(scalar localtime $this->time);
	$id = $this->file_id;
    }
    my $me = $self->current;
    $self->popup->submenu('navto',
			  [ map { [ $me eq $_ ? "*$_" : $_,
				    _trimfile($_), 'goto' ] }
			    $self->{tree}->related($me, $id) ]);
}

sub xofy {	      # find pic position in current gallery directory
    my($self, $me) = @_;
    my $max = $self->count;
    # my $this = $all->[$me];
    my $this = $self->item($me);
    $this or return (0, 0);
    my $dir = $this->dir->directory;
    my $first = $me;
    while ($first > -1
	   and $self->item($first)->isa('LPDB::Schema::Result::Picture')
	   and $self->item($first)->dir->directory eq $dir) {
	$first--;
    }
    my $last = $me;
    while ($last < $max
	   and $self->item($last)->isa('LPDB::Schema::Result::Picture')
	   and $self->item($last)->dir->directory eq $dir) {
	$last++;
    }
    $last--;
    my $x = $me - $first;
    my $y = $last - $first;
    # warn "$first -> $me -> $last == ($x of $y)";
    return $x, $y;
}

sub cwd {
    my($self, $cwd) = @_;
    $cwd and $self->{cwd} = $cwd;
    if ($cwd) {			# hack: assume no images
	$self->owner->NORTH->N->text('0 images, check filters!');
	$self->owner->NORTH->NE->text('0 / 0');
    }
    return $self->{cwd} || '/';
}

sub on_mouseclick
{
    my($self, $btn, $mod, $x, $y, $dbl) = @_;
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
    if ($key == kb::Enter && $idx >= 0) {
	my $this = $self->item($idx);
	# warn $self->focusedItem, " is entered\n";
	if ($this->isa('LPDB::Schema::Result::Path')) {
	    $self->cwd($this->path);
	    $self->items($self->children($this->path));
	    $self->focusedItem(-1);
	    $self->repaint;
	    $self->focusedItem(0);
	    $self->repaint;
	} elsif ($this->isa('LPDB::Schema::Result::Picture')) {
	    # show picture in other window and raise it unless remote
	    $self->viewer($code == -1 ? 1 : 0)->IV->viewimage($this);
	}
	$self->clear_event;
	return;
    } elsif ($key == kb::Escape) {
	$self->goto($self->cwd);
	$self->clear_event;
	return;
    }
    if ($code == ord 'm' or $code == ord '?' or $code == 13) { # popup menu
	my @sz = $self->size;
	$self->popup->popup(50, $sz[1] - 50); # near top left
	return;
    }
    if ($code == 5) {		# ctrl-e = crops, in menu
	$self->key_down(ord 'c');
	return;
    }
    $self->SUPER::on_keydown( $code, $key, $mod);
}
sub on_drawitem
{
    my $self = shift;
    my $this = $self->item($_[1]);
    if ($this->isa('LPDB::Schema::Result::Path')) {
	$self->draw_path(@_);
    } elsif ($this->isa('LPDB::Schema::Result::Picture')) {
	$self->draw_picture(@_);
    }
}

# replace the center picture of a path stack with random one
sub stackcenter {		# called by {cycler} timer
    my($self) = @_;
    my $cwd = $self->{cwd};	   # using internals here not methods
    my $first = $self->{topItem};  # could be method
    my $last = $self->{lastItem};  # internal to Lists.pm, no method
    my $key = "$cwd $first $last"; # view change detector
    if ($self->{firstlast} ne $key) { # update the view cache
	my @path;
	for (my $i = $first; $i <= $last; $i++) {
	    my $this = $self->{items}[$i];
	    ref $this or next;	# only paths are refs, pics are ints
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
	$idx{$cur} = 1 if $cur > -1
	    and $self->{items}[$cur]->isa('LPDB::Schema::Result::Path');
    }
    if ($self->popup->checked('corder')) {
	$idx{$self->{pathsnow}[$self->{corder}++]} = 1;
	$self->{corder} = 0
	    if $self->{corder} >= $n;
    } elsif ($self->popup->checked('crandom')) {
	$idx{$self->{pathsnow}[int rand $n]} = 1;
    }				# else cnone
    my @s = $self->size;
    for my $idx (keys %idx) {	# 1 or 2
	my $this = $self->{items}[$idx] or next;
	ref $this or next;
	my($pic) = $this->random;
	my $id = $pic->file_id;
	my $im = $self->{thumb}->get($pic->file_id);
	$im or return;
	$self->begin_paint;
	$self->_draw_thumb($im, 2, $self->{canvas},
			   $idx, $self->item2rect($idx, @s),
			   $idx == $self->{focusedItem});
	$self->end_paint;
    }
}

# source -> destination, preserving aspect ratio
sub _draw_thumb {		# pos 0 = full size, pos 1,2,3 = picture stack
    my ($self, $im, $pos, $canvas, $idx, $x1, $y1, $x2, $y2, $sel, $foc, $pre, $col) = @_;

    $self->{canvas} ||= $canvas; # for middle image rotator
    my $bk = $sel ? $self->hiliteBackColor : cl::Back;
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
    if ($pos and $self->popup->checked('croppaths') or
	!$pos and $self->popup->checked('cropimages')) {
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
	$b = $self->_draw_thumb($im, $where, $canvas, $idx, $x1, $y1, $x2, $y2, $sel, $foc, $pre, $col);
    }

    # # TODO: center/top picture is favorite from DB, if any, or cycling random!
    # $self->_draw_thumb($im, 3, $canvas, $idx, $x1, $y1, $x2, $y2, $sel, $foc, $pre, $col);

    $canvas->textOpaque(!$b);
    $b += 5;			# now text border
    my $n = $path->picturecount;
    my $str = $path->path;
    $str =~ m{(.*/)(.+/?)};
    $canvas->draw_text("$2\n$n", $x1 + $b, $y1 + $b, $x2 - $b, $y2 - $b,
		       dt::Right|dt::Top|dt::Default);

    # $canvas->draw_text($n, $x1 + $b, $y1 + $b, $x2 - $b, $y2 - $b,
    # 		       dt::Center|dt::VCenter|dt::Default);
    
    $str = $first ? strftime("%b %d %Y", localtime $first->time) : 'FILTERED OUT!';
    my $end = $last ? strftime("%b %d %Y", localtime $last->time) : '';
    $str eq $end or $str .= "\n$end";
    $canvas->draw_text($str, $x1 + $b, $y1 + $b, $x2 - $b, $y2 - $b,
		       dt::Left|dt::Bottom|dt::Default);
    $canvas->rect_focus( $x1, $y1, $x2, $y2 ) if $foc;
}

sub draw_picture {
    my ($self, $canvas, $idx, $x1, $y1, $x2, $y2, $sel, $foc, $pre, $col) = @_;

    my $pic = $self->item($idx);
    my $im = $self->{thumb}->get($pic->file_id);
    $im or return "warn: can't get thumb!\n";
    my $b = $self->_draw_thumb($im, 0, $canvas, $idx, $x1, $y1, $x2, $y2, $sel, $foc, $pre, $col);

    $b += 10;			# now text border
    $canvas->textOpaque(1);
    my $str = $pic->width > 1.8 * $pic->height ? '===' # wide / portrait flags
	: $pic->width < $pic->height ? '||' : '';
    $str and
	$canvas->draw_text($str, $x1 + $b, $y1 + $b, $x2 - $b, $y2 - $b,
			   dt::Right|dt::Top|dt::Default);

    $canvas->textOpaque($b == 10); # highlight caption of selection
    $pic->caption and
	$canvas->draw_text($pic->caption, $x1 + $b, $y1 + $b, $x2 - $b, $y2 - $b,
			   dt::Center|dt::Bottom|dt::Default); # dt::VCenter
    $canvas->rect_focus( $x1, $y1, $x2, $y2 ) if $foc;
}

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
	my $w = $self->{viewer} = Prima::Window->create(
	    text => 'Image Viewer',
	    #	    size => [$::application->size],
	    # packPropagate => 0,
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

=back

=head1 SEE ALSO
L<Prima::TileViewer>, L<Prima::ImageViewer>, L<LPDB>, L<lpgallery>

=head1 AUTHOR

Timothy D Witham <twitham@sbcglobal.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2013-2022 Timothy D Witham.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
