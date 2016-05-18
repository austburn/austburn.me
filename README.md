austburn.me
-----------

Welcome to my [personal blog's](https://austburn.me) repository.

# Runbook

Here are some operational tasks for bootstrapping a node.

## Bootstrap

`ansible-playbook bootstrap.yml --limit node_name`
```
node_name ansible_user=root ansible_host=ip
```
Add SSH key to Github.

## Update

`ansible-playbook site.yml`
```
node_name ansible_user=austin ansible_host=ip
```
