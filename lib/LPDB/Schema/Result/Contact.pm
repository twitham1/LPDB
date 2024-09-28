use utf8;
package LPDB::Schema::Result::Contact;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LPDB::Schema::Result::Contact - Known people in pictures

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<Contacts>

=cut

__PACKAGE__->table("Contacts");

=head1 ACCESSORS

=head2 contact_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 hexid

  data_type: 'text'
  is_nullable: 1

Hexadecimal Picasa Identifier

=head2 name

  data_type: 'text'
  is_nullable: 0

Name of the person, required

=head2 email

  data_type: 'text'
  is_nullable: 1

Optional email address

=head2 birth

  data_type: 'integer'
  is_nullable: 1

Optional time of birth

=head2 death

  data_type: 'integer'
  is_nullable: 1

Optional time of death

=cut

__PACKAGE__->add_columns(
  "contact_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "hexid",
  { data_type => "text", is_nullable => 1 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "email",
  { data_type => "text", is_nullable => 1 },
  "birth",
  { data_type => "integer", is_nullable => 1 },
  "death",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</contact_id>

=back

=cut

__PACKAGE__->set_primary_key("contact_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<hexid_unique>

=over 4

=item * L</hexid>

=back

=cut

__PACKAGE__->add_unique_constraint("hexid_unique", ["hexid"]);

=head2 C<name_unique>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("name_unique", ["name"]);

=head1 RELATIONS

=head2 thumbs

Type: has_many

Related object: L<LPDB::Schema::Result::Thumb>

=cut

__PACKAGE__->has_many(
  "thumbs",
  "LPDB::Schema::Result::Thumb",
  { "foreign.contact_id" => "self.contact_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2024-09-28 00:18:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+LjqoqWCSS3KZ7J741t74A


# You can replace this text with custom code or comments, and it will
# be preserved on regeneration

# This relationship was generated when 2 database files were one.
# Assume I will still need this link between the 2 separate files.

=head1 RELATIONS

=head2 thumbs

Type: has_many

Related object: L<LPDB::Schema::Result::Thumb>

=cut

__PACKAGE__->has_many(
  "thumbs",
  "LPDB::Schema::Result::Thumb",
  { "foreign.contact_id" => "self.contact_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

1;
