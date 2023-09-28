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

sub hms {			# formatted video duration
    my $dur = $_[0]->duration or return '';
    return $dur > 59 ? sprintf '%d:%02d:%02d',
	$dur / 3600, $dur % 3600 / 60, $dur % 60
	: $dur > 1 ? "$dur seconds" : "$dur second";
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
    $self->{resultset} and return $self->{resultset};
    my $schema = $self->result_source->schema;
    $self->{resultset} = $schema->resultset('PathView')->search(
    	{path => { like => $self->path . '%'},
	 time => { '!=' => undef },
	 @{$self->{filter}} },
	{order_by => { -asc => 'time' },
	 group_by => 'file_id',
	 columns => [ qw/time file_id dir_id/ ],
	 # cache => 1,		# does this work?
    	});
    return $self->{resultset};
}

sub count {
    my($self) = @_;
    defined $self->{count} or $self->{count} = $self->resultset->count || 0;
    return $self->{count};
}
sub picturecount {
    return $_[0]->count;
}

sub stack { # stack of up to 3 paths (first middle last), for thumbnails
    my($self) = @_;
    $self->{stack} and return @{$self->{stack}}; # TODO: when to drop cache?
    my $rs = $self->resultset;
    my $num = $self->count
	or return ();
    my $half = int($num/2);
    my @out = $rs->slice(0, 0);
    push @out, ($half && $half != $num - 1 ?  $rs->slice($half, $half) : undef);
    push @out, ($num > 1 ?  $rs->slice($num - 1, $num - 1) : undef);
    return @{$self->{stack} = [ @out ]};
}

sub time {		 # return begin/middle/end time from the stack
    my($self, $n) = @_;	 # 0, 1, 2
    my @s = $self->stack;
    $n < 3 or return $s[0]->time;
    return $s[$n] ? $s[$n]->time :
	$s[--$n] ? $s[$n]->time
	: $s[0]->time;
}

sub random {			# return a random picture from the path
    my($self) = @_;
    my $rs = $self->resultset;
    my $n = int(rand($self->count));
    return ($rs->slice($n, $n));
}

1;
