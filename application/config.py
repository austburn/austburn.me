import os


pg_user = os.getenv('POSTGRES_USER', 'local')
pg_password = os.getenv('POSTGRES_PASSWORD', 'local')
DB_URI = 'postgresql://{pg_user}:{pg_password}@postgres:5432/blog'.format(pg_user=pg_user, pg_password=pg_password)
