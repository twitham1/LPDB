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

1;				# Object.pm
