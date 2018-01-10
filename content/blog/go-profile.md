+++
author = "Austin Burnett"
categories = ["golang", "go", "performance", "memory"]
date = "2018-01-09"
description = "Some quick gotchyas for memory profiling in Go."
title = "Go Memory Profiling Gotchya"
type = "post"

+++

# Goal
The holidays are typically a great time to experiment, learn new things, and try to contribute back to your team. This year, I attempted to understand better how one of our command-line tools for [Hipchat Data Center](https://www.atlassian.com/software/hipchat/enterprise/data-center) performs. While being feature complete, we wanted to better understand its resource consumption. Having heard so much about Go's builtin performance tooling, I was excited to learn more and hopefully glean some valuable information to confirm assumptions and start brainstorming solutions.

# Reality

I was quickly met with frustration. Many examples online assume you're building a web application or have an glaringly obvious problem. I was hoping to quickly replicate our problem on a small dataset and I was greeted with an empty memory profile. I created a quick example to demonstrate the empty memory profile problem:

{{< highlight go >}}
package main

import (
    "fmt"
    "os"
    "runtime"
    "runtime/pprof"
)

func main() {
    // CPU Profile
    cpuProfile, err := os.Create("example-cpu.prof")
    if err != nil {
        fmt.Println(err)
        os.Exit(1)
    }
    pprof.StartCPUProfile(cpuProfile)
    defer pprof.StopCPUProfile()

    // Allocate some memory
    x := make([]string, 0)
    for i := 0; i < 1000000; i++ {
        x = append(x, "my string")
    }

    // Memory Profile
    runtime.GC()
    memProfile, err := os.Create("example-mem.prof")
    if err != nil {
        fmt.Println(err)
        os.Exit(1)
    }
    defer memProfile.Close()
    if err := pprof.WriteHeapProfile(memProfile); err != nil {
        fmt.Println(err)
        os.Exit(1)
    }
}
{{< /highlight >}}

Now, the profiling code is mostly lifted from [Profiling Go Programs](https://blog.golang.org/profiling-go-programs) with a quick and dirty memory allocation. I expect to look at the memory profile and see the allocations.

{{< highlight bash >}}
~ go run mem.go
~ go tool pprof mem example-mem.prof
File: mem
Type: inuse_space
Time: Jan 10, 2018 at 11:40am (CST)
Entering interactive mode (type "help" for commands, "o" for options)
(pprof) top
Showing nodes accounting for 1.16MB, 100% of 1.16MB total
      flat  flat%   sum%        cum   cum%
    1.16MB   100%   100%     1.16MB   100%  runtime/pprof.StartCPUProfile /usr/local/go/src/runtime/pprof/pprof.go
         0     0%   100%     1.16MB   100%  main.main /home/aburnett/go/src/stream-test/mem.go
         0     0%   100%     1.16MB   100%  runtime.main /usr/local/go/src/runtime/proc.go
{{< /highlight >}}

Hmm... Not what I expected. If you remove the call to `StartCPUProfile` in hopes of removing that from the profile, you actually end up with an empty memory profile. Why is this?

# Solution

While documented, this information was difficult to uncover. While this post from [Defer Panic](https://deferpanic.com/blog/understanding-golang-memory-usage/) mentions `--alloc_space`, it doesn't mention why you might use it. The pertinent piece of information can be found in the [Golang Performance Wiki](https://github.com/golang/go/wiki/Performance#memory-profiler): `The former [inuse_objects] is useful for profiles collected with net/http/pprof on live applications, the latter is useful for profiles collected at program end [alloc_space] (otherwise you will see almost empty profile).` With many of the blogs and guides out there assuming you're writing a web application, few of them mention these options and `go tool pprof --help` yields no help either. Despite a lack of documentation, these options make sense and are useful. If you're trying to trouble a live application, it's useful to track what is in use right now, where as if you just have a program that runs and terminates, you want to see what was allocated over it's runtime.

{{< highlight bash >}}
~ go tool pprof --alloc_space mem example-mem.prof
File: mem
Type: alloc_space
Time: Jan 10, 2018 at 11:40am (CST)
Entering interactive mode (type "help" for commands, "o" for options)
(pprof) top
Showing nodes accounting for 87.10MB, 100% of 87.10MB total
      flat  flat%   sum%        cum   cum%
   85.94MB 98.67% 98.67%    87.10MB   100%  main.main /home/aburnett/go/src/stream-test/mem.go
    1.16MB  1.33%   100%     1.16MB  1.33%  runtime/pprof.StartCPUProfile /usr/local/go/src/runtime/pprof/pprof.go
         0     0%   100%    87.10MB   100%  runtime.main /usr/local/go/src/runtime/proc.go
(pprof) list main.main
Total: 87.10MB
ROUTINE ======================== main.main in /home/aburnett/go/src/stream-test/mem.go
   85.94MB    87.10MB (flat, cum)   100% of Total
         .          .     14:   cpuProfile, err := os.Create("example-cpu.prof")
         .          .     15:   if err != nil {
         .          .     16:           fmt.Println(err)
         .          .     17:           os.Exit(1)
         .          .     18:   }
         .     1.16MB     19:   pprof.StartCPUProfile(cpuProfile)
         .          .     20:   defer pprof.StopCPUProfile()
         .          .     21:
         .          .     22:   x := make([]string, 0)
         .          .     23:   for i := 0; i < 1000000; i++ {
   85.94MB    85.94MB     24:           x = append(x, "my string")
         .          .     25:   }
         .          .     26:
         .          .     27:   runtime.GC()
         .          .     28:   memProfile, err := os.Create("example-mem.prof")
         .          .     29:   if err != nil {
{{< /highlight >}}

That is more of what we expected to see. If you notice, the `Type` is now `alloc_space` as opposed to the default `inuse_objects`. Now, in the intro I mentioned that I was using a small dataset. Before learning about `--alloc_space` I tried pulling in `github.com/pkg/profile` and added `defer profile.Start(profile.MemProfileRate(2048)).Stop()` at the top of `main`, not really knowing what `MemProfileRate` might do. After adding this, I noticed the profile it generated was non-empty. I started digging into what `github.com/pkg/profile` does. Turns out, it mostly wraps `runtime` to make it more convenient to profile. Setting `MemProfileRate` adjusts the rate at which it samples memory usage. The default is 1 sample per 512kb allocated. I found out that my small sample was never crossing this threshold, resulting in an empty profile. If you want to record _every_ allocation, you can set this to 1. This should enable you to detect problems at any scale. Like I mentioned, there's no need to use `github.com/pkg/profile` other than convenience, you can do this with `runtime` (i.e. `runtime.MemProfileRate = 2048`).

As I discovered, while the tooling may be robust, the documentation is somewhat lacking for Go's profiling tools, especially if you're not using a web application. If you find yourself looking at an empty memory profile, make sure that you're looking at the right usage pattern (inuse_objects - running application vs. alloc_space - program that has already ran) and that you're sampling frequency is adjusted accordingly (or that you track every allocation).
