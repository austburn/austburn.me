from logging import FileHandler
from git import Repo
from docker import Client
from flask import Flask, request


app = Flask(__name__)
handler = FileHandler('/var/log/infra.log')
app.logger.addHandler(handler)


@app.route('/post', methods=['POST'])
def post():
    json_body = request.get_json()
    Repo.clone_from('git@github.com:austburn/austburn.me.git', '/data/')
    cli = Client(base_url='unix://var/run/docker.sock')

    with f as open('/data/docker/app.docker'):
        try:
            response = [
                line for line in cli.build(
                    fileobj=f, path='/data/', tag='austburn.app'
                )
            ]
        except Exception as e:
            app.logger.exception(e)

    app.logger.info(json_body)

    return '', 200

