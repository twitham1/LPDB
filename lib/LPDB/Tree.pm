package LPDB::Tree;

=head1 NAME

LPDB::Tree - navigate a logical tree of pictures in sqlite

=cut

use strict;
use warnings;
use Image::Magick;
use LPDB::Schema;
use LPDB::Schema::Object;	# object extensions by twitham

sub new {
    my($class, $lpdb) = @_;
    my $self = { schema => $lpdb->schema,
		 conf => $lpdb->conf,
    };
    bless $self, $class;
    return $self;
}

sub pathpics {		      # return paths and pictures of parent ID
    my($self, $id) = @_;
    my(@dirs, @pics);
    if (my $paths = $self->{schema}->resultset('Path')->search(
	    {parent_id => $id || 0},
	    {order_by => { -asc => 'path' },
	    })) {
	while (my $row = $paths->next) {
	    push @dirs, $row;
	}
    }
    if (my $pics = $self->{schema}->resultset('Picture')->search(
	    {path_id => $id || 0},
	    {order_by => { -asc => 'basename' },
	     prefetch => 'picture_paths',
	    })) {
	push @pics, $pics->all;
    }
    return \@dirs, \@pics;
}

sub node {			# return Path or Picture of ID
    my($self, $id) = @_;
    my $obj;
    if ($id < 0) {
	$obj = $self->{schema}->resultset('Path')->find(
	    { path_id => -1 * $id});
    } else {
	$obj = $self->{schema}->resultset('Picture')->find(
	    { file_id => $id});
    }
#    warn "node $id = $obj\n";
    return $obj;
}

1;