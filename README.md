austburn.me
-----------

Welcome to my [personal blog's](https://austburn.me) repository.

# Up and Running

## Requirements

* `ansible`
* `docker`

## Galaxy

`ansible-galaxy install -r roles.txt -p roles`

# Runbook

Here are some operational tasks for bootstrapping a node.

## Bootstrap New Node

```
node_name ansible_user=root ansible_host=ip
```
`ansible-playbook bootstrap.yml --limit node_name`

Add SSH key to Github.

```
node_name ansible_user=austin ansible_host=ip
```

## Deploy Container

`make gr=<git_revision> deploy_test`

The git revision, last commit hash, and CIRCLE_SHA1 should all be the same.

General health of the test node can be determined by `curl https://austburn.me -H "X-Use-Test: true"`.

Assuming all is well:

`make gr=<git_revision> deploy_production`
