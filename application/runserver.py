import os
import string
from datetime import datetime
from logging import Logger

from yaml import load
from flask import Flask, render_template, send_file, url_for
from flask.ext.sqlalchemy import SQLAlchemy


app = Flask(__name__, static_folder='static')
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
    all_posts = Post.query.all()
    sort_by_date = lambda a, b: cmp(a.date, b.date)
    all_posts.sort(cmp=sort_by_date, reverse=True)

    return render_template('posts.html', posts=all_posts)


@app.route('/posts/<post_id>')
def post(post_id):
    try:
        return render_template('base.html', post=Post.query.filter(Post.tag == post_id).one())
    except Exception as e:
        return render_template('error.html')


@app.route('/favicon.ico')
def favicon():
    return send_file('static/img/favicon.ico')


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5050)
