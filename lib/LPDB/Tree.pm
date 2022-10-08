package LPDB::Tree;

=head1 NAME

LPDB::Tree - navigate a logical tree of pictures in sqlite

=cut

use strict;
use warnings;
use LPDB::Schema;
use LPDB::Schema::Object;	# object extensions by twitham

sub new {
    my($class, $lpdb) = @_;
    my $self = { schema => $lpdb->schema,
		 conf => $lpdb->conf,
		 id => 0,	# default id is last one
    };
    bless $self, $class;
    return $self;
}

sub pathpics {		     # return paths and pictures in given path
    my($self, $parent, $sort, $filter) = @_;
    my @filter;
    @filter = @$filter if $filter;
    $parent =~ s{/+}{/};	# cleanup
    my $id = $self->{id};
    if ($parent and my $obj =
	$self->{schema}->resultset('Path')->find(
	    { path => $parent})) {
	$id =  $obj->path_id;
    }
    $self->{id} = $id;
    my $paths;
    if ($paths = $self->{schema}->resultset('Path')->search(
	    {parent_id => $id})) {
    }
    my @pics;
    my $dur = 0;		# total video duration
    if (my $pics = $self->{schema}->resultset('Picture')->search(
	    { path_id => $id, @filter },
	    { order_by => $sort || [],
	      prefetch => [ 'picture_paths', 'dir', 'picture_tags'],
	      columns => [ qw/file_id duration/ ],
	      # required to tell DBIC to collapse has_many relationships
	      collapse => 1,
	    })) {

	# We can't afford returning full (big) picture objects, so
	# return IDs only then look up each picture as needed later.
	# get_column is fast but it loses the order.  Sorting all
	# records is slow no matter what, so "Fast" menu option exists
	# to take the fast DB order immediately (assumes Ungrouped).

	if (@$sort > 0) {	# slow full sort required
	    while (my $one = $pics->next) {
		push @pics, $one->file_id;
		$dur += $one->duration || 0;
	    }
	} else {		# no sort, instant DB order
	    @pics = $pics->get_column('file_id')->all;
	    map { $dur += $_ || 0 } @pics;
	}
#	warn "pics: @pics";
    }
    return [ $paths->all ], \@pics, $dur;
}

sub related {			# paths related to given path or picture
    my($self, $path, $id) = @_;
    my %path = ( $path => 1 );
    if ($id and my $paths = $self->{schema}->resultset('PicturePath')->search(
    	    {"me.file_id" => $id},
	    {prefetch => [ 'path', 'file' ]},
	)) {
	while (my $one = $paths->next) {
	    $path{$one->path->path . '/' . $one->file->pathtofile } = 1;
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
#    warn "tree picture: $id = $obj\n";
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
    # warn "tree id of $path = $id";
    return $id;
}

1;
