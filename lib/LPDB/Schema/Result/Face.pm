use utf8;
package LPDB::Schema::Result::Face;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LPDB::Schema::Result::Face - Joins many pictures to many contacts

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<Faces>

=cut

__PACKAGE__->table("Faces");

=head1 ACCESSORS

=head2 dir_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 file_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

0 means all pictures of the directory, with no left/top/right/bottom

=head2 contact_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 left

  data_type: 'float'
  is_nullable: 1

left edge of the face rectangle, 0-1

=head2 top

  data_type: 'float'
  is_nullable: 1

top edge of the face rectangle, 0-1

=head2 right

  data_type: 'float'
  is_nullable: 1

right edge of the face rectangle, 0-1

=head2 bottom

  data_type: 'float'
  is_nullable: 1

bottom edge of the face rectangle, 0-1

=cut

__PACKAGE__->add_columns(
  "dir_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "file_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "contact_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "left",
  { data_type => "float", is_nullable => 1 },
  "top",
  { data_type => "float", is_nullable => 1 },
  "right",
  { data_type => "float", is_nullable => 1 },
  "bottom",
  { data_type => "float", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</dir_id>

=item * L</file_id>

=item * L</contact_id>

=back

=cut

__PACKAGE__->set_primary_key("dir_id", "file_id", "contact_id");

=head1 RELATIONS

=head2 contact

Type: belongs_to

Related object: L<LPDB::Schema::Result::Contact>

=cut

__PACKAGE__->belongs_to(
  "contact",
  "LPDB::Schema::Result::Contact",
  { contact_id => "contact_id" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 dir

Type: belongs_to

Related object: L<LPDB::Schema::Result::Directory>

=cut

__PACKAGE__->belongs_to(
  "dir",
  "LPDB::Schema::Result::Directory",
  { dir_id => "dir_id" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);

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


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2024-09-30 00:49:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:5bMew+NEKPaa9Q1BUaC6bQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
