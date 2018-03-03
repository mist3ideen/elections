SQLALCHEMY_TRACK_MODIFICATIONS = False
SQLALCHEMY_DATABASE_URI = 'postgresql://username:password@localhost:5432/elections'
SQLALCHEMY_ECHO = False

HASHIDS_MIN_LENGTH = 5
HASHIDS_SECRET_KEY = 'change this'
SECRET_KEY = b'change this'
HASHIDS_CANARY = 55
