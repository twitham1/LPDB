use utf8;
package LPDB::Schema::Result::Path;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LPDB::Schema::Result::Path - Virtual logical collections of pictures

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<path>

=cut

__PACKAGE__->table("path");

=head1 ACCESSORS

=head2 path_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 path

  data_type: 'text'
  is_nullable: 0

Logical path to a collection of pictures

=cut

__PACKAGE__->add_columns(
  "path_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "path",
  { data_type => "text", is_nullable => 0 },
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


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2019-11-13 00:08:28
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Sw78jPVd2d6yqr9FIkPPRg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
