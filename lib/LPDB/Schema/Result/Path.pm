use utf8;
package LPDB::Schema::Result::Path;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LPDB::Schema::Result::Path - Virtual logical collections of pictures

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<Paths>

=cut

__PACKAGE__->table("Paths");

=head1 ACCESSORS

=head2 path_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 path

  data_type: 'text'
  is_nullable: 0

Logical path to a collection of pictures

=head2 parent_id

  data_type: 'integer'
  is_nullable: 1

ID of parent path, 0 for / root

=cut

__PACKAGE__->add_columns(
  "path_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "path",
  { data_type => "text", is_nullable => 0 },
  "parent_id",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</path_id>

=back

=cut

__PACKAGE__->set_primary_key("path_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<path_unique>

=over 4

=item * L</path>

=back

=cut

__PACKAGE__->add_unique_constraint("path_unique", ["path"]);

=head1 RELATIONS

=head2 picture_paths

Type: has_many

Related object: L<LPDB::Schema::Result::PicturePath>

=cut

__PACKAGE__->has_many(
  "picture_paths",
  "LPDB::Schema::Result::PicturePath",
  { "foreign.path_id" => "self.path_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 files

Type: many_to_many

Composing rels: L</picture_paths> -> file

=cut

__PACKAGE__->many_to_many("files", "picture_paths", "file");


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2021-10-13 00:56:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:SWYs55YsguH2cnhWEKFtWA


# You can replace this text with custom code or comments, and it will be preserved on regeneration

=head1 METHODS

Methods are functions of the above table columns.

=head1 METHODS

=head2 basename (alias pathtofile)

Returns the basename, or final component of the path, that collects a
gallery of images.  The alisas is used by goto of
L<LPDB::ThumbViewer>.  This name is needed so that both Picture
objects and Path objects can use the same method.

=cut

sub basename {
    $_[0]->path =~ m{(.*/)(.+/?)} and
	return $2;
    return '/';
}

sub pathtofile {
    $_[0]->basename;
}

# in here this fails to find {filter} so it is still in ../Object.pm
# =head2 resultset

# Return all File objects below this logical path in time order per the
# current {filter => []}.

# =cut

# sub resultset {		 # all files below logical path, in time order
#     my($self) = @_;
#     $self->{resultset} and return $self->{resultset};
#     my $schema = $self->result_source->schema;
#     $self->{resultset} = $schema->resultset('PathView')->search(
#     	{path => { like => $self->path . '%'},
# 	 time => { '!=' => undef },
# 	 # @{$self->{filter}} },
# 	 @{$self->lpdb->{filter}} },
# 	{order_by => { -asc => 'time' },
# 	 group_by => 'file_id',
# 	 columns => [ qw/time file_id dir_id/ ],
# 	 # cache => 1,		# does this work?
#     	});
#     return $self->{resultset};
# }

=head2 count (alias picturecount)

Return count of image files below current path.

=cut

sub count {
    my($self) = @_;
    defined $self->{count} or $self->{count} = $self->resultset->count || 0;
    return $self->{count};
}

sub picturecount {
    return $_[0]->count;
}

=head2 stack

Return a stack of up to 3 Paths (first middle last), used for
generating thumbnail stacks.

=cut

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

=head2 time

Return begin / middle / end time of the picture stack above.

=cut

sub time {		 # return begin/middle/end time from the stack
    my($self, $n) = @_;	 # 0, 1, 2
    my @s = $self->stack;
    $n < 3 or return $s[0]->time;
    return $s[$n] ? $s[$n]->time :
	$s[--$n] ? $s[$n]->time
	: $s[0]->time;
}

=head2 random

Return a random picture from the path.

=cut

sub random {			# return a random picture from the path
    my($self) = @_;
    my $rs = $self->resultset;
    my $n = int(rand($self->count));
    return ($rs->slice($n, $n));
}

=head1 SEE ALSO

L<LPDB>

=cut

1;				# Path.pm
