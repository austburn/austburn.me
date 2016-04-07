from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy import MetaData, create_engine, Column, String, DateTime

from config import DB_URI, pg_user


engine = create_engine(DB_URI)

try:
    conn = engine.connect()
except OperationalError:
    create_db_engine = create_engine(DB_URI[0:DB_URI.rindex('/')])
    create_db_conn = create_db_engine.connect()
    create_db_conn.connection.connection.set_isolation_level(0)
    create_db_conn.execute('create database blog with owner = {pg_user}'.format(pg_user=pg_user))
    create_db_conn.connection.connection.set_isolation_level(1)
    create_db_conn.close()
finally:
    conn = engine.connect()

metadata = MetaData(bind=engine)
Base = declarative_base(metadata=metadata)
class Post(Base):
    __tablename__ = 'posts'

    tag = Column(String, primary_key=True)
    title = Column(String)
    date = Column(DateTime)
    gist = Column(String)
    post = Column(String)

Base.metadata.create_all(engine)
Session = sessionmaker(bind=engine)
session = Session()
