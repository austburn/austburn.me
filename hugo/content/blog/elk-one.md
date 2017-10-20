+++
author = "Austin Burnett"
categories = [""]
date = "2015-10-19"
description = "The ELK stack is something that I've learned about through work. In this post, I try to apply what I've learned to my IRC logs."
title = "Setting Up An ELK Stack for IRC Logs: Part One"
type = "post"

+++

On the [Rackspace Cloud Control Panel](https://mycloud.rackspace.com) team, we use the [ELK Stack](https://www.elastic.co/webinars/introduction-elk-stack) to collect and visualize our logs. You can find more information online, but out of convenience:

* **Elasticsearch** - Used to index logs and make them searchable.
* **Logstash** - Takes any log and allows you to create a filter to pull out the information you are interested in and format it for Elasticsearch indexing.
* **Kibana** - Pretty web application that leverages the Elasticsearch api.


Being on-call occasionally, I utilize an IRC bouncer in order to keep track of logs so that I don't have to. Just because my bouncer keeps track of my logs doesn't imply that they're easy to reference. As a result, I decided to set up an ELK stack for my IRC logs. Probably a little overkill, but it presents itself as a useful exercise that others might be able to relate to.

This post will be part of a 2 (or 3) part series. First, we'll set up Logstash to parse our IRC logs.

Let's start with some details:

* I have a lot of logs.
* Inside the log files, there are two formats:
  * `[hh:mm:ss] <user> <log>`
  * `[hh:mm:ss] <log>`
* Logs are titled: `user_network_channel_yyyymmdd.log`

I would put how to get started with Logstash, but my teammate Matt Green put together a [thorough guide](https://medium.com/@thematthewgreen/getting-started-with-logstash-62f0a573685b). The guide will take you through the basics of Logstash, getting it set up, and how to write Logstash configurations.

With that, let's get started. When writing a new filter, I usually just set up a basic config that utilizes `stdin`and `stdout` and as per Matt's suggestion, use [Grok Debugger](https://grokdebug.herokuapp.com/) to create a basic filter:

```
input {
  stdin { }
}
 filter {
  grok {
    match => {
      "message" => [ "\[%{TIME:time}\] \<%{GREEDYDATA:username}\> %{GREEDYDATA:msg}" ]
    }
  }
}
 output {
  stdout { codec => rubydebug }
}
```

This Logstash configuration enables us to filter our first type of log, a basic log with a timestamp, username, and a message. We'll use the `GREEDYDATA` pattern because both usernames and messages can contain symbols that the `WORD` pattern does not include.

**TIP:** You can find a list of Logstash grok patterns [here](https://github.com/elastic/logstash/blob/v1.4.2/patterns/grok-patterns).


Let's take a look at what our config will do:

```bash
# Wait until "Logstash startup completed" is echo'd
# then type "[07:25:53] <austburn> ping" - fun, right?
$ bin/logstash  -f grok_config
Logstash startup completed
[07:25:53] <austburn> ping
{
     "message" => "[07:25:53] <austburn> ping",
    "@version" => "1",
  "@timestamp" => "2015-10-14T19:34:26.866Z",
        "time" => "07:25:53",
    "username" => "austburn",
         "msg" => "ping"
}
```

Awesome, our config worked as expected.

What if we feed it a system log?

```bash
$ bin/logstash  -f grok_config
Logstash startup completed
[07:25:53] austin is now known as austburn
{
     "message" => "[07:25:53] austin is now known as austburn",
    "@version" => "1",
  "@timestamp" => "2015-10-19T17:41:58.789Z",
        "tags" => [
      [0] "_grokparsefailure"
  ]
}
```

`_grokparsefailure` is not what we wanted. Since we were looking for a username enclosed in angle brackets, grok didn't appreciate our log not adhering to that style.

Logstash supports multiple grok patterns. Be careful as Logstash attempts to parse logs in the order of the patterns. I made this mistake by putting a more lenient pattern first and it absorbed all my logs. As a rule of thumb, you'd want to have your least generic filter take precedence.

```
input {
  stdin { }
}
 filter {
  grok {
    match => {
      "message" => [ "\[%{TIME:time}\] \<%{GREEDYDATA:username}\> %{GREEDYDATA:msg}", "\[%{TIME:time}\] %{GREEDYDATA:msg}" ]
    }
  }
}
 output {
  stdout { codec => rubydebug }
}
```

```bash
$ bin/logstash  -f grok_config
Logstash startup completed
[07:25:53] austin is now known as austburn
{
     "message" => "[07:25:53] austin is now known as austburn",
    "@version" => "1",
  "@timestamp" => "2015-10-19T17:54:59.859Z",
        "time" => "07:25:53",
         "msg" => "austin is now known as austburn"
}
[07:25:53] <austburn> ping
{
     "message" => "[07:25:57] <austburn> ping",
    "@version" => "1",
  "@timestamp" => "2015-10-19T17:56:25.761Z",
        "time" => "07:25:57",
    "username" => "austburn",
         "msg" => "ping"
}
```

Now our filter accepts and parses both types of logs. In reality, I don't really care if austin changed his IRC nickname at all. I don't need to index these logs or look at them ever again, so we're actually going to ignore them.

Normally, you probably would not want to drop all logs that produce `_grokparsefailure`'s, but being that IRC logs are pretty straightforward, this is OK.

```
input {
  stdin { }
}
 filter {
  grok {
    match => {
      "message" => [ "\[%{TIME:time}\] \<%{GREEDYDATA:username}\> %{GREEDYDATA:msg}" ]
    }
  }
  if "_grokparsefailure" in [tags] {
    drop { }
  }
}
 output {
  stdout { codec => rubydebug }
}
```

While using `stdin` is great for debugging and general testing, it's not how we'll ultimately consume the logs. For right now, I plan to read logs from disk. There is a `file` plugin for the input that we will use.

```
input {
  file {
    path => ["/data/log/*"]
    start_position => "beginning"
    sincedb_path => "/dev/null"
  }
}
 filter {
  grok {
    match => {
      "message" => [ "\[%{TIME:time}\] \<%{GREEDYDATA:username}\< %{GREEDYDATA:msg}" ]
    }
  }
  if "_grokparsefailure" in [tags] {
    drop {}
  }
}
 output {
  stdout { codec => rubydebug }
}
```

Let's talk through this config:

  * **path**: Where the logs we want are located on disk
  * **start_position**: Tell where Logstash to begin parsing files. By default, this is set to `"end"` because Logstash expects traditional
  log behavior where new logs are appended to the file.
  * **sincedb_path**: Really only necessary for the ability to reprocess logs. Logstash keeps track of how much of a file it has parsed so
    that it does not reprocess logs. By setting this to `/dev/null`, Logstash effectively has no memory and will reprocess logs each run. We will
  want to remove this when we begin to actually consume logs.


As I mentioned before, ZNC stores some valuable data in the name of the log file including the user, network, channel, and date. If you've noticed, our timestamps are not linked to the time the log was written. This information will be important for indexing logs and searching for logs base on time.

Because we're now consuming logs from file, we have access to the filename via the path attribute. We can add a second grok pattern and add this information to the log.

```
input {
  file {
    path => ["/data/log/*"]
    start_position => "beginning"
    sincedb_path => "/dev/null"
  }
}
 filter {
  grok {
    match => {
      "message" => [ "\[%{TIME:time}\] \<%{GREEDYDATA:username}\< %{GREEDYDATA:msg}" ]
    }
    match => {
      "path" => [ "%{UNIXPATH:location}\/%{GREEDYDATA:znc_user}_%{GREEDYDATA:network}_#%{GREEDYDATA:channel}_%{YEAR:year}%{MONTHNUM:month}%{MONTHDAY:day}" ]
    }
    break_on_match => false
  }
  if "_grokparsefailure" in [tags] {
    drop {}
  }
}
 output {
  stdout { codec => rubydebug }
}
```

Let's see what this looks like:

```
$ bin/logstash  -f grok_config
Logstash startup completed
{
     "message" => "[19:43:13] <austburn> hey",
    "@version" => "1",
  "@timestamp" => "2015-10-19T19:57:31.748Z",
        "path" => "/data/log/austburn_freenode_#austin_channel_20150615.log",
        "time" => "19:43:13",
    "username" => "austburn",
         "msg" => "hey",
    "location" => "/data/log",
    "znc_user" => "austburn",
     "network" => "freenode",
     "channel" => "austin_channel",
        "year" => "2015",
       "month" => "06",
         "day" => "15"
}
```

We now have all the information to craft the timestamp based on the filename and time in the log message itself.

To achieve this, we are going to have to construct a timestamp from the information we have and apply the `date` filter in order to manipulate the `@timestamp` field.

```
input {
  file {
    path => ["/data/log/*"]
    start_position => "beginning"
    sincedb_path => "/dev/null"
  }
}
 filter {
  grok {
    match => {
      "message" => [ "\[%{TIME:time}\] \<%{GREEDYDATA:username}\> %{GREEDYDATA:msg}" ]
    }
    match => {
      "path" => [ "%{UNIXPATH:location}\/%{GREEDYDATA:znc_user}_%{GREEDYDATA:network}_#%{GREEDYDATA:channel}_%{YEAR:year}%{MONTHNUM:month}%{MONTHDAY:day}" ]
    }
    break_on_match => false
  }
  if "_grokparsefailure" in [tags] {
    drop {}
  }
  mutate {
    add_field => { "message_timestamp" => "%{year}-%{month}-%{day};%{time}" }
  }
  date {
    match => [ "message_timestamp", "YYYY-MM-dd;HH:mm:ss" ]
    target => "@timestamp"
  }
  mutate {
    remove_field => [ "message_timestamp", "year", "month", "day", "time" ]
  }
}
 output {
  stdout { codec => rubydebug }
}
```

This config will:

  * Grab the time information from the IRC log as well as the filename.
  * Create a `message_timestamp` field based on the information we collected.
  * Use the date filter to parse the `message_timestamp` field and assign the value to the `@timestamp` field.
  * Remove all the time related fields that we no longer need.


Let's see what the final log looks like:

```
$ bin/logstash  -f grok_config
Logstash startup completed
{
     "message" => "[19:43:13] <austburn> hey",
    "@version" => "1",
  "@timestamp" => "2015-06-15T19:43:13.000Z",
        "path" => "/data/log/austburn_freenode_#austin_channel_20150615.log",
    "username" => "austburn",
         "msg" => "hey",
    "location" => "/data/log",
    "znc_user" => "austburn",
     "network" => "freenode",
     "channel" => "austin_channel"
}
```

Great, now our logs parsed and include all the information we need (or have access to for that matter) to start indexing.

That will conclude this part of the series. In conclusion we:

  * Set up Logstash.
  * Built a basic Logstash config utilizing `stdin`.
  * Filtered out IRC system logs.
  * Created a Logstash filter for reading from disk.
  * Gathered interesting information from the filename.
  * Used the information we had to give the log an accurate timestamp.
