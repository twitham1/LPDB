use utf8;
package LPDB::Schema::Result::PictureTag;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LPDB::Schema::Result::PictureTag - Joins many pictures to many tags

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<PictureTag>

=cut

__PACKAGE__->table("PictureTag");

=head1 ACCESSORS

=head2 file_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 tag_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "file_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "tag_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</file_id>

=item * L</tag_id>

=back

=cut

__PACKAGE__->set_primary_key("file_id", "tag_id");

=head1 RELATIONS

=head2 file

Type: belongs_to

Related object: L<LPDB::Schema::Result::Picture>

=cut

__PACKAGE__->belongs_to(
  "file",
  "LPDB::Schema::Result::Picture",
  { file_id => "file_id" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 tag

Type: belongs_to

Related object: L<LPDB::Schema::Result::Tag>

=cut

__PACKAGE__->belongs_to(
  "tag",
  "LPDB::Schema::Result::Tag",
  { tag_id => "tag_id" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2021-10-13 00:56:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:3HrWlWczRfeeyr/9l6mdZw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
