import os
import string
from datetime import datetime
from logging import FileHandler

from yaml import load
from flask import Flask, render_template, send_file, url_for
from flask.ext.sqlalchemy import SQLAlchemy


app = Flask(__name__, static_folder='static')
handler = FileHandler('/var/log/flask.log')
app.logging.addHandler(handler)

pg_user = os.getenv('POSTGRES_USER', 'local')
pg_password = os.getenv('POSTGRES_PASSWORD', 'local')
db_uri = 'postgresql://{pg_user}:{pg_password}@postgres:5432/blog'.format(pg_user=pg_user, pg_password=pg_password)
app.config['SQLALCHEMY_DATABASE_URI'] = db_uri
db = SQLAlchemy(app)


class Post(db.Model):
    __tablename__ = 'posts'
    tag = db.Column(db.String, primary_key=True)
    title = db.Column(db.String)
    date = db.Column(db.DateTime)
    gist = db.Column(db.String)
    post = db.Column(db.String)

    def __init__(self, tag, title, date, gist, post):
        self.tag = tag
        self.title = string.capwords(title)
        self.date = date
        self.gist = gist
        self.post = post

    def __repr__(self):
        return '<Post %r>' % self.title


@app.route('/')
def index():
    return render_template('base.html', post=Post.query.order_by(Post.date.desc()).first())


@app.route('/about')
def about():
    return render_template('about.html')


@app.route('/posts')
def posts():
    return render_template('posts.html', posts=Post.query.order_by(Post.date.desc()))


@app.route('/posts/<post_id>')
def post(post_id):
    return render_template('base.html', post=Post.query.filter(Post.tag == post_id).one())


@app.route('/favicon.ico')
def favicon():
    return send_file('static/img/favicon.ico')


@app.errorhandler(Exception)
def handle_exception(e):
    app.logger.exception(e)
    return render_template('error.html')
