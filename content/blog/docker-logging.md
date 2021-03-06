+++
author = "Austin Burnett"
categories = ["docker", "logging", "logspout", "logstash"]
date = "2016-07-06"
description = "Docker is a useful tool, but getting your logs while maintaining the container-host separation can be difficult."
title = "Portable Docker Logging"
type = "post"

+++

In the past couple years, the way we think about our infrastructure has undergone a makeover. Without a doubt, the biggest shift in operations and infrastructure has been towards containers. As a result, we've been forced to question the way we do infrastructure. Before containers, you're "deliverable" was the application itself. Your configuration management tools would provision your host to be able to run that application. With containers, you're "deliverable" is, well, the container. Your configuration management tools need to... install Docker, rkt, etc. This realization has fueled the container orchestration tools to challenge the way we think about hosts and what we expect from them. One of the more challenging problems my team has faced has been getting logging right, especially as you begin to look at container orchestration solutions, many of which don't grant access to the host. In this post I plan to talk about our journey to getting logging right (for us) and why many of the existing solutions didn't work for our use case.


Shifting to containers for our team has been an extended learning process. Operationally, we viewed containers as an opportunity to improve our processes and challenge ourselves as engineers. We also had just been assigned a new project, so we had some time to experiment and work out the kinks. Our first foray into Docker could best be summed up as, "Let's use Docker, but what the heck is all this Kubernetes/Swarm/Mesos business and why would we need it?" By this, I mean that our initial focus was on how to get our application into a Docker container and how do we get it from dev to production in a way that makes sense. We had a pipeline set up to build our container, ship it to [Quay](https://quay.io/), then use Chef to pull the correct container and start it... _what about the logs?_.

![](https://i.makeagif.com/media/5-05-2014/zAfH3e.gif)

## Making It Work

As I stated previously, we weren't initially invested in the nuances of containers and really just wanted to get things working. Inside our container, we were logging to files, just as we would had we been on the host. We use the [ELK stack](https://www.elastic.co/webinars/introduction-elk-stack) for all our logging needs. [Logstash](https://www.elastic.co/products/logstash) runs on every host and watches a set of files that eventually get indexed into our [Elasticsearch](https://www.elastic.co/products/elasticsearch) cluster.

We explored a few different options, one of which was putting Logstash inside the container. At the time, our container was constantly evolving and as a result, expanding. Installing Java and adding Logstash to our container was going to lengthen our build times and violate our separation of responsibilities. Additionally, we were still interested in some of the logs that existed on the host. This meant two instances of Logstash on those hosts. We decided that this was not an appropriate solution.

In interest of simplicity and moving forward, we decided to mount `/var/log` from our host into our container. This allowed us to write to log files in our container and have them available on the host. From a Logstash point of view, we had to add configuration to monitor these new files and that was about it. Maybe this wasn't the most glorious solution, but we have our application in a container and we're running in production, two of our foremost goals.

## Portability: Rethinking How We Log

Any team that runs containers long enough will really begin to question what they look for in a host. This is the question that many of the container orchestration tools are trying to answer. They tend to eliminate the need to think about hosts. They remove the need to think about the host so that your concerns boil down to which container is running and how many you need. While we're still only investigating container orchestration solutions, that host isolation is still desirable. So, if you're using the host machine, how can you lift yourself away from that dependency so that you can just have container(s) that run anywhere? **Answer:** moar containers! If you have responsibilities on the host that your container depends on and you want to maintain host isolation, you'll want to investigate how you can achieve those responsibilities inside additional containers.

### Logspout

[Logspout](https://github.com/gliderlabs/logspout) was our first attempt at solving our logging problem. It's a minimalist container that run on a host that takes logs from `stdout` of other running containers and allows you to route the logs somewhere. There are several modules available and even some third party modules, including one for [Logstash](https://github.com/looplab/logspout-logstash). Here's an example of how you might use Logspout:

```bash
# Window1

# Start up logspout host
$ docker run -d --name="logspout" \
    --volume=/var/run/docker.sock:/var/run/docker.sock \
    --publish=127.0.0.1:8000:80 \
    gliderlabs/logspout

# Switch to Window2...
$ curl http://127.0.0.1:8000/logs
             app|Hey! A log`</pre>
```
```bash
# Window2
# Start up our application container and produce a line on stdout
$ docker run --name app ubuntu /bin/bash -c "echo Hey! A log"
# Return to Window1...
```

Unfortunately, Logspout did not solve our problems. For one, `stdout` is the only stream for the logs to flow through. If you have more than one type of log coming from your container, which we did, you have to generate a Logstash configuration that handles this. One of Logstash's weaknesses is that it's conditional constructs are not extensive and often lead to multiple if-else statements with cryptic conditionals. Second, which is definitely preference based, is that you lose the phyiscal log file. In one regard, you don't have to worry about log rotation and retention, but you're really relying on your logging infrastructure to be highly available and reliable.

While Logspout didn't work for our particular use case, it works wonderfully if you have multiple instances of the same container running on the same host that you need to pull logs from. You have a consistent pattern and the logs are prepended by their container name. This makes you Logstash config simple and you'll be able to easily pull out the container name from the log letting you know from a monitoring perspective which container may be having a problem.

### Data Container with Logstash

After doing some research, we found a way to use Logstash as we had traditionally used it, but inside a container. We ended up using what Docker as [data volume containers](https://docs.docker.com/v1.10/engine/userguide/containers/dockervolumes/). To do so, we'd create a container running Logstash with a volume at `/var/log`. When running our application container, we'd have it use the volume from our Logstash container, the log directory. Here is (generally) how this would work:

```bash
# Window1
# Start up our log container
~ docker run --name logstash -v /var/log -it ubuntu /bin/bash
# Switch to Window2...
# Check that the log shows up
root@366320d88c4a:/# cat /var/log/test.txt
Hey! A log
```

```bash
# Window2
# Start up our application container and just dump a log
~ docker run --name app --volumes-from logstash \
    -it ubuntu /bin/bash -c "echo Hey! A log > /var/log/test.txt"
# Return to Window1...
```

As you can see, this alleviates the need for a host volume and having Logstash run on the host. This gave us the power to generate Logstash configuration that handles individual files. This grants you convenience in terms of easily tagging your log files and being able to `grok` fields from them later. In my experience, you should try to distinguish the differences between your log files as easily and cheapily as possible.

```
input {
  file {
    path => "/var/log/app.log"
    tags => ["app"]
  }
}
 input {
  file {
    path => "/var/log/server.log"
    tags => ["server"]
  }
}
 filter {
  if "app" in [tags] {
    # special app log stuff here
  }

  if "server" in [tags] {
    # special server log stuff here
  }
}
```

This pattern keeps your Logstash conditional structures to a minimum and very easy to understand. This is accomplished by tagging each stream of logs at the source. Without this, you normally have to detect patterns in logs in order to dictate what type of log you're looking at. This is especially true when you have a single stream of logs streaming from multiple sources.

It's important to note that multiple sources means multiples files on the "filesystem" (from the developer's point of view, these are in the container). This solution is not optimal if each host is to serve multiple instances of the same service and/or container. There is a 1:1 ratio of service to Logstash data container in this scenario. If each host is designated to running a set of services, as long as logs don't clash, this solution will work for you.

## Conclusion

Adjusting to the Docker has definitely had its ups and downs. Forcing yourself to separate your containers from the host directly cause you to really think about the services you're running and how they interact with each other. By addressing this as early as possible you prepare yourself for whatever container orchestration you might want down the road. As you build out more services and container-ize them, it's inevitable that you'll need a container orchestration solution. We ran into this problem relatively early and solved it by using a data volume container with Logstash alongside our application container. As explained above, depending on what you're trying to achieve with your container orchestration tool, Logspout might be a better solution for you.
