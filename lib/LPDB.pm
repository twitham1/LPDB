=head1 NAME

LPDB - Local Picture metadata in sqlite

=head1 SYNOPSIS

  use LPDB;
  my $lpdb = new LPDB( { } );	# key = value configuration hash
  $lpdb->create;		# or update schema
  $lpdb->update('.');		# update database from files and metadata
  $lpdb->disconnect;		# all done

=head1 DESCRIPTION

B<LPDB> stores local picture metadata in a local sqlite database whose
tables are described below.  Its primary application is L<lpgallery>,
a keyboard driven picture browser.  This module provides configuration
and access to the database object while deferring storage and
retrieval to L<LPDB::Filesystem>.

=cut

package LPDB;

use strict;
use warnings;
use Carp;
use DBI;
use LPDB::Schema;		# from dbicdump dbicdump.conf
use LPDB::Filesystem;
use LPDB::VFS;
use Time::HiRes qw(gettimeofday tv_interval); # for profiling
use Data::Dumper;

my $conf = {		       # override any keys in first arg to new
    dbfile	=> '.lpdb.db',
    thumbfile	=> '.lpdb-thumb.db',
    reject	=> '\.import',	# pattern of files/dirs to reject
    regex	=> '(?i)\.(jpe?g|png|mp4|mov)$', # patterns to include
    # ext		=> [ qw/jpg png mp4/ ],	# if defined replaces regex
    update	=> sub {},  # callback after each directory is scanned
    debug	=> 0,	    # diagnostics to STDERR
    filter	=> {},	    # filters
    sqltrace	=> 0,	    # SQL to STDERR from DBIx::Class::Storage
    # editpath	=> 0,	# optional sub to return modified virtual path
    minpixels => 320 * 320 + 1,	# reject icons/thumbnails smaller than this
};

sub new {
    my($class, $hash) = @_;
    my $self = {};

    if (!$hash or ref $hash and $hash->{autoconfigure}) {
	# configuration files: last option setting wins
	for ("$ENV{HOME}/.lpdb.pl", "./.lpdb.pl", @ARGV) {
	    if (-f $_) {
		#	s{^(\w+)}{./$1};
		warn "using config $_\n";
		my $tmp = require $_ or die "error in $_: $!";
		map { $hash->{$_} = $tmp->{$_} } keys %$tmp;
	    } else {
		warn "no config at $_, skipping\n";
	    }
	}
    }
    if (ref $hash) {	      # switch to caller's conf or my defaults
	while (my($k, $v) = each %$conf) {
	    $hash->{$k} = $v unless $hash->{$k};
	}
	$conf = $hash;
    }
    if ($conf->{ext}) {		# supported filename extensions
	my $ext = join '|', @{$conf->{ext}};
	my $regex = "(?i)\\.($ext)\$";
	# warn $regex;
	$conf->{regex} = $regex;
    }
    # warn "self=$self, conf=$conf, reject=$conf->{reject}";
    # warn "reject: ", $self->conf('reject');

    $ENV{DBIC_TRACE} = $conf->{sqltrace} || 0;

    $self->{conf} = $conf;
    $conf->{dbfile} or
	carp "{dbfile} required" and return undef;

    # don't accidentally recurse: create database only with confirmation
    my $create = -f $conf->{dbfile} && -s _ ? 0 : 1;
    if ($create and !$conf->{create}) {
	die "bailing out, $conf->{dbfile} not found here!\n",
	    qq'use "lpdb --create" to create this picture database\n';
    }
    my $dbh = DBI->connect("dbi:SQLite:dbname=$conf->{dbfile}",  "", "",
			   { RaiseError => 1, AutoCommit => 1,
			     # DBIx::Class::Storage::DBI::SQLite(3pm):
			     on_connect_call => 'use_foreign_keys',
			     sqlite_unicode => 1,
			   })
	or die $DBI::errstr;
    # Default is no enforcement, and must be set per connection:
    $dbh->do('PRAGMA foreign_keys = ON;');
    # WAL lets writers not block readers and is faster at writing:
    $dbh->do('PRAGMA journal_mode = WAL;'); # or DELETE or TRUNCATE
    $self->{dbh} = $dbh;

    $conf->{thumbfile} or
    	carp "{thumbfile} required" and return undef;
    my $tdbh = DBI->connect("dbi:SQLite:dbname=$conf->{thumbfile}",  "", "",
    			    { RaiseError => 1, AutoCommit => 1,
    			      # DBIx::Class::Storage::DBI::SQLite(3pm):
    			      on_connect_call => 'use_foreign_keys',
    			    })
    	or die $DBI::errstr;
    # WAL lets writers not block readers and is faster at writing:
    $tdbh->do('PRAGMA journal_mode = WAL;'); # or DELETE or TRUNCATE
    $self->{tdbh} = $tdbh;

    bless $self, $class;
    $self->{schema} = $self->schema;
    $self->{tchema} = $self->tschema;
    $self->{vfs} = new LPDB::VFS($self);

    $self->{mtime} = 0;	# modify time of dbfile, for detecting updates
    $self->{sofar} = 0;	# hack!!! for picasagallery, fix this...
    return $self;
}

sub conf {	     # return whole config, or key, or set key's value
    my($self, $key, $value) = @_;
    if (defined $value) {
	$key eq 'sqltrace'
	    and $ENV{DBIC_TRACE} = $value;
	return $self->{conf}{$key} = $value;
    } elsif ($key) {
	return $self->{conf}{$key} || undef;
    }
    return $self->{conf};	# whole configuration hash
}

sub dbh { return $_[0]->{dbh}; }
sub tdbh { return $_[0]->{tdbh}; }

sub disconnect {
    my $self = shift;
    # my $dbh = $self->dbh;
    # print all currently cached prepared statements
#    print "cache>>>$_<<<\n" for keys %{$dbh->{CachedKids}};
    $self->dbh->do('PRAGMA optimize;');
    $self->dbh->disconnect;
    $self->tdbh->do('PRAGMA optimize;');
    $self->tdbh->disconnect;
}

sub schema {
    my $self = shift;
    $self->{schema} or $self->{schema} = LPDB::Schema->connect(
	sub { $self->dbh });
    return $self->{schema};
}
sub tschema {
    my $self = shift;
    $self->{tschema} or $self->{tschema} = LPDB::Schema->connect(
	sub { $self->tdbh });
    return $self->{tschema};
}

sub namevalue {			# key / value store
    my($self, $name, $value) = @_;
    defined $name or return;
    my $schema = $self->schema;
    my $row;
    if (defined $value) {
	$row = $schema->resultset('NameValue')->find_or_create(
	    { name => $name });
	$row->value($value);
	$row->update;
    }
    $row or $row = $schema->resultset('NameValue')->find(
	{ name => $name });
    return $row ? $row->value : undef;
}

1;				# LPDB.pm

__END__

=head1 DATABASE FILES and their TABLES

Picture metadata is stored in one file (C<.lpdb.db> by default) and
picture thumbnails in another (C<.lpdb-thumb.db>).  These filenames
are configurable at creation.  These files can be viewed by C<sqlite3>
or used by any compatible programming language.  LPDB accesses the
database via L<DBIx::Class> whose L<dbicdump> maintains the schema
documentation linked below.

The tables are defined by SQL in C<lib/LPDB/*.sql>.  Any times stored
are in seconds since the unix epoch of 1970.  The table content and
purpose are as follows:

=over

=item Directories, see L<LPDB::Schema::Result::Directory>

Each directory that holds one or more pictures on disk is recorded.
By default, L<lpgallery> keeps pictures grouped together in these
B<"galleries"> of pictures, even when viewing a larger list by other
metadata.  Each entry has a base name and a parent reference to record
the whole physical directory tree.  Also recorded is the begin and end
time of the pictures of the directory.

If all pictures are stored in only one directory, then there is just
one gallery.  It might be better to organize photos into separate
directories per day or month or per place or event.  Photographers may
have a directory per location or per client.

=item Pictures, see L<LPDB::Schema::Result::Picture>

Each row represents a single picture or video file.  Some metadata
from the file is recorded here such as image size and time.  Duration
is seconds of runtime for videos or NULL for still images.

=item Paths, see L<LPDB::Schema::Result::Path>

Paths enables L<LPDB::VFS>, a virtual file system of alterative useful
ways to navigate the metadata like time, people, captions, tags, stars
and so on.  This is similar to B<Directories> above except that these
paths don't exist on disk.  Pictures can be in many virtual paths, see
the next table.

=item PicturePath, see L<LPDB::Schema::Result::PicturePath>

This joins many B<Pictures> to many B<Paths>, placing images in
several logical places in the tree based on their metadata.  All
pictures will be listed in the original location on disk and in the
timelines.  Other locations depend on metadata of the picture.

=item Tags, see L<LPDB::Schema::Result::Tag>

Words of EXIF keywords or subject are stored here.

=item PictureTag, see L<LPDB::Schema::Result::PictureTag>

This joins many B<Tags> to many B<Pictures>

=item Contacts, see L<LPDB::Schema::Result::Contact>

Picasa or F<.names.txt> people in B<Pictures> are stored here.  They
can optionally have birthdays from F<.birthdays.txt>, see
L<lpgallery>.

=item Faces, see L<LPDB::Schema::Result::Face>

This joins many B<Contcts> to B<Pictures>.  Face rectangles from
Picasa are also stored.  A file_id of 0 instead comes from
F<.names.txt> as the name applies to all files of the dir_id.

=item Albums, see L<LPDB::Schema::Result::Album>

Picasa album of pictures.

=item PictureAlbum, see L<LPDB::Schema::Result::PictureAlbum>

This joins many B<Albums> to many B<Pictures>


!!!!!!!!!!!!!!TODO!!!!!!!!!!!!!!

=back

=head1 SEE ALSO

L<LPDB::Filesystem>, L<lpgallery>, L<DBIx::Class>

=head1 AUTHOR

Timothy D Witham <twitham@sbcglobal.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2013-2024 Timothy D Witham.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
