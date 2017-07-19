import os
from datetime import date
from yaml import load


class PostManager(object):
    def __init__(self):
        self.posts = []
        self.metadata_directory = os.path.join(os.getcwd(), 'posts/metadata')
        self.post_directory = os.path.join(os.getcwd(), 'posts/html')
        self.post_metadata = os.listdir(self.metadata_directory)

        self.posts = self.get_posts()

    def pull_md_from_yaml(self, path):
        with open(os.path.join(self.metadata_directory, path)) as md_file:
            yaml_obj = load(md_file)
            content = open(os.path.join(self.post_directory, yaml_obj['post']))
            yaml_obj.update({
                'date_obj': date(**yaml_obj['date']),
                'tag': path.split('.')[0],
                'post': content.read()
            })
            content.close()
            return yaml_obj

    def get_posts(self):
        if self.posts:
            return self.posts
        else:
            self.posts = map(self.pull_md_from_yaml, self.post_metadata)
            return self.posts

    def get_post_by_tag(self, tag):
        found_posts = filter(lambda p: p['tag'] == tag, self.posts)
        if found_posts:
            return found_posts[0]
        else:
            return None

    def get_posts_by_date(self):
        return sorted(self.posts, key=lambda p: p['date_obj'], reverse=True)
