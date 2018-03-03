#!/usr/bin/env python3

from setuptools import setup, find_packages

setup(
    name='uielections',
    version='0.1',
    description='Frontend for the elections',

    packages=find_packages(),

    install_requires=[
        'flask',
        'Flask-SQLAlchemy',
        'Babel',
        'psycopg2',
        'SQLAlchemy',
        'SQLAlchemy-Utils',
        'click',
        'Jinja2',
        'isodate',
        'strict-rfc3339',
    ],

    author='Jad Kik',
    author_email='jadkik94@gmail.com',
    url=''
)
