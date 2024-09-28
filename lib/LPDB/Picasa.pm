package LPDB::Picasa;

=head1 NAME

LPDB::Picasa - understand .picasa.ini files for LPDB

=cut

use strict;
use warnings;
use File::Basename;
# use Date::Parse;
# use POSIX qw/strftime/;
use LPDB::Schema;
use LPDB::Filesystem;
use base 'Exporter::Tiny';
our @EXPORT = qw(ini_read ini_updatedb);

# return given .picasa.ini file as a hash
sub ini_read {
    my($file) = @_;
    my $data = {};
    my $fh;
    return $data unless open $fh, $file;
    my $section = '';
    my($name, $dir) = fileparse $file;
    $data->{dir} = $dir;
    while (<$fh>) {
	chomp;
	s/\r*\n*$//;
	s/\&\#(\d{3});/sprintf "%c", oct($1)/eg; # will this corrupt if we write it out later?
	if (/^\[([^\]]+)\]/) {
	    $section = $1;
	} elsif (my($k, $v) = split '=', $_, 2) {
	    $data->{$section}{$k} = $v;
	}
    }
    close $fh or warn $!;
    return $data;
}

# update given ini_read hash into LPDB
sub ini_updatedb {
    my($self, $ini) = @_;
    my $dir = $ini->{dir};
    $dir =~ m@/$@ or return;
    my $schema = $self->schema;
    my $id = LPDB::Filesystem::_savedirs($dir); # hack!!! cached dir id
    print "in $dir = $id is following:\n";
    for my $k (keys %$ini) {
	my $this = $ini->{$k};
	if ($k =~ /^Picasa/) {
	    for my $id (keys %{$this}) {
		print "$k\t{$id}{$this->{$id}}\n";
	    }
	} elsif ($k =~ /^Contacts2/) {
	    for my $id (keys %{$this}) {
		my($name, $email) = split ';', $this->{$id};
		my $obj = $schema->resultset('Contact')->find_or_new(
		    { hexid => $id } );
		if ($obj->in_storage) { # last one wins?
		    my $tmp = $obj->email;
		    $obj->email($email);
		    $tmp eq $email or warn "$dir: $tmp -> $email";
		    $tmp = $obj->name;
		    $obj->name($name);
		    $tmp eq $name or warn "$dir: $tmp -> $name";
		} else {
		    $obj->hexid($id);
		    $obj->name($name);
		    $obj->email($email);
		    $obj->insert;
		}
	    }
	} elsif ($k =~ /^\.album:(\w+)$/) {
	    print qq'{album}{$1} = 1;\n';
	    for my $id (keys %{$this}) {
		print "$k\t{$id}{$this->{$id}}\n";
	    }
	    # $pic->{album}{$1} =
	    # 	&_merge(undef, $pic->{album}{$1}, $this->);
	} elsif ($k eq 'dir') {
	    next;
	} elsif (my $row = $schema->resultset('Picture')->find(
		     { dir_id => $id,
		       basename => $k })) { # image
	    for my $id (keys %{$this}) {
		print "$k\t{$id}{$this->{$id}}\n";
	    }
	    print "\tsetting star in $dir/$k\n";
	    $row->stars($this->{star} && $this->{star} eq 'yes' ? 1 : 0);
	    $row->is_changed
		? $row->update
		: $row->discard_changes;
	} elsif (-f "$dir$k") {	# image not in database?!
	    print "WHY IS $dir$k not in DB?!!!!!!!!!!!!!\n";
	    for my $id (keys %{$this}) {
		print "$k\t{$id}{$this->{$id}}\n";
	    }
	} else {
	    print "[$k] ignored\n";
	}
    }
}

1;				# LPDB::Picasa.pm
