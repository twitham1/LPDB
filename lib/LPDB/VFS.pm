package LPDB::VFS;

=head1 NAME

LPDB::VFS - interact with the virtual file system of LPDB

=head1 DESCRIPTION

Not yet documented, see the source.  The VFS is a path hierarchy that
organizes the images by metadata in several ways.

=cut

use strict;
use warnings;
use POSIX qw/strftime/;
use LPDB::Schema;
use LPDB::Schema::Object;	# object extensions by twitham
use Data::Dumper;

sub new {
    my($class, $lpdb) = @_;
    my $self = { lpdb => $lpdb,
		 schema => $lpdb->{schema},
		 conf => $lpdb->{conf},
		 id => 0,	# default id is last one
    };
    bless $self, $class;
    return $self;
}

sub schema {
    return $_[0]->{schema};
}

# verbatim from Picasa.pm
sub dirfile { # similar to fileparse, but leave trailing / on directories
    my($self, $path) = @_;
    my $end = $path =~ s@/+$@@ ? '/' : '';
    my($dir, $file) = ('/', '');
    ($dir, $file) = ($1, $2) if $path =~ m!(.*/)([^/]+)$!;
    return "$dir", "$file$end";
}

# WRITING METHODS ------------------------------------------------------------

# add a path and its parents to the virtual Paths table (see also
# similar _savedirs of Filesystem.pm)
{
    my %id;			# cache: {path} = id
    sub savepath {		# recursive up to root /
	my($self, $this) = @_;
	$this =~ m@/$@ or return;
	unless ($id{$this}) {
	    # warn "saving path $this";
	    my $obj = $self->schema->resultset('Path')->find_or_new(
		{ path => $this });
	    unless ($obj->in_storage) { # pre-existing?
		my($dir, $file) = $self->dirfile($this);
		$obj->parent_id($self->savepath($dir));
		$obj->insert;
	    }
	    $id{$this} = $obj->path_id;
	}
	return $id{$this};
    }
}
# connect a picture id to one logical path, creating it as needed
sub savepathfile {
    my($self, $path, $id) = @_;
    my $path_id = $self->savepath($path);
    $self->schema->resultset('PicturePath')->find_or_create(
	{ path_id => $path_id,
	  file_id => $id });
}

BEGIN {
    my $done = 0;
    sub commit {
	my($self) = @_;
	unless ($done == time) {
	    $self->schema->txn_commit;
	    # status "checked @ " . localtime $done;
	    $self->schema->txn_begin;
	    $done = time;
	}
    }
}

# sqlite> select MIN(time),AVG(time),MAX(time),count(distinct file_id) from PathView where path like "/[Folders]/%";
# 1213854021|1482244816.30303|1627612772|32

sub updatepaths {
    my($self) = @_;
    print "update total summary metadata of [Paths] in the tree\n";
    my $paths = $self->schema->resultset('Path')->search(
	{},
	{ order_by => 'path' });
    # $self->schema->txn_begin;
    while (my $path = $paths->next) {
	my $rs = $self->schema->resultset('PathView')->search(
	    { path => { like => $path->path . '%' }},
	    { group_by => 'file_id' });
	print join("\t", $path->path,
		   $rs->count,
		   $rs->get_column('time')->min,
		   int($rs->get_column('time')->func('avg')),
		   $rs->get_column('time')->max,
		   $rs->get_column('bytes')->func('total'),
		   $rs->get_column('duration')->func('total'),
		   $rs->get_column('stars')->func('total'),
	    ), "\n";
	my $p = $self->schema->resultset('Path')->find(
	    { path_id => $path->path_id });
	$p->update({
	    files	=> $rs->count,
	    beg		=> $rs->get_column('time')->min,
	    mid		=> int($rs->get_column('time')->func('avg')),
	    end		=> $rs->get_column('time')->max,
	    bytes	=> $rs->get_column('bytes')->func('total'),
	    stars	=> $rs->get_column('stars')->func('total'),
	    duration	=> int($rs->get_column('duration')->func('total')),
		   });
	# $self->commit;
    }
    # $self->schema->txn_commit;
}

sub updatecaptions {
    my($self) = @_;
    print "update [Captions] in the tree\n";
    my $pics = $self->schema->resultset('Picture')->search(
	{ caption => { '!=' => undef }},
	{ columns => [ qw/file_id caption/ ]});
    while (my $pic = $pics->next) {
	$self->savepathfile("/[Captions]/All/",
			    $pic->file_id);
	my $cap = $pic->caption;
	$cap =~ /^(.)/;
	my $letter = uc $1;
	$self->savepathfile("/[Captions]/Alphabetical/$letter/",
			    $pic->file_id);
	my $n = split/\s+/, $cap;
	$self->savepathfile(sprintf("/[Captions]/Words/%03d/", $n),
			    $pic->file_id);
    }
    # TODO: fix captions that disappeared or changed
}

{
    my $alias;
    sub updatefaces {
	my($self) = @_;
	$alias ||= $self->{lpdb}->conf('alias') || {};
	print "update [Faces] contacts in the tree\n";
	my $pics = $self->schema->resultset('PathView')->search(
	    {contact_id => { '!=' => undef } },
	    { group_by => [ qw/file_id contact_id/ ] });
#	$self->schema->txn_begin;
	while (my $pic = $pics->next) {
	    my $name = $pic->contact or next;
	    if ($alias->{$name}) {
		warn "$name merged into $alias->{$name}";
		my $old = $self->schema->resultset('Path')->search(
		    { path => { like => "/[Faces]/$name/%" } });
		$old->delete;
		(my $tmp = $alias->{$name}) =~ s/ +//g;
		$old = $self->schema->resultset('PathCache')->search(
		    { cache => { like => "%/[Faces]/$tmp/%" } });
		$old->delete;
		$name = $alias->{$name};
	    }
	    # warn "/[Faces]/$name/ in ", $pic->path, $pic->basename;
	    $self->savepathfile("/[Faces]/$name/", $pic->file_id);
	    # $self->commit;
	}
#	$self->schema->txn_commit;
    }
}

sub updatestars {
    my($self) = @_;
    print "update [Stars] = favorites in the tree\n";
    my $pics = $self->schema->resultset('PathView')->search(
	{ stars => { '!=' => undef } },
	{ group_by => [ 'file_id', ] });
    while (my $pic = $pics->next) {
	if ($pic->stars) {
	    $self->savepathfile("/[Stars]/All Years/", $pic->file_id);
	    my $time = $pic->time or next;
	    $self->savepathfile(strftime("/[Stars]/%Y/",
					 localtime $time), $pic->file_id);
	} else {
	    # TODO!!! remove star = 0 from Paths
	}
    }
}

sub updateflats {
    my($self) = @_;
    print "update [Flats] = flattened [Folders] of the tree\n";
    my $schema = $self->schema;
    my $pics = $schema->resultset('Picture')->search(
	undef,
	{ columns => [ qw/dir_id file_id basename/ ] });
    my $done = time;
    my $num;
    while (my $pic = $pics->next) {
	my $fid = $pic->file_id or next;
	my $path = $pic->pathtofile;
	my $n = $path =~ tr{/}{/} - 1;
	while ($n > 0 and $path =~ s{[^/]+/$}{}) {
	    $self->savepathfile("/[Flats]/$n/$path", $fid);
	    $n--;
	}
	$num++;
	unless ($done == time) {
	    warn "checked $num @ " . localtime $done;
	    $done = time;
	}
    }
}


# READING METHODS ------------------------------------------------------------

sub pathobject {		# return object of given path
    my($self, $parent) = @_;
    $parent or return;
#    warn "pathobj $parent";
    $parent =~ s{/+}{/};	# cleanup
    if ($parent and my $obj =
	$self->schema->resultset('Path')->find(
	    { path => $parent })) {
	return $obj;
    }
    return;
}

sub pathpics {		     # return paths and pictures in given path
    my($self, $parent, $filter, $sort, $psort, $picsfirst) = @_;

    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Indent = 0;
    (my $string = Dumper($parent, $filter, $sort, $psort, $picsfirst)) =~ s/\n//g;
    $string =~ s/ => /=>/g;
    my $list = '';		# cache to the database
    my $dur = 0;		# total video duration
    if (my $cache = $self->schema->resultset('PathCache')->find(
	    { cache => $string })) {
	$list = $cache->list;
	my $len = length $list;
	warn "cache hit on: $string ->\n", $len < 150 ? $list : "$len bytes";

    } else {	    # not in cache: filter/sort and save list in cache

	$filter or $filter = [];
	$parent =~ s{/+}{/};	# cleanup
	my $id = $self->{id};
	if ($parent and my $obj =
	    $self->schema->resultset('Path')->find(
		{ path => $parent },
		{ columns => qw/path_id/})) {
	    $id =  $obj->path_id;
	}
	$self->{id} = $id;

	my $paths = $self->schema->resultset('Path')->search(
	    { parent_id => $id },
	    { order_by => $psort || [],
	      columns => [ qw/path_id/ ]});
	my @path;
	for my $one ($paths->all) {
	    push @path, $one->path_id;
	}

	my $pics = $self->schema->resultset('Picture')->search(
	    { path_id => $id, @$filter },
	    { order_by => $sort || [],
	      prefetch => [ qw/picture_paths dir picture_tags faces/],
	      columns => [ qw/file_id dir_id duration/ ],
	      # required to tell DBIC to collapse has_many relationships
	      collapse => 1,
	    });

	# We can't afford returning full (big) picture objects, so
	# return IDs only then look up each picture as needed later.
	# get_column is fast but it loses the order.  Sorting all
	# records is slow no matter what, so "Fast" menu option exists
	# to take the fast DB order immediately (assumes Ungrouped).

	my $prev = my $gal = 0;
	if (@$sort > 0) {	# slow full sort required
	    for my $one ($pics->all) {
		my $now = $one->dir_id;
		$now != $prev and ++$gal;
		$prev = $now;
		$list .= ' ' . $one->file_id . ",$gal";
		$dur += $one->duration || 0;
	    }
	    chomp $list;
	} else {	    # no sort, instant DB order, checkerboard!
	    $list = join '', map { " $_," . ++$gal }
	    $pics->get_column('file_id')->all;
	    map { $dur += $_ || 0 }
	    $pics->get_column('duration')->all;
	}
	$list = $picsfirst ? join(' ', $list, @path) : join(' ', @path, $list);
	$self->schema->resultset('PathCache')->update_or_create(
	    { cache => $string, list => $list });
    }
    # return \@path, $list, $dur;
    return $list, $dur;
}

sub related {		      # paths related to given path or picture
    my($self, $path, $id) = @_;
    my %path = ( $path => 1 );
    if ($id and my $paths =
	$self->schema->resultset('PicturePath')->search(
    	    {"me.file_id" => $id},
	    {prefetch => [ 'path', 'file' ]},
	)) {
	while (my $one = $paths->next) {
	    $path{$one->path->path . '/' . $id } = 1;
	}
	return sort keys %path;
    }
    $path =~ s{//.*}{};		# trim away pathtofile to list parents
    while ($path =~ s{[^/]+/?$}{}) {
    	$path{$path} = 1 if length $path > 1;
    }
    return reverse sort keys %path;
}

sub picture {			# return picture object of given ID
    my($self, $id) = @_;
    $self->{rsallpics} ||=
	$self->schema->resultset('Picture');
    my $obj = $self->{rsallpics}->find($id);
#    warn "vfs picture: $id = $obj\n";
    return $obj;
}

sub path {			# return path object of given ID
    my($self, $id) = @_;
    $self->{rsallpaths} ||=
	$self->schema->resultset('Path');
    my $obj = $self->{rsallpaths}->find($id);
#    warn "vfs picture: $id = $obj\n";
    return $obj;
}

sub id_of_path {		# return ID of given pathtofile
    my($self, $path) = @_;
    # warn "id of $path";
    $path =~ m{(.*/)(.+)} or return undef;
    $2 or return undef;
    # warn "($1 / $2)";
    $self->{rspicdir} ||=
	$self->schema->resultset('Picture');
    my $obj = $self->{rspicdir}->find(
	{ 'dir.directory' => $1,
	      'basename' => $2,
	},
	{ join => 'dir',
	  columns => [ qw/file_id/ ],
	});
    $obj or return undef;
    # warn "obj=$obj";
    my $id = $obj->file_id
	or return undef;
    # warn "vfs id of $path = $id";
    return $id;
}

1;
