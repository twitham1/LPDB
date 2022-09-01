# LPDB - Local Picture DataBase - picture metadata in sqlite

LPDB is a local picture database.  This has nothing to do with web
galleries, as it sees pictures only in the local fileystem.  Metadata
of these pictures is stored in a local database so that we can
organize them in various ways and navigate them quickly.

# bin/lpgallery

lpgallery is a keyboard (remote) controlled local picture browser
similiar to mythgallery of mythtv for viewing local pictures on a big
screen from the comfort of your couch.  On Linux I tune its look with
the following:

	> xrdb -merge ./.Xdefaults # where ./.Xdefaults is:
	Prima.Color: white
	Prima.Back: black
	Prima.HiliteBackColor: gray33
	Prima.Font: Helvetica-20

# Status / TODO

This is "works-for-me" ware under development.  It should someday do
everything that picasagallery did (see below) and more, only better
and in a smaller memory footprint.

# Dependencies

You will need to already have or install at least:

* Perl (see https://perl.org)
* Prima from CPAN ("cpan install Prima" or https://cpan.org)
* DBIx::Class from CPAN
* Image::ExifTool from CPAN (https://exiftool.org)
* SQLite and its sqlite3 command (https://sqlite.org)
* optional: Dist::Zilla / "dzil" for building the package

# INSTALL

This should work to install the code

```
  dzil build	# or grab a pre-made build
  cd <build>
  perl Makefile.PL
  make
  sudo make install
```

# USAGE

Now cd to the root of a directory with some pictures, ideally managed
by Picasa (but optional), and run lpgallery.  Answer yes to the prompt
and it should begin caching picture metadata and present the browser
after a brief wait.  See lpgallery(1) manual page for more.

# See also

https://github.com/twitham1/picasagallery is the original proof of
concept that also understands .picasa.ini files to organize by Stars,
Albums and Faces.  These features will be added to LPDB/lpgallery
eventually.
