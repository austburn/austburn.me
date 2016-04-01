import os
import string
from datetime import datetime

from yaml import load
from sqlalchemy import MetaData, create_engine, Table
from sqlalchemy.schema import Column
from sqlalchemy.types import String, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import OperationalError, IntegrityError


pg_user = os.getenv('POSTGRES_USER', 'local')
pg_password = os.getenv('POSTGRES_PASSWORD', 'local')
db_name = 'blog'
db_connection_uri = 'postgresql://{pg_user}:{pg_password}@postgres:5432/{db_name}'.format(
    pg_user=pg_user,
    pg_password=pg_password,
    db_name=db_name
)

engine = create_engine(db_connection_uri)

try:
    conn = engine.connect()
except OperationalError:
    create_db_engine = create_engine(db_connection_uri[0:db_connection_uri.rindex('/')])
    create_db_conn = create_db_engine.connect()
    create_db_conn.connection.connection.set_isolation_level(0)
    create_db_conn.execute('create database {db_name} with owner = {pg_user}'.format(db_name=db_name, pg_user=pg_user))
    create_db_conn.connection.connection.set_isolation_level(1)
    create_db_conn.close()
finally:
    conn = engine.connect()

metadata = MetaData(bind=engine)
posts_table = Table('posts', metadata,
    Column('tag', String, primary_key=True),
    Column('title', String),
    Column('date', DateTime),
    Column('gist', String),
    Column('post', String))

metadata.create_all(engine)

insert = posts_table.insert()
posts = os.listdir('/migrations/posts/yaml')
for post in posts:
    with open(os.path.join('/migrations/posts/yaml', post)) as p:
        yaml_obj = load(p)

        tag = string.rstrip(post, '.yml')

        date_obj = yaml_obj.get('date')
        date = datetime(date_obj.get('year'), date_obj.get('month'), date_obj.get('day'))
        title = yaml_obj.get('title')
        with open(os.path.join('/migrations/posts/html', yaml_obj.get('post')), 'r') as f:
            post_content = f.read()

        status = yaml_obj.get('status')
        if status == 'publish' or environment == 'dev':
            try:
                conn.execute(insert, tag=tag, title=title, date=date, gist=yaml_obj.get('gist'), post=post_content)
            except IntegrityError:
                pass
            else:
                print('Post {} added!'.format(tag))

conn.close()
exit(0)
