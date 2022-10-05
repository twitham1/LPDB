use utf8;
package LPDB::Schema::Result::TableComment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LPDB::Schema::Result::TableComment

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<table_comments>

=cut

__PACKAGE__->table("table_comments");

=head1 ACCESSORS

=head2 table_name

  data_type: 'text'
  is_nullable: 0

=head2 comment_text

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "table_name",
  { data_type => "text", is_nullable => 0 },
  "comment_text",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</table_name>

=back

=cut

__PACKAGE__->set_primary_key("table_name");


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-09-21 00:09:14
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:sJCwzbksQZMtpABJOSDwzQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
