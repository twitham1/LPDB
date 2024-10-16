use utf8;
package LPDB::Schema::Result::PathCache;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LPDB::Schema::Result::PathCache - Cache of filtered sorted file_id per path

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<PathCache>

=cut

__PACKAGE__->table("PathCache");

=head1 ACCESSORS

=head2 cache

  data_type: 'text'
  is_nullable: 0

Selected path/filter/sort key

=head2 list

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "cache",
  { data_type => "text", is_nullable => 0 },
  "list",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</cache>

=back

=cut

__PACKAGE__->set_primary_key("cache");


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2024-10-16 01:26:54
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:A2dOoIx7g2fieWHK4m0X6A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
