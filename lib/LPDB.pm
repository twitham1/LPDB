=head1 NAME

LPDB - Local Picture metadata in sqlite

=head1 SYNOPSIS

  use LPDB;
  my $lpdb = new LPDB( { } );	# key = value configuration hash
  $lpdb->create;		# or update schema
  $lpdb->update('.');		# update database from files and metadata
  $lpdb->disconnect;		# all done

=head1 DESCRIPTION

B<LPDB> stores local picture metadata in a local sqlite database whose
tables are described below.  Its primary application is L<lpgallery>,
a keyboard driven picture browser.  This module provides access to the
database object while deferring storage and retrieval to
L<LPDB::Filesystem>.

=cut

package LPDB;

use strict;
use warnings;
use Carp;
use DBI;
use POSIX qw/strftime/;
use LPDB::Schema;		# from dbicdump dbicdump.conf
use LPDB::Filesystem;
use Time::HiRes qw(gettimeofday tv_interval); # for profiling
use Data::Dumper;

my $conf = {		       # override any keys in first arg to new
    reject	=> '\.import', # pattern of files/dirs to reject
    keep	=> '(?i)\.(jpe?g|png|mp4|mov)$',
    update	=> sub {},  # callback after each directory is scanned
    debug	=> 0,	    # diagnostics to STDERR
    filter	=> {},	    # filters
    sqltrace	=> 0,	    # SQL to STDERR from DBIx::Class::Storage
    editpath	=> 0,	# optional sub to return modified virtual path
    # dbfile	=> '.lpdb.db',
    # thumbfile	=> '.lpdb-thumb.db',
};

sub new {
    my($class, $hash) = @_;
    my $self = {
	index => 0, # dir => { qw(dir / file /) },
    };
    if (ref $hash) {		# switch to user's conf + my defaults
	while (my($k, $v) = each %$conf) {
	    $hash->{$k} = $v unless $hash->{$k};
	}
	$conf = $hash;
    }
    $ENV{DBIC_TRACE} = $conf->{sqltrace} || 0;

    $self->{conf} = $conf;
    $conf->{dbfile} or
	carp "{dbfile} required" and return undef;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$conf->{dbfile}",  "", "",
			   { RaiseError => 1, AutoCommit => 1,
			     # DBIx::Class::Storage::DBI::SQLite(3pm):
			     on_connect_call => 'use_foreign_keys',
			     sqlite_unicode => 1,
			   })
	or die $DBI::errstr;
    # Default is no enforcement, and must be set per connection:
    $dbh->do('PRAGMA foreign_keys = ON;');
    # WAL lets writers not block readers and is faster at writing:
    $dbh->do('PRAGMA journal_mode = WAL;'); # or DELETE or TRUNCATE
    $self->{dbh} = $dbh;

    $conf->{thumbfile} or
    	carp "{thumbfile} required" and return undef;
    my $tdbh = DBI->connect("dbi:SQLite:dbname=$conf->{thumbfile}",  "", "",
    			    { RaiseError => 1, AutoCommit => 1,
    			      # DBIx::Class::Storage::DBI::SQLite(3pm):
    			      on_connect_call => 'use_foreign_keys',
    			    })
    	or die $DBI::errstr;
    # WAL lets writers not block readers and is faster at writing:
    $tdbh->do('PRAGMA journal_mode = WAL;'); # or DELETE or TRUNCATE
    $self->{tdbh} = $tdbh;

    $self->{mtime} = 0;	# modify time of dbfile, for detecting updates
    $self->{sofar} = 0;	# hack!!! for picasagallery, fix this...
    bless $self, $class;
    return $self;
}

sub conf {	     # return whole config, or key, or set key's value
    my($self, $key, $value) = @_;
    if (defined $value) {
	$key eq 'sqltrace'
	    and $ENV{DBIC_TRACE} = $value;
	return $self->{conf}{$key} = $value;
    } elsif ($key) {
	return $self->{conf}{$key} || undef;
    }
    return $self->{conf};	# whole configuration hash
}

sub dbh { return $_[0]->{dbh}; }
sub tdbh { return $_[0]->{tdbh}; }

sub disconnect {
    my $self = shift;
    # my $dbh = $self->dbh;
    # print all currently cached prepared statements
#    print "cache>>>$_<<<\n" for keys %{$dbh->{CachedKids}};
    $self->dbh->do('PRAGMA optimize;');
    $self->dbh->disconnect;
    $self->tdbh->do('PRAGMA optimize;');
    $self->tdbh->disconnect;
}

sub schema {
    my $self = shift;
    $self->{schema} or $self->{schema} = LPDB::Schema->connect(
	sub { $self->dbh });
    return $self->{schema};
}
sub tschema {
    my $self = shift;
    $self->{tschema} or $self->{tschema} = LPDB::Schema->connect(
	sub { $self->tdbh });
    return $self->{tschema};
}

sub namevalue {			# key / value store
    my($self, $name, $value) = @_;
    defined $name or return;
    my $schema = $self->schema;
    my $row;
    if (defined $value) {
	$row = $schema->resultset('NameValue')->find_or_create(
	    { name => $name });
	$row->value($value);
	$row->update;
    }
    $row or $row = $schema->resultset('NameValue')->find(
	{ name => $name });
    return $row ? $row->value : undef;
}

# ------------------------------------------------------------
# Everything below here might be used by legacy picasagallery but is
# likely never used by current lpgallery.  Not well tested.  Should be
# offloaded to a separate file. -twitham
# ------------------------------------------------------------

# stats of given result set moves values from DB to perl object
sub plstats {
    my $self = shift;
    my $rs = shift;
    my $path = shift;
    my $t0 = [gettimeofday];
    my @cols = qw/bytes pixels width height time modified/;
    my $data = {};
    my $n = $rs->count;
    $n or return {};
    my $half = int($n / 2);
    my %dir;
    while (my $row = $rs->next) { # gather all info in 1 quick loop
	my %this = $row->get_columns;
#	print Dumper \%this;
	$data->{files}++;	# DB already ordered by file_id
	$dir{$this{dir_id}}++
	    or $data->{dirs}++;
	for my $num (@cols) {	# sums
	    $data->{$num} += $this{$num};
	}
	$data->{last} = $this{filename}; # ends of time
	$data->{endtime} = $this{time};
	$data->{lastid} = $this{file_id};

	$this{tag} and $data->{tags}++; # flags
	$this{caption} and $data->{caption}++;

	$data->{physical} and next; # shortcut second half
	$data->{files} >= $half and
	    $data->{physical} = $this{filename} and
	    $data->{middleid} = $this{file_id};

	$data->{first} and next; # shortcurt after first
	$data->{first} = $this{filename};
	$data->{begintime} = $this{time};
	$data->{firstid} = $this{file_id};
    }
    my $fmt = $self->conf('datefmt'); # for picasagallery only
    if ($fmt) {			# hacks!!! for picasagallery
	$data->{mtime} = $data->{modified} / $data->{files};
	$data->{begintime} = $data->{time} =
	    strftime($fmt, localtime $data->{begintime});
	$data->{endtime} = strftime($fmt, localtime $data->{endtime});
    }
    my $elap = tv_interval($t0);
    warn "plstats $path took $elap\n" if $conf->{debug};
    return $data;
}

# stats of given result set moves values from DB to perl object
sub dbstats {
    my $self = shift;
    my $rs = shift;
    my $path = shift;
    my $t0 = [gettimeofday];
    my $num = $rs->count
	or return {};
    my $half = int($num/2);
    warn "stats on $num\n";
    my($first, $middle, $last) =  (
	$rs->slice(0, 0),
	$rs->slice($half, $half),
	$rs->slice($num - 1, $num - 1));
    my $bytes = $rs->get_column('bytes');
    my $width = $rs->get_column('width');
    my $height = $rs->get_column('height');
    my $pixels = $rs->get_column('pixels');
    my $time = $rs->get_column('time');
    my $fmt = $self->conf('datefmt');
    my $data = {
	files => $num,
	bytes => $bytes->sum,
	width => $width->sum,
	height => $height->sum,
	pixels => $pixels->sum,

	# picasagallery needs formatted times, else return raw times
	time => $fmt ? strftime($fmt, localtime $time->min) : $time->sum,
	begintime => $fmt ? strftime($fmt, localtime $time->min) : $time->min,
	endtime => $fmt ? strftime($fmt, localtime $time->max) : $time->max,

	firstid => $first->file_id,   # thumbnail generator can use
	middleid => $middle->file_id, # first-middle-last as key for
	lastid => $last->file_id,	    # automated updates

	first => $first->filename,     # thumbnail generator could
	physical => $middle->filename, # look these up but might as
	last => $last->filename,       # well do it while here

	mtime => $time->max,
    };
    my $elap = tv_interval($t0);
    warn "dbstats $path took $elap\n" if $conf->{debug};
    return $data;
}

# return value of named stat, 0=sum,1=mean, 0=file,1=dir
sub stat {
    my $self = shift;
    my $stat = shift || 'files';
    my $avg = shift ? 1 : 0;
    my $which = shift ? 'dir' : 'file';
    return $avg			# mean average, as integer:
	? int($self->{$which}{$stat} / ($self->{$which}{files} || 1) + 0.5)
	: $self->{$which}{$stat}; # default = sum
}
sub files { shift->stat('files', @_) }
sub dirs { shift->stat('dirs', @_) }
sub bytes { shift->stat('bytes', @_) }
sub width { shift->stat('width', @_) }
sub height { shift->stat('height', @_) }
sub pixels { shift->stat('pixels', @_) }
sub tagged { shift->stat('tagged', @_) }
sub captioned { shift->stat('caption', @_) }

sub sums {
    my $self = shift;
    my $this = $self->{file};
    return sprintf "%.0f MB (%.0f MP) in %d files in %d dirs",
	$this->{bytes} / 1024 / 1024,
	$this->{pixels} / 1000 / 1000,
	$this->{files}, $this->{dirs};
}

# see stats in picasagallery for more options!!!
sub averages {
    my($self, $x, $y, $scale) = @_;
    my $this = $self->{file};
    my $files = $this->{files};
    my $w = $this->{width} / $files;
    my $h = $this->{height} / $files;
    my $str = sprintf "%.0f KB (%.0f KP) %.0f x %.0f (%.3f)",
	$this->{bytes} / 1024 / $files,
	$this->{pixels} / 1000 / $files,
	$w, $h, $w / $h;
    if ($scale or $x and $y) {	# scale of displayed pictures
	$scale = $x / $w < $y / $h ? $x / $w : $y / $h
	    unless $scale;
	$scale *= 2 / 3 if $this->{file} =~ m!/$!;
	$str .= sprintf " %.0f%%", 100 * $scale;
    }
    return $str;
}

sub children {			# pass dir or file
    my $self = shift;
    my $which = shift || 'file';
    return $self->{$which}{children} || [];
}

# verbatim from Picasa.pm
sub dirfile { # similar to fileparse, but leave trailing / on directories
    my($path) = @_;
    my $end = $path =~ s@/+$@@ ? '/' : '';
    my($dir, $file) = ('/', '');
    ($dir, $file) = ($1, $2) if $path =~ m!(.*/)([^/]+)$!;
    return "$dir", "$file$end";
}

# ------------------------------------------------------------
# adapted from Picasa.pm

# given a virtual path, return all data known about it with current filters
sub filter {
    my($self, $path, $opt) = @_;
    my $t0 = [gettimeofday];
    my $schema = $self->schema;
    my $mtime = (CORE::stat $self->conf('dbfile'))[9];
    if ($mtime > $self->{mtime}) {
	$self->{root} = {};	# discard and rebuild all paths
	my $paths = $schema->resultset('Path')->search();
	while (my $one = $paths->next) {
	    $self->{root}{$one->path} = $one->path_id;
	}
	#	print Dumper $self->{root};
	$self->{mtime} = $mtime;
    }
    $opt or $opt = 0;
    $path =~ s@/+@/@g;
    # warn "filter:$path\n" if $conf->{debug};

    my @filter;			# filter the pictures - set by the UI
    $conf->{filter}{Tags}     and push @filter, (tag => { '!=' => undef });
    $conf->{filter}{Captions} and push @filter, (caption => { '!=' => undef });
    $conf->{filter}{age} and
	push @filter, (time => { '>' => $conf->{filter}{age} });
    my $rs = $schema->resultset('PathView')->search(
	{ file_id => { '!=' => undef },
	  path => { like => "$path%" },
	  @filter,		# user toggles these on GUI
	},
	{ group_by => 'file_id', # count each file only once
	  order_by => 'time', # time order needed for first/middle/last
	  cache => 1,	      # faster if rows are checked > once
	}) or return {};

#    my $data = $self->dbstats($rs, $path); # 2X slower than perl
    my $data = $self->plstats($rs, $path); # 2X faster than DB

    ($data->{dir}, $data->{file}) = dirfile $path;


    my $t00 = [gettimeofday];
    my $lp = length $path;
    my %child;			# children of this parent
    my $sort;
    @$sort = keys %{$self->{root}};
    for my $str (@$sort) {
    	next unless 0 == index($str, $path); # match
    	my $rest = substr $str, $lp;
    	$rest =~ s!/.*!/!;
    	$rest and $child{$rest}++; # entries in this directory
    }
    # DB too slow, use cache in perl instead...
    my $elapsed0 = tv_interval($t00);
    warn "virtual $path took $elapsed0\n" if $conf->{debug};
    $data->{children} = [ sort keys %child ];

    my $elapsed = tv_interval($t0);
    warn "filter $path took $elapsed\n" if $conf->{debug};
    return $data;
}

# return metadata of given picture filename
sub pics {
    my($self, $filename) = @_;
    my $rs = $self->schema->resultset('PathView')->search(
	{ file_id => { '!=' => undef },
	  filename => $filename },
	{ group_by => 'file_id' });
    my $data = $self->plstats($rs, $filename);
    $data->{rot} = $rs->get_column('rotation')->min;
    ($data->{dir}, $data->{file}) = dirfile $filename;
    return $data;
}

# twiddle location in the virtual tree and selected node (file):

# nearly verbatim from Picasa.pm

# move to the virtual location of given picture
sub goto {
    my($self, $pic) = @_;
    $pic =~ s@/+@/@g;
    ($self->{dir}{dir}, $self->{dir}{file}) = dirfile $pic;
    $self->up;
}

# TODO: option to automove to next directory if at end of this one
sub next {
    my($self, $n, $pindexdone) = @_;
    $self->{pindex} = $self->{index} unless $pindexdone;
    $self->{index} += defined $n ? $n : 1;
    my @child = @{$self->{dir}{children}};
    my $child = @child;
    $self->{index} = $child - 1 if $self->{index} >= $child;
    $self->{index} = 0 if $self->{index} < 0;
    $self->{file} = $self->
	filter("$self->{dir}{dir}$self->{dir}{file}$child[$self->{index}]");
}
# TODO: option to automove to prev directory if at beginning of this one
sub prev {
    my($self, $n) = @_;
    $self->{pindex} = $self->{index};
    $self->{index} -= defined $n ? $n : 1;
    my @child = @{$self->{dir}{children}};
    $self->{index} = 0 if $self->{index} < 0;
    $self->{file} = $self->
	filter("$self->{dir}{dir}$self->{dir}{file}$child[$self->{index}]");
}
# back up into parent directory, with current file selected
sub up {
    my($self) = @_;
    my $file = $self->{dir}{file}; # current location should be selected after up
    warn "chdir $self->{dir}{dir}\n" if $conf->{debug};
    $self->{dir} = $self->filter("$self->{dir}{dir}");
    my $index = 0;
    for my $c (@{$self->{dir}{children}}) {
	last if $c eq $file and $file = '!file found!';
	$index++;
    }
    $index = 0 if $file ne '!file found!';
    $self->{pindex} = $self->{index};
    $self->{index} = $index;
    $self->next(0, 1);
}
# step into {file} of current {dir}
sub down {
    my($self) = @_;
    return 0 unless $self->{file}{file} =~ m!/$!;
    warn "chdir $self->{file}{dir}$self->{file}{file}\n" if $conf->{debug};
    $self->{dir} = $self->filter("$self->{file}{dir}$self->{file}{file}");
    $self->{index} = -1;
    $self->next;
    return 1;
}

# reapply current filters, moving up if needed
sub filtermove {
    my($self) = @_;
    while (($self->{dir} = $self->filter("$self->{dir}{dir}$self->{dir}{file}")
	    and !$self->{dir}{files})) {
	$self->up;
	last if $self->{dir}{file} eq '/';
    }
    $self->next(0, 1);
}

1;				# LPDB.pm

__END__

=head1 DATABASE FILES and their TABLES

Picture metadata is stored in one file (C<.lpdb.db> by default) and
picture thumbnails in another (C<.lpdb-thumb.db>).  These filenames
are configurable at creation.  These files can be viewed by C<sqlite3>
or any compatible programming language.  LPDB accesses the database
via L<DBIx::Class> which also maintains the schema documentation
linked below.

The tables are defined by SQL in C<lib/LPDB/*.sql>.  Any times stored
are in seconds since the unix epoch of 1970.  The table content and
purpose are as follows:

=over

=item Directories, see L<LPDB::Schema::Result::Directory>

Each directory that holds one or more pictures on disk is recorded.
By default, L<lpgallery> keeps pictures grouped together in these
B<"galleries"> of pictures, even when viewing a larger list by other
metadata.  Each entry has a base name and a parent reference to record
the whole physical directory tree.  Also recorded is the begin and end
time of the pictures of the directory.

If all pictures are stored in only one directory, then there is just
one gallery.  It might be better to organize photos into separate
directories per day or month or per place or event.  Photographers may
have a directory per location or per client.

=item Pictures, see L<LPDB::Schema::Result::Picture>

Each row represents a single picture or video file.  Some metadata
from the file is recorded here such as image size and time.  Duration
is seconds of runtime for videos or NULL for still images.

=item Paths, see L<LPDB::Schema::Result::Path>

Paths enables L<LPDB::VFS>, a virtual file system of alterative useful
ways to navigate the data based on metadata like time, people,
captions, tags, stars and so on.  This is similar to B<Directories>
above except that these paths don't exist on disk.  Pictures can be in
many virtual paths, see the next table.

=item PicturePath, see L<LPDB::Schema::Result::PicturePath>

This joins many B<Pictures> to many B<Paths>, placing images in
several logical places in the tree based on their metadata.  All
pictures will be listed in the original location on disk and in the
timelines.  Other locations depend on metadata of the picture.


=item Contacts, see L<LPDB::Schema::Result::Contact>

Picasa or F<.names.txt> people in B<Pictures> are stored here.  They
can optionally have birthdays from F<.birthdays.txt>, see
L<lpgallery>.

=item Faces, see L<LPDB::Schema::Result::Face>

This joins many B<Contcts> to B<Pictures>.  Face rectangles from
Picasa are also stored.  A file_id of 0 instead comes from
F<.names.txt> as the name applies to all files of the dir_id.

=item Tags, see L<LPDB::Schema::Result::Tag>

Words of EXIF keywords or subject are stored

=item PicturePath, see L<LPDB::Schema::Result::PicturePath>

This joins many B<Tags> to many B<Pictures>

=item Albums, see L<LPDB::Schema::Result::Album>

Words of EXIF keywords or subject are stored

=item PicturePath, see L<LPDB::Schema::Result::PicturePath>

This joins many B<Albums> to many B<Pictures>


!!!!!!!!!!!!!!TODO!!!!!!!!!!!!!!

=back

=head1 SEE ALSO

L<LPDB::Filesystem>, L<lpgallery>, L<DBIx::Class>

=head1 AUTHOR

Timothy D Witham <twitham@sbcglobal.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2013-2024 Timothy D Witham.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
