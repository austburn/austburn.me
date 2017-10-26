+++
author = "Austin Burnett"
categories = ["operations", "cicd", "docker", "ansible"]
date = "2016-04-12"
description = "I decided to apply operations to my blog, here is the story."
title = "Blog Ops'd"
type = "post"

+++

For some time now, I have wanted to apply configuration management to my blog. It's been about a year since I first stood up my blog. I began with a cloud server, Nginx, and a static HTML page. From there, I graduated to a Python application with Postgres. The next obvious choice was to shim everything into Docker containers (yes, I was affected by the Great Container Obsession of 2014-15). During those transitions, I used scripts and text files to make things somewhat repeatable, but they still required my memory and manual intervention - both limited and error prone.


While the changes I have made have not resulted in any large amounts of downtime, I have had to rush to make hot fixes - frantically debugging, grepping, and trying to make sense of the situation. Everytime I wanted to add a post or even make a cosmetic change, it was done with caution. Will this break anything? What if my server dies? Will I be able to stand this back up? How much downtime would it cause me? Even though this is a blog that receives a little amount of traffic, it's _my_ blog - to those on the Interwebs, it serves as a direct representation of myself.

The obvious answer was configuration management. Getting there is another story - that's what I'd like to share here. In this post I'll discuss the problems I had and how I remedied them. We'll start by talking about how you simplify what you are managing, how you can reliably configure your application, and how to can maintain it.

## Simplify

Configuration management is largely about consistency - but we're not there, yet. Before you can leverage configuration management - do you have a workflow that works?

I didn't.

I had a hundred line text file that contained instructions for how to get my blog running on a cloud server from scratch along with a handful of scripts that really just helped me run my application, not provision my server. I decline to comment on whether or not that text file was even useful. (It wasn't.)

As a first step, I took a look at what I had and where I wanted to be.

Where I was:

* My Docker container was bloated.
* My dev flow was not extremely useful.
* Had my server died, I'd be at square one.

Where I wanted to be:

* Simple Docker workflow.
* Debugging capabilities.
* Clear division of responbility.

Here is my Docker experience summed up into two memes [I have interchanged which one comes first multiple times](
![](https://bookloversunite.files.wordpress.com/2014/10/do-all-the-things.jpeg)
![](https://i.imgur.com/V8KfCpj.jpg)

What I mean is that my experience with Docker was initially immature. I wasn't really sure what it was best used for, so I used it for just about everything. As I continually made changes to my blog, it seemed as though I was also adding more complexity to my container. As a result, I had 6 Docker images - 5 of which were application based while the latter was my database. The 5 application images consisted of:

* **base**: install common dependencies (Python, pip, etc.)
* **Nginx**
  * **dev**: Run on port 80, don't worry about certs, redirects, etc.
  * **prod**: Run on port 80 and 443, worry about certs, redirects, etc.


* **Application**
  * **dev**: Build from dev Nginx image
  * **prod**: Build from prod Nginx image

The problem I had here was: development was slow and not very helpful. I was always indirectly running my Python application via Nginx and uWSGI - both server processes that close `stdin` and make debugging impossible. If there was a problem with the application itself, I had to run the application outside the container. Wait... my database is inside a container, too... And I need that to run my application... Exactly. My dev flow was flawed. As a result, I only ever had so much faith in the changes I made. To be confident in the changes you make, you need a proper development flow.

That is why I headered this section `Simplify`. The first step to configuration management is actually management. Can your application itself be managed? Does this make sense? Can I explain how it all works to a [rubber duck](http://www.rubberduckdebugging.com/)?

In my eyes, the source of my problems were largely my Docker images/containers. Ultimately, I decided to yank Nginx out of the container. Can you have Nginx and your application running inside a container? Of course. I decided to adhere more closely to the [Unix philosophy](http://www.catb.org/esr/writings/taoup/html/ch01s06.html) and have my container do one thing and do it well - my Python application. This accomplished a few things:

* Faster container builds
* Less images!
* `pdb` - [The Python Debugger](https://docs.python.org/2/library/pdb.html) which I adore/abuse
* Reduced responsibilities for the container; reduced cognitive load
* More portable container - it's just my Python application and dependencies - it can be run the exact same way locally as on my server


At this point, I felt comfortable moving forward. Now, I just need to get Docker, Nginx, and my image to a server.

## Ansible

As I began to weigh my options of which configuration management solution to choose, I picked Ansible mainly out of interest. At [Rackspace](https://mycloud.rackspace.com) we use [LittleChef](https://github.com/tobami/littlechef). Like Ansible, LittleChef uses a push model ("Hey, I have some changes for you, here they are.") for infrastructure changes. While using something like [Chef Server](https://downloads.chef.io/chef-server/] would expose me to a pull model ("Hey boss, any changes you need me to make?"), I figured it might be a little overkill and LittleChef has already introduced me to some of the Chef philosophies. I had also just taken a class at Rackspace on Ansible and felt ready to try to apply the skills I had learned.

### First Impressions

**This isn't Python**. Well... Kinda. With LittleChef I'm used to finding a community cookbook, noticing that it solves 95% of usecases, writing a little Ruby for that 5% we need to tweak, and voil&agrave;. Starting out with Ansible, I haven't really looked at Galaxy or developing modules/plugins, but it seems there's not a quick and easy way to extend playbooks.

**Syntax.** Tailing on the above statement... Still not sold on YAML. Tasks being strings with key-value pairs takes a little getting used to.

**Fast.** I don't mean in the time that it takes to make changes on a remote host, but rather the time it takes to get started and make changes. Getting Docker and Nginx set up was pretty straightforward. Once you grasp the Ansible syntax, it becomes intuitive to take what you know about a service's installation and configuration and translate that to a playbook (maybe this counteracts my previous point).

**Docs.** The Ansible documentation is great. Their guide is fantastic and includes all sorts of best practices that make keeping track of all your resources manageable. Additionally, I found the `ansible-doc` tool very helpful as a quick reference.

### Vault

Pretty much exactly like encrypted data bags in Chef, Vault is Ansible's offering to encrypt your sensitive data. It requires a password or secret file and a target file to encrypt. I followed the [documentation](http://docs.ansible.com/ansible/playbooks_vault.html#running-a-playbook-with-vault] on how to get started with Vault and used [this](http://docs.ansible.com/ansible/playbooks_best_practices.html#best-practices-for-variables-and-vaults] guide on best practices to setup my variables correctly in conjunction with Vault. I used Vault to encrypt my SSL cert/key and my Postgres credentials.

Once I had cleaned up my application, the next step was to get everything into version control. By encrypting the sensitive bits, I can confidently store everything in version control aside from my secret file containing my Vault password. This makes development possible from pretty much anywhere provided you store your secret file in a safe location.

## Version Control

Getting started with blogging has been a slowly evolving adventure. Along with work, constantly trying to learn something new, and trying to discover what I want this blog to become, making updates has ultimately become an infrequent and adaptive process. Each new blog post seems to coincide with spending time remembering how everything works and how I can make that process better. Fixing things resulted in more time spent understanding. I had no [good] way of tracking the changes I had made and what problems my new changes might cause.

Version control remedies this problem and provides ways to track and visualize the work you do. Not only does it provide tooling for maintaining, it provides evidence for any event that occurs. Whether the event is positive or negative - you have a track record to begin to understand the cause.

While version control for a project which you're the lone contributor of may seem unnecessary, I find it only beneficial. You're able to track changes, scope changes into branches, and provide commentary to the changes you make.

## Next Steps

Configuration management is a never ending battle. There will always be new tools, new ideas, and general changes that you make to your application that will force you to question how well your current solution works.

### Docker Registry

I'll probably try to figure out a way to store my images somewhere. Currently, I have to checkout my entire Git repo to my node, it would be nice to just have to pull an image instead. Here, I could start tagging images as well - if I make a breaking change, I can revert to the previous image.

### Git Hooks

Currently, I am still in charge of deploying any and all changes. If I go down the path of having a Docker registry, it'd be ideal to have merging a pull request trigger an image build and subsequently Ansible my node. I think I could accomplish this via CircleCI. Ultimately, I'll try to find something free.

### Testing

I have constantly thought about this issue. How do I _really_ know my changes are good? I would like to find a way to do this without having a test node. Essentially I give everything the eye test locally, but on the node itself is a different story. I think I can tie in some sort of check to my Ansible playbooks, but I'd have to look into this more. Basically, I need a way to safeguard myself from releasing a breaking change to my live site.

### Monitoring

Currently I monitor my application via Rackspace, but I would like to add some custom metrics to understand what kind of load my Python application is receiving and if I can be proactive about problems. Additionally, I plan to learn more about Google Analytics and how I can leverage their platform to gather more information about vistors. Monitoring is more of a research project than an actionable task. You have to figure out what questions you need answers to before really implementing anything.

## Conclusion

I hope this tale has provided you with some good information on why configuration management is important and how you can take steps to get there. I feel much more comfortable now with my blog, which I think will help me write more!
