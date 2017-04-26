import os


PG_USER = os.getenv('POSTGRES_USER', 'local')
PG_PASSWORD = os.getenv('POSTGRES_PASSWORD', 'local')
PG_ENDPOINT = os.getenv('POSTGRES_ENDPOINT', 'postgres')
DB_URI = 'postgresql://{pg_user}:{pg_password}@{pg_endpoint}:5432/blog'.format(
    pg_user=PG_USER,
    pg_password=PG_PASSWORD,
    pg_endpoint=PG_ENDPOINT
)
