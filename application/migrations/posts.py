import os
import string
from datetime import datetime
from yaml import load
from migrations.db import Post, session

posts = os.listdir('migrations/posts/yaml')
for post in posts:
    with open(os.path.join('migrations/posts/yaml', post)) as p:
        yaml_obj = load(p)

        tag = string.rstrip(post, '.yml')
        date = datetime(**yaml_obj.get('date'))

        with open(os.path.join('migrations/posts/html', yaml_obj.get('post')), 'r') as f:
            post_content = f.read()
            if session.query(Post).filter(Post.tag == tag).count():
                session.execute(Post.__table__.update().where(Post.tag == tag), {'post': post_content})
            else:
                session.add(Post(tag=tag, title=yaml_obj.get('title'), date=date, gist=yaml_obj.get('gist'), post=post_content))

session.commit()
