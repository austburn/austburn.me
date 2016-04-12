import os


PG_USER = os.getenv('POSTGRES_USER', 'local')
PG_PASSWORD = os.getenv('POSTGRES_PASSWORD', 'local')
DB_URI = 'postgresql://{pg_user}:{pg_password}@postgres:5432/blog'.format(pg_user=PG_USER, pg_password=PG_PASSWORD)
