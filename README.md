austburn.me
-----------

Welcome to my [personal blog's](https://austburn.me) repository.

# Up and Running

## Requirements

* `tfenv`
* `docker`

## Deploy Container

After merging, run `make tf_apply` and when prompted for the `git_revision`, paste the master hash. At this point, `terraform` notifies ECS there is a new task definition.
