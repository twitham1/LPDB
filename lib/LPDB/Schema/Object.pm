# Here is where we add methods to the DB objects that also need access
# to the LPDB object.  I've not yet found how to merge this into
# Result/* where the rest of them went as over there it doesn't have
# $self->{filter}.

# ------------------------------------------------------------
# Path extensions

package LPDB::Schema::Result::Path;

=head2 resultset

Return all File objects below this logical path in time order per the
current {filter => []}.

=cut

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

# =head2 count (alias picturecount)

# Return count of image files below current path.

# =cut

# sub count {
#     my($self) = @_;
#     defined $self->{count} or $self->{count} = $self->resultset->count || 0;
#     return $self->{count};
# }

# sub picturecount {
#     return $_[0]->count;
# }

# =head2 stack

# Return a stack of up to 3 Paths (first middle last), used for
# generating thumbnail stacks.

# =cut

# sub stack { # stack of up to 3 paths (first middle last), for thumbnails
#     my($self) = @_;
#     $self->{stack} and return @{$self->{stack}}; # TODO: when to drop cache?
#     my $rs = $self->resultset;
#     my $num = $self->count
# 	or return ();
#     my $half = int($num/2);
#     my @out = $rs->slice(0, 0);
#     push @out, ($half && $half != $num - 1 ?  $rs->slice($half, $half) : undef);
#     push @out, ($num > 1 ?  $rs->slice($num - 1, $num - 1) : undef);
#     return @{$self->{stack} = [ @out ]};
# }

# =head2 time

# Return begin / middle / end time of the picture stack above.

# =cut

# sub time {		 # return begin/middle/end time from the stack
#     my($self, $n) = @_;	 # 0, 1, 2
#     my @s = $self->stack;
#     $n < 3 or return $s[0]->time;
#     return $s[$n] ? $s[$n]->time :
# 	$s[--$n] ? $s[$n]->time
# 	: $s[0]->time;
# }

# =head2 random

# Return a random picture from the path.

# =cut

# sub random {			# return a random picture from the path
#     my($self) = @_;
#     my $rs = $self->resultset;
#     my $n = int(rand($self->count));
#     return ($rs->slice($n, $n));
# }

package LPDB::Schema::Result::Picture;

=head2

Given a picture, return its file_id unless in a [People] path with
facecrops checked.  In that case, return his file_id, contact_id.
This is used to pull face L<LPDB::Thumbnail> out of pictures for the
draw routines in L<Prima::LPDB::ThumbViewer>.

=cut

sub ids {
    my($self, $pic, $path) = @_;
    my $name = $path =~ m{/\[People\]/([^/]+)} ? $1 : undef;
    my $schema = $self->result_source->schema;
    my $rs = $schema->resultset('PathView')->find(
	{file_id => $pic->file_id,
	 path => $path,
	 contact => $name || undef},
	{group_by => [qw/file_id contact_id/]} # not sure needed here...
	);
    $rs or return $pic->file_id;
    # warn "found for $pic $contact:", $rs->contact, $rs->left, $rs->top, $rs->right, $rs->bottom;
    return $rs->file_id, $rs->contact_id || undef;
}

1;				# Object.pm
