-- if upgrading from version < 0.6, you must run this:

-- sqlite3 .lpdb.db < upgrade.0.6,sql

-- table columns changed, was not used < 0.6, will be recreated
DROP TABLE IF EXISTS Contacts;
DROP TABLE IF EXISTS Faces;
DROP TABLE IF EXISTS Albums;
