# Here is where we add methods to the DB objects (rows)

# ------------------------------------------------------------
# Picture extensions

package LPDB::Schema::Result::Picture;

sub pathtofile {		# full filesystem path to image file
    return $_[0]->dir->directory . $_[0]->basename;
}

sub pixels {			# return pixels of the picture
    return $_[0]->width * $_[0]->height;
}

sub ratio {			# width to height ratio
    $_[0]->height || return 0;
    return $_[0]->width / $_[0]->height;
}

# sub thumbnail {
#     my($self) = @_;
#     return 
# }

# ------------------------------------------------------------
# Path extensions

package LPDB::Schema::Result::Path;

# sub first {		    # return first picture below path
#     my($self) = @_;
#     my $schema = $self->result_source->schema; # any way to find both in 1 query?
#     return $schema->resultset('PathView')->find(
#     	{path => { like => $self->path . '%'},
# 	 time => { '!=' => undef } },
# 	{order_by => { -asc => 'time' },
# 	 rows => 1,
#     	});
# }
# sub last {			# return last picture below path
#     my($self) = @_;
#     my $schema = $self->result_source->schema; # any way to find both in 1 query?
#     return $schema->resultset('PathView')->find(
#     	{path => { like => $self->path . '%'},
# 	 time => { '!=' => undef } },
# 	{order_by => { -desc => 'time' },
# 	 rows => 1,
#     	});
# }

sub basename {			# final component of path
    $_[0]->path =~ m{(.*/)(.+/?)} and
	return $2;
    return '/';
}
sub pathtofile {		# alias used by goto of ThumbViewer
    $_[0]->basename;
}

sub resultset {		 # all files below logical path, in time order
    my($self) = @_;
    my $schema = $self->result_source->schema;
    return $schema->resultset('PathView')->search(
    	{path => { like => $self->path . '%'},
	 time => { '!=' => undef },
	 @{$self->{filter}} },
	{order_by => { -asc => 'time' },
	 group_by => 'file_id',
	 columns => [ qw/time file_id dir_id/ ],
    	});
}

sub picturecount {
    return $_[0]->resultset->count || 0;
}

sub stack { # stack of up to 3 paths (first middle last), for thumbnails
    my($self) = @_;
    my $rs = $self->resultset;
    my $num = $rs->count
	or return ();
    my $half = int($num/2);
    return (
	$rs->slice(0, 0),
	($half && $half != $num - 1 ?  $rs->slice($half, $half) : undef),
	($num > 1 ?  $rs->slice($num - 1, $num - 1) : undef),
	);
}

sub time {		 # return begin/middle/end time from the stack
    my($self, $n) = @_;	 # 0, 1, 2
    my @s = $self->stack;
    $n < 3 or return $s[0]->time;
    return $s[$n] ? $s[$n]->time :
	$s[--$n] ? $s[$n]->time
	: $s[0]->time;
}

1;
