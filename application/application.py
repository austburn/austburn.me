from logging import FileHandler
from flask import Flask, render_template, send_file, request
from cStringIO import StringIO
import gzip

from post_manager import PostManager

app = Flask(__name__, static_folder='static')
app.config.from_object('config')

post_manager = PostManager()

handler = FileHandler('/var/log/flask.log')
app.logger.addHandler(handler)


@app.after_request
def after_request(response):
    # http://flask.pocoo.org/snippets/122/
    accept_encoding = request.headers.get('Accept-Encoding', '')
    if 'gzip' not in accept_encoding.lower():
        return response

    response.direct_passthrough = False

    if (response.status_code < 200 or response.status_code >= 300 or 'Content-Encoding' in response.headers):
        return response

    gzip_buffer = StringIO()
    gzip_file = gzip.GzipFile(mode='wb',
                              fileobj=gzip_buffer)
    gzip_file.write(response.data)
    gzip_file.close()

    response.data = gzip_buffer.getvalue()
    response.headers['Content-Encoding'] = 'gzip'
    response.headers['Vary'] = 'Accept-Encoding'
    response.headers['Content-Length'] = len(response.data)

    return response


@app.route('/')
def index():
    return render_template(
        'base.html',
        post=post_manager.get_posts_by_date()[0],
        title='Austin Burnett - Blog'
    )


@app.route('/about')
def about():
    return render_template(
        'about.html',
        title='About Me'
    )


@app.route('/posts')
def posts():
    return render_template(
        'posts.html',
        posts=post_manager.get_posts_by_date(),
        title='Posts'
    )


@app.route('/posts/<tag>')
def post_by_tag(tag):
    post = post_manager.get_post_by_tag(tag)
    if not post:
        raise Exception('{} tag not found.'.format(tag))
    return render_template(
        'base.html',
        post=post,
        title=post['title']
    )


@app.route('/favicon.ico')
def favicon():
    return send_file('static/img/favicon.ico')


@app.route('/hash')
def hash():
    return app.config['GIT_HASH']


@app.errorhandler(Exception)
def handle_exception(e):
    app.logger.exception(e)
    return render_template('error.html')
