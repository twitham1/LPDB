use utf8;
package LPDB::Schema::Result::BookMark;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LPDB::Schema::Result::BookMark - Name / Value data store

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<BookMarks>

=cut

__PACKAGE__->table("BookMarks");

=head1 ACCESSORS

=head2 name_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 0

Name of the key

=head2 value

  data_type: 'text'
  is_nullable: 1

Value of the key

=cut

__PACKAGE__->add_columns(
  "name_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "value",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</name_id>

=back

=cut

__PACKAGE__->set_primary_key("name_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<name_unique>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("name_unique", ["name"]);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2024-06-25 18:46:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Z6HxPlb6/I/vcSukeeX02w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
