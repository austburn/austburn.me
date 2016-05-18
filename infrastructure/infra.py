from logging import FileHandler
from git import Repo
from docker import Client
from flask import Flask, request


app = Flask(__name__)
handler = FileHandler('/var/log/infra.log')
app.logger.addHandler(handler)


@app.route('/post')
def post():
    json_body = request.get_json()
    app.logger.info(json_body)
    return 200

# Repo.clone_from('git@github.com:austburn/austburn.me.git', '/home/austin/austburn.me')
# cli = Client(base_url='unix://var/run/docker.sock')

# with f as open('/home/austin/austburn.me/docker/app.docker'):
#     try:
#         response = [
#             line for line in cli.build(
#                 fileobj=f, path='/home/austin/austburn.me', tag='austburn.app'
#             )
#         ]
#     except Exception:
#         # ah
