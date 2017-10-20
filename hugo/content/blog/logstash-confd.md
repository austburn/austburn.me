+++
author = "Austin Burnett"
categories = [""]
date = "2016-08-12"
description = "Making a dynamic Logstash container with confd."
title = "Logstash and confd"
type = "post"

+++


In my [last post](/blog/docker-logging) I talked about making your application containers more portable in regards to logging. The way my team ended up doing this was by shipping a container along with our application container that served as a data container to mount application logs to and having Logstash run in that container with application logs as the input. I mentioned in the previous post that I had found adding as much information to the logs as you can at the source will alleviate problems later. After having recently discovered [`confd`](https://github.com/kelseyhightower/confd), we have started using it inside our Logstash container to configure Logstash by environment.

## Logging in a Multi-environment, Multi-region World

Having log information is obviously important to the success of your application. As developers, we often use logs to gain insight as to what the application is doing in real time. For experience designers or managers, logs can serve as the data to understand how users are reacting to a new experiment. Unfortunately, logs are often associated with understanding what went wrong. In any case, you'd be hard pressed to argue that the more information your logs have, the less valuable they are. It's crucial to be able to filter your logs by environment, region, and any other top-level distinction you have for your application's architecture.

This allows you to answer very specific questions: How does that change look in APAC? Can we go to production with that? How are our LON users responding to the new experiment? Looks like we're seeing increased response times on the West coast, how do the upstream response times look in that region? Whether you want to know how your changes look with respect to your continuous integration pipeline, how customers are interacting with your site, or what the root of a problem might be, more information is always better. You begin to be able to discern between a true application problem and what might be a problem with one of your dependencies: hosting provider, upstream API, etc.

If you begin to see logs suggesting that your _entire_ application is suffering, what changes just went in? There is a good chance they're bad. Are you seeing problems in a specific region? Check your hosting provider's status page, what's going on in that region? Do you use region-specific API endpoints? What about their status? Being that operationally aware can greatly improve your ability to respond to problems. I can attest to mental blur when things have gone wrong only to be asked by one of our more senior engineers, "Wait, where are you seeing this?", only for me to realize that the world is not coming to the end and there is a known reason that our nodes in X environment and Y region are alerting.

## Life Before Confd

As my team has taken on new projects, we've learned a bit more each time and have been able to improve our practices in many areas. In some of our older projects, we have some examples of what I'd consider inefficient Logstash configuration:

```
# app-n01.prod.dfw.rackspace.net
filter {
    grok {
        match => { "host" => "%{WORD:node}.%{WORD:environment}.%{WORD:region}.rackspace.net" }
    }
}
```

While this configuration is pretty straightforward, we're just stripping some information from the `host` field, we perform this `grok` for _every_ log we index. The logging pipeline I'm referencing indexes over a million logs per hour. While I can't exactly quantify how much time we're spending in this very `grok`, I can guarantee that it is time lost and that we can fix this problem.

## Enter Confd

On the most recent project my team has been working on, we are trying to live in a more mutable world. One of our goals is to be able to autoscale our application. While
we're still working on getting there, one of the side effects is that we don't have the luxury of garnering information from the hostname. If a node dies or we experience
load that triggers our application to scale, this new node will have a dynamically generated hostname. So, we lose the ability to use that `grok` above as our
hostname no longer carries the information we'd want. This is great, we have to get creative!

To break `confd` down a bit, it basically enables you to template text files powered by an array of engines or backends. `confd` is a powerful
tool and honestly, we're going to belittle its abilities a bit in this post. You should really take the time to check [it](https://github.com/kelseyhightower/confd) out and see how you might be able to use it for your own projects. You can use `confd` with a myriad of backends, like [`etcd`](https://github.com/coreos/etcd), and have updates trigger service reloads. For instance, you could have a change in `etcd` trigger an `nginx` reload. This is just one example, but can get your gears turning for how you might be able to leverage `confd` with some services you may already be using. We're going to generate Logstash configuration files using `confd` powered by environment variables.

### Logstash and Confd

It's probably easiest for you to see this in action, rather than writing about how to use it. For that reason, I created a [repository](https://github.com/austburn/logstash-confd/tree/not-crazy) for reference. Notice that this is actually on a branch... That branch's name is `not-crazy`. In the process of writing this post I began to work on the code examples. My brain spiraled out of control. I was trying to create an image for the Docker hub that was truly dynamic via `confd`. The problem I ran into was that I was basically rewriting Logstash config. If you check out the [`master`](https://github.com/austburn/logstash-confd) branch, you can see this. I slowly realized I was reinventing the wheel. If you want a truly dynamic solution, don't mind passing in long environment strings to Docker, and don't want to host your images, I suggest you just use the official [Logstash image](https://hub.docker.com/_/logstash/). If you don't mind rolling a bit of your own Logstash config and hosting that image doesn't bother you, then the Logstash `confd` hybrid may be for you. I felt I had to be transparent here, I'm looping back on this blog post after a few weeks because I wasn't sure what I had created or where this was going. I still think this approach is useful and can easily be tweaked to your needs.

OK, with that out of the way, let's start looking at this branch. I'll label the sections by the directory I'm discussing.

#### [`logstash/config`](https://github.com/austburn/logstash-confd/tree/not-crazy/logstash/config)

Here we'll store our static Logstash configuration. This will generally be you `input`, `output`, and maybe some `filter` configuration that applies to classes of logs regardless of environment, region, etc.

#### [`etc/confd`](https://github.com/austburn/logstash-confd/tree/not-crazy/etc/confd)

This folder contains our `confd` configuration and templates. In `config.toml` you can see that if you were to follow this approach, you may need to update the `keys` to match your needs. These are the names of the environment variables that `confd` expects and will feed to our template. This is also where, as I mentioned before, you may configure your reload commands that would be triggered on a `confd` backend update. Looking at `filter.tmpl`, you can see we access our `keys` here.

#### [`Dockerfile`](https://github.com/austburn/logstash-confd/blob/not-crazy/Dockerfile)

* [Grab `confd`](https://github.com/austburn/logstash-confd/blob/not-crazy/Dockerfile#L3-L4)
* [Add our config](https://github.com/austburn/logstash-confd/blob/not-crazy/Dockerfile#L6-L8)
* [Run `confd`](https://github.com/austburn/logstash-confd/blob/not-crazy/Dockerfile#L10) to populate our Logstash config.
* [Start Logstash](https://github.com/austburn/logstash-confd/blob/not-crazy/Dockerfile#L11)

### Demo

```bash
# Window1 - execute in logstash-confd directory
# Build and tag
$ docker build --tag logstash-confd .

# Run it
$ docker run -it --name logstash-confd \
                        -e ENVIRONMENT=test \
                        -e REGION=local \
                        logstash-confd

# Switch to Window2...

{
        "message" => "user did x",
       "@version" => "1",
     "@timestamp" => "2016-08-12T16:17:36.850Z",
           "path" => "/var/log/web.log",
           "host" => "385b22573e9b",
           "tags" => [
        [0] "web"
    ],
    "environment" => "test",
         "region" => "local"
}
{
        "message" => "/ 200 OK",
       "@version" => "1",
     "@timestamp" => "2016-08-12T16:17:51.842Z",
           "path" => "/var/log/access.log",
           "host" => "385b22573e9b",
           "tags" => [
        [0] "server_access"
    ],
    "environment" => "test",
         "region" => "local"
}
```

```bash
# Window2

# Exec into our container and just dump some logs
$ docker exec -it logstash-confd /bin/bash -c \
        "echo user did x > /var/log/web.log && \
        echo / 200 OK > /var/log/access.log"
# See output in Window1...
```

## Wrapping Up

### Why not use [`add_metadata_from_env`](https://www.elastic.co/guide/en/logstash/current/plugins-filters-environment.html)?

I investigated this option before using `confd`. The biggest reason I didn't use the `environment` plugin is because it adds the environment variable you're interested in as a child of the `@metadata` key. These are important fields to us that we regularly search for (e.g., `environment:"preprod" AND region:"dfw"`) . I didn't want to make our Kibana queries feel unnatural or clunky and didn't want to add additional processing to lift those `@metadata` keys to be first class fields. Further, it seems there is some [nastiness](http://stackoverflow.com/questions/30648488/nested-object-in-kibana-visualize) surrounding nested fields and Kibana queries.

### Conclusion

Before we started using `confd` for our Logstash configurations, we had the liberty of plucking useful information from the node's `hostname` - a default field. In order to become more resilient, we're investigating how we can autoscale our infrastructure. A by-product of this is that we don't have the ability to garner useful information from the `hostname`. We use `confd` to dynamically configure our Logstash configurations to add information about where the node is located. Hopefully by looking at my example [repo](https://github.com/austburn/logstash-confd/tree/not-crazy) you can craft a similar logging container for your needs. This added information is invaluable when trying to gather insight from your logs and more deeply understand how your changes affect your application and its users.
