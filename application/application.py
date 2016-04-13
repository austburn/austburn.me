from logging import FileHandler
from flask import Flask, render_template, send_file

from migrations.db import Post, session

app = Flask(__name__, static_folder='static')
handler = FileHandler('/var/log/flask.log')
app.logger.addHandler(handler)


@app.route('/')
def index():
    return render_template('base.html', post=session.query(Post).order_by(Post.date.desc()).first())


@app.route('/about')
def about():
    return render_template('about.html')


@app.route('/posts')
def posts():
    return render_template('posts.html', posts=session.query(Post).order_by(Post.date.desc()))


@app.route('/posts/<post_id>')
def post(post_id):
    return render_template('base.html', post=session.query(Post).filter(Post.tag == post_id).one())


@app.route('/favicon.ico')
def favicon():
    return send_file('static/img/favicon.ico')


@app.errorhandler(Exception)
def handle_exception(e):
    app.logger.exception(e)
    return render_template('error.html')
