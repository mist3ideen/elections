How to set up the database
==========================

Install postgresql 9.6 (9.5 or 10 should do too).

Run this as a PostgreSQL superuser (postgres is the default). Example:

    $ sudo -u postgres ./create.sh

It will create a database called "elections" with the tables and views needed and add some test data in there.

If you make some changes, there's a `./dump.sh` script that will dump all your changes and data into `elections.sql`.

The `run.sql` file has some sample commands you can run to see the results.


How to set up the UI
====================

Once the DB is set up, you can set up the UI for it.

Make sure you have python3 and PIP installed. Then:

    virtualenv -p python3 venv
    . venv/bin/activate
    pip install -r requirements.txt
    pip install -e .
    cp uielections/config.py .

Now, enter the credentials to your database in `./config.py` (make sure PostgreSQL accepts those in the hba file by running `psql -h 127.0.0.1 -U yourusername -W`)

Every time you want to run it, you have to do the following `export` command once in your shell, then run the next `python` command:

    export UIELECTIONS_CONFIG=`pwd`/config.py
    python -m uielections

You should see a message on the terminal that says the following:

    Running on http://127.0.0.1:5000/ (Press Ctrl+C to quit)
