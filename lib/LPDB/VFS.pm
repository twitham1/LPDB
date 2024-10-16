package LPDB::VFS;

=head1 NAME

LPDB::VFS - interact with the virtual file system of LPDB

=head1 DESCRIPTION

Not yet documented, see the source.  The VFS is a path hierarchy that
organizes the images by metadata in several ways.

=cut

use strict;
use warnings;
use LPDB::Schema;
use LPDB::Schema::Object;	# object extensions by twitham

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
	    my $obj = $self->{schema}->resultset('Path')->find_or_new(
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
    $self->{schema}->resultset('PicturePath')->find_or_create(
	{ path_id => $path_id,
	  file_id => $id });
}

# READING METHODS ------------------------------------------------------------

sub pathobject {		# return object of given path
    my($self, $parent) = @_;
    $parent or return;
#    warn "pathobj $parent";
    $parent =~ s{/+}{/};	# cleanup
    if ($parent and my $obj =
	$self->{schema}->resultset('Path')->find(
	    { path => $parent })) {
	return $obj;
    }
    return;
}

sub pathpics {		     # return paths and pictures in given path
    my($self, $parent, $filter, $sort) = @_;
    my @filter;
    @filter = @$filter if $filter;
    $parent =~ s{/+}{/};	# cleanup
    my $id = $self->{id};
    if ($parent and my $obj =
	$self->{schema}->resultset('Path')->find(
	    { path => $parent })) {
	$id =  $obj->path_id;
    }
    $self->{id} = $id;
    my $paths = $self->{schema}->resultset('Path')->search(
	{ parent_id => $id });
    my $dur = 0;		# total video duration

    use Data::Dumper;		# cache to the database
    local $Data::Dumper::Terse = 1;
    (my $string = Dumper($parent, $filter, $sort)) =~ s/\n//g;
    $string =~ s/ +//g;
    my $list = '';
    if (my $cache = $self->{schema}->resultset('PathCache')->find(
    	    { cache => $string })) {
	$list = $cache->list;
    # if (0) {
	warn "cache hit on: $string -> ", length($list), " bytes";

    } else {	    # not in cache: filter/sort and save list in cache

	my $pics = $self->{schema}->resultset('Picture')->search(
	    { path_id => $id, @filter },
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
	} else {	 # no sort, instant DB order, checkerboard!
	    $list = join '', map { " $_," . ++$gal }
	    $pics->get_column('file_id')->all;
	    map { $dur += $_ || 0 }
	    $pics->get_column('duration')->all;
	}
	$self->{schema}->resultset('PathCache')->update_or_create(
	    { cache => $string, list => $list });
    }
    # warn "list: $list";
    my @pics;
    map { push @pics, [ split ',', $_ ] } split ' ', $list;
    # warn Dumper "pics=", \@pics, 'dur=', $dur;
    return [ $paths->all ], \@pics, $dur, $list;
}

sub related {		      # paths related to given path or picture
    my($self, $path, $id) = @_;
    my %path = ( $path => 1 );
    if ($id and my $paths =
	$self->{schema}->resultset('PicturePath')->search(
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
	$self->{schema}->resultset('Picture');
    my $obj = $self->{rsallpics}->find($id);
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
	$self->{schema}->resultset('Picture');
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
