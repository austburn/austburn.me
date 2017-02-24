from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy import MetaData, create_engine, Column, String, DateTime

from config import DB_URI


engine = create_engine(DB_URI)
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
