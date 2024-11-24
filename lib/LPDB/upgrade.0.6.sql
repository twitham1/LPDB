-- if upgrading from version < 0.6, you must run this:

-- sqlite3 .lpdb.db < upgrade.0.6,sql

-- table columns changed, was not used < 0.6, will be recreated
DROP TABLE IF EXISTS Contacts;
DROP TABLE IF EXISTS Faces;
DROP TABLE IF EXISTS Albums;

------ added in 0.6 for quicker sorting
ALTER TABLE Paths ADD COLUMN files INTEGER;
ALTER TABLE Paths ADD COLUMN beg   INTEGER;
ALTER TABLE Paths ADD COLUMN mid   INTEGER;
ALTER TABLE Paths ADD COLUMN end   INTEGER;
ALTER TABLE Paths ADD COLUMN bytes INTEGER;
ALTER TABLE Paths ADD COLUMN stars INTEGER;
ALTER TABLE Paths ADD COLUMN duration REAL;
