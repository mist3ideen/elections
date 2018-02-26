How to set up
=============

Install postgresql 9.6 (9.5 or 10 should do too).

Run this as a PostgreSQL superuser (postgres is the default). Example:

   $ sudo -u postgres ./create.sh

It will create a database called "elections" with the tables and views needed and add some test data in there.

If you make some changes, there's a `./dump.sh` script that will dump all your changes and data into `elections.sql`.

The `run.sql` file has some sample commands you can run to see the results.
