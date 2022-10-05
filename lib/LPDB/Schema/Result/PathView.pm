use utf8;
package LPDB::Schema::Result::PathView;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LPDB::Schema::Result::PathView

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->table_class("DBIx::Class::ResultSource::View");

=head1 TABLE: C<PathView>

=cut

__PACKAGE__->table("PathView");

=head1 ACCESSORS

=head2 path_id

  data_type: 'integer'
  is_nullable: 1

=head2 path

  data_type: 'text'
  is_nullable: 1

=head2 parent_id

  data_type: 'integer'
  is_nullable: 1

=head2 file_id

  data_type: 'integer'
  is_nullable: 1

=head2 basename

  data_type: 'text'
  is_nullable: 1

=head2 dir_id

  data_type: 'integer'
  is_nullable: 1

=head2 bytes

  data_type: 'integer'
  is_nullable: 1

=head2 modified

  data_type: 'integer'
  is_nullable: 1

=head2 time

  data_type: 'integer'
  is_nullable: 1

=head2 rotation

  data_type: 'integer'
  is_nullable: 1

=head2 width

  data_type: 'integer'
  is_nullable: 1

=head2 height

  data_type: 'integer'
  is_nullable: 1

=head2 caption

  data_type: 'text'
  is_nullable: 1

=head2 duration

  data_type: 'real'
  is_nullable: 1

=head2 stars

  data_type: 'integer'
  is_nullable: 1

=head2 attrs

  data_type: 'text'
  is_nullable: 1

=head2 pixels

  data_type: (empty string)
  is_nullable: 1

=head2 filename

  data_type: (empty string)
  is_nullable: 1

=head2 tag_id

  data_type: 'integer'
  is_nullable: 1

=head2 tag

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "path_id",
  { data_type => "integer", is_nullable => 1 },
  "path",
  { data_type => "text", is_nullable => 1 },
  "parent_id",
  { data_type => "integer", is_nullable => 1 },
  "file_id",
  { data_type => "integer", is_nullable => 1 },
  "basename",
  { data_type => "text", is_nullable => 1 },
  "dir_id",
  { data_type => "integer", is_nullable => 1 },
  "bytes",
  { data_type => "integer", is_nullable => 1 },
  "modified",
  { data_type => "integer", is_nullable => 1 },
  "time",
  { data_type => "integer", is_nullable => 1 },
  "rotation",
  { data_type => "integer", is_nullable => 1 },
  "width",
  { data_type => "integer", is_nullable => 1 },
  "height",
  { data_type => "integer", is_nullable => 1 },
  "caption",
  { data_type => "text", is_nullable => 1 },
  "duration",
  { data_type => "real", is_nullable => 1 },
  "stars",
  { data_type => "integer", is_nullable => 1 },
  "attrs",
  { data_type => "text", is_nullable => 1 },
  "pixels",
  { data_type => "", is_nullable => 1 },
  "filename",
  { data_type => "", is_nullable => 1 },
  "tag_id",
  { data_type => "integer", is_nullable => 1 },
  "tag",
  { data_type => "text", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-09-26 16:20:54
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IcbSTZcY27egM3eHlFpTCw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
