use utf8;
package LPDB::Schema::Result::Picture;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LPDB::Schema::Result::Picture - Picture files that hold images

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<Pictures>

=cut

__PACKAGE__->table("Pictures");

=head1 ACCESSORS

=head2 file_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 basename

  data_type: 'text'
  is_nullable: 0

Base name to the image file contents

=head2 dir_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

ID of the directory of the file

=head2 bytes

  data_type: 'integer'
  is_nullable: 1

Size of the image file in bytes

=head2 modified

  data_type: 'integer'
  is_nullable: 1

Last modified timestamp of the image file

=head2 time

  data_type: 'integer'
  is_nullable: 1

Time image was taken if known from EXIF, else file create or modify time

=head2 rotation

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

Orientation of the camera in degrees: 0, 90, 180, 270

=head2 width

  data_type: 'integer'
  is_nullable: 1

Displayed horizontal width of the image in pixels, after rotation correction

=head2 height

  data_type: 'integer'
  is_nullable: 1

Displayed vertical height of the image in pixels, after rotation correction

=head2 caption

  data_type: 'text'
  is_nullable: 1

EXIF caption or description

=head2 duration

  data_type: 'real'
  is_nullable: 1

video duration in seconds or undefined for pictures

=head2 stars

  data_type: 'integer'
  is_nullable: 1

optional star rating

=head2 attrs

  data_type: 'text'
  is_nullable: 1

optional attribute string

=cut

__PACKAGE__->add_columns(
  "file_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "basename",
  { data_type => "text", is_nullable => 0 },
  "dir_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "bytes",
  { data_type => "integer", is_nullable => 1 },
  "modified",
  { data_type => "integer", is_nullable => 1 },
  "time",
  { data_type => "integer", is_nullable => 1 },
  "rotation",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
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
);

=head1 PRIMARY KEY

=over 4

=item * L</file_id>

=back

=cut

__PACKAGE__->set_primary_key("file_id");

=head1 RELATIONS

=head2 dir

Type: belongs_to

Related object: L<LPDB::Schema::Result::Directory>

=cut

__PACKAGE__->belongs_to(
  "dir",
  "LPDB::Schema::Result::Directory",
  { dir_id => "dir_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 faces

Type: has_many

Related object: L<LPDB::Schema::Result::Face>

=cut

__PACKAGE__->has_many(
  "faces",
  "LPDB::Schema::Result::Face",
  { "foreign.file_id" => "self.file_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 picture_albums

Type: has_many

Related object: L<LPDB::Schema::Result::PictureAlbum>

=cut

__PACKAGE__->has_many(
  "picture_albums",
  "LPDB::Schema::Result::PictureAlbum",
  { "foreign.file_id" => "self.file_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 picture_paths

Type: has_many

Related object: L<LPDB::Schema::Result::PicturePath>

=cut

__PACKAGE__->has_many(
  "picture_paths",
  "LPDB::Schema::Result::PicturePath",
  { "foreign.file_id" => "self.file_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 picture_tags

Type: has_many

Related object: L<LPDB::Schema::Result::PictureTag>

=cut

__PACKAGE__->has_many(
  "picture_tags",
  "LPDB::Schema::Result::PictureTag",
  { "foreign.file_id" => "self.file_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 thumbs

Type: has_many

Related object: L<LPDB::Schema::Result::Thumb>

=cut

__PACKAGE__->has_many(
  "thumbs",
  "LPDB::Schema::Result::Thumb",
  { "foreign.file_id" => "self.file_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 albums

Type: many_to_many

Composing rels: L</picture_albums> -> album

=cut

__PACKAGE__->many_to_many("albums", "picture_albums", "album");

=head2 paths

Type: many_to_many

Composing rels: L</picture_paths> -> path

=cut

__PACKAGE__->many_to_many("paths", "picture_paths", "path");

=head2 tags

Type: many_to_many

Composing rels: L</picture_tags> -> tag

=cut

__PACKAGE__->many_to_many("tags", "picture_tags", "tag");


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2024-09-30 00:49:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:EyRutGZel7p6AxWadKNB8A


# You can replace this text with custom code or comments, and it will be preserved on regeneration

=head1 METHODS

Methods are functions of the above table columns.

=head1 METHODS

=head2 pathtofile

Returns to full filesystem path to the image file

=cut

sub pathtofile {
    return $_[0]->dir->directory . $_[0]->basename;
}

=head2 pixels

Returns the pixels (width * height) of the image.

=cut

sub pixels {
    return $_[0]->width * $_[0]->height;
}

=head2 ratio

Returns the floating point width to height ratio of the image in final
displayed orientation after any rotation correction.

=cut

sub ratio {
    $_[0]->height
	or return 0;
    return $_[0]->width / $_[0]->height;
}

=head2 hms

Returns a formatted time string of the duration of the video or the
empty string for still images.  The format is "H:MM:SS" if over 59
seconds or "N seconds" otherwise.

=cut

sub hms {
    my $dur = $_[0]->duration or return '';
    return $dur > 59 ? sprintf '%d:%02d:%02d',
	$dur / 3600, $dur % 3600 / 60, $dur % 60
	: $dur > 1 ? "$dur seconds" : "$dur second";
}

=head1 SEE ALSO

L<LPDB>

=cut

1;				# Picture.pm
