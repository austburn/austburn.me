from logging import FileHandler
from flask import Flask, render_template, send_file, request, make_response
from cStringIO import StringIO
import gzip

from migrations.db import Post, session

app = Flask(__name__, static_folder='static')
handler = FileHandler('/var/log/flask.log')
app.logger.addHandler(handler)


@app.after_request
def after_request(response):
    accepted_encodings = request.headers.get('Accept-Encoding', '')
    if 'gzip' in accepted_encodings.lower():
        response.direct_passthrough = False
        gzip_buffer = StringIO()
        gzip_file = gzip.GzipFile(mode='wb', fileobj=gzip_buffer)
        gzip_file.write(response.data)
        gzip_file.close()

        compressed_response = make_response(gzip_buffer.getvalue())
        compressed_response.headers['Content-Encoding'] = 'gzip'
        return compressed_response

    return response


@app.route('/')
def index():
    return render_template(
        'base.html',
        post=session.query(Post).order_by(Post.date.desc()).first(),
        title='@austburn'
    )


@app.route('/about')
def about():
    return render_template(
        'about.html',
        title='@austburn - About Me'
    )


@app.route('/posts')
def posts():
    return render_template(
        'posts.html',
        posts=session.query(Post).order_by(Post.date.desc()),
        title='Posts'
    )


@app.route('/posts/<post_id>')
def post(post_id):
    post = session.query(Post).filter(Post.tag == post_id).one()
    return render_template(
        'base.html',
        post=post,
        title=post.title
    )


@app.route('/favicon.ico')
def favicon():
    return send_file('static/img/favicon.ico')


@app.errorhandler(Exception)
def handle_exception(e):
    app.logger.exception(e)
    return render_template('error.html')
