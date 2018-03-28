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

How to parse the real electoral lists data
======================================

You can view the finished (mostly clean) CSV files in `candidates/tabula-Lists2018_ocr_gray/`
Each CSV file corresponds to a page of the official document in `candidates/Lists2018.pdf`,
parsed with OCR and manually edited. If a list is split between two pages, the whole
list is included in the file of the page it started from.

If you need to generate it from scratch, to maybe get better results, or just
for the sake of it:

  1. Install tesseract and the arabic language pack (on Fedora, `dnf install tesseract tesseract-langpack-ara`) (tested with version `3.05.01-3.fc27.x86_64`)
  2. Install tabula (http://tabula.technology/) (tested with version `1.2.0`)
  3. Install pdfsandwich (http://www.tobias-elze.de/pdfsandwich/) (tested with version `0.1.6`)
  4. (optional) Install pdftohtml (on Fedora, `dnf install poppler-utils`), useful if the document contained raw text (i.e. OCR was not needed) (tested with version `0.57.0-8.fc27`)
  5. Run `/path/to/pdfsandwich -gray -lang ara ./candidates/Lists2018.pdf` to perform OCR on the whole PDF document (it may take some time)
  6. Run Tabula `java -Dfile.encoding=utf-8 -Xms256M -Xmx1024M -jar tabula.jar` and upload the transformed PDF document (`Lists2018_ocr.pdf`) and the template (`candidates/Lists2018.tabula-template.json`) and run tabula and export as `CSV` or `CSV zipped`
  7. Clean up the files (each row has the full info, lists are seperated by a blank line, etc.)
  8. After configuring the database and the UI, you can run `python import_realdata.py <path-to-directory-containing-csv-files>` and it will dump them to the database. (You may want to run `./fresh.sh` to clear **ALL** the existing data in the database first)

You can then use `./dump.sh` to dump it and use a diff tool like meld to use it
as a template for the UI. (use `meld elections.sql uielections/templates/simulation-templates/empty.sql.j2` and you take it from there)
