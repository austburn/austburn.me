+++
author = "Austin Burnett"
categories = ["golang", "go", "software development", "concurrency"]
date = "2018-03-27"
description = "A better example to understand the fan-out, fan-in concurrency pattern in Go."
title = "Go: A Better Fan-out, Fan-in Example"
type = "post"

+++

As I've been learning Go, I've knowingly put off picking up the concurrency model as I know it's something I haven't touched since college. Wanting an additional resource to dive back in, I've been reading [_Concurrency in Go_](http://shop.oreilly.com/product/0636920046189.do) by Katherine Cox-Buday. This book has been great as someone who generally understands the idioms of Go, but may not know where to start when it comes to concurrency.

Popularized by the [Go blog](https://blog.golang.org/pipelines) and referenced in the book is the fan-out, fan-in pattern. In my opinion, the examples suffer from being too generic. It was hard for me to reference the examples and understand the real benefit of using this pattern. So, I began thinking of examples that showed why this was a powerful pattern.

The context of out problem is a shipping warehouse. Items are sent from the shelves to a conveyor belt. An employee packs the items and places them on an outbound conveyor belt to be shipped. It's important here to note that we'll have one item per box and that some items may require extra handling to package than others. Let's first conquer the problem using pipelines:

{{< highlight go "linenos=inline" >}}
// https://play.golang.org/p/JWEIQDdxv6G
package main

import (
        "fmt"
        "time"
)

type Item struct {
        ID            int
        Name          string
        PackingEffort time.Duration
}

func PrepareItems(done <-chan bool) <-chan Item {
        items := make(chan Item)
        itemsToShip := []Item{
                Item{0, "Shirt", 1 * time.Second},
                Item{1, "Legos", 1 * time.Second},
                Item{2, "TV", 5 * time.Second},
                Item{3, "Bananas", 2 * time.Second},
                Item{4, "Hat", 1 * time.Second},
                Item{5, "Phone", 2 * time.Second},
                Item{6, "Plates", 3 * time.Second},
                Item{7, "Computer", 5 * time.Second},
                Item{8, "Pint Glass", 3 * time.Second},
                Item{9, "Watch", 2 * time.Second},
        }
        go func() {
                for _, item := range itemsToShip {
                        select {
                        case <-done:
                                return
                        case items <- item:
                        }
                }
                close(items)
        }()
        return items
}

func PackItems(done <-chan bool, items <-chan Item) <-chan int {
        packages := make(chan int)
        go func() {
                for item := range items {
                        select {
                        case <-done:
                                return
                        case packages <- item.ID:
                                time.Sleep(item.PackingEffort)
                                fmt.Printf("Shipping package no. %d\n", item.ID)
                        }
                }
                close(packages)
        }()
        return packages
}

func main() {
        done := make(chan bool)
        defer close(done)

        start := time.Now()

        packages := PackItems(done, PrepareItems(done))

        numPackages := 0
        for range packages {
                numPackages++
        }

        fmt.Printf("Took %fs to ship %d packages\n", time.Since(start).Seconds(), numPackages)
}
{{< / highlight >}}

In this example, `PrepareItems` queues up items on an unbuffered channel, think of this as our conveyor belt from the shelves to the employee packing the items. `PackItems` pulls from this channel, places it on the packages channel (i.e., our shipping conveyor belt), and assimilates work by calling `time.Sleep` for the `PackingEffort` in seconds. This pipeline essentially runs serially, requiring 25s to run. A possible solution to this problem is adding more workers. Additional workers can pack items and make sure they make it onto the shipping belt. This is the essence of fan-out, fan-in. We'll introduce additional goroutines in a certain stage to increase our throughput, placing them back into the single pipeline. (**Note**: I'm going to use a hard-coded number for number of additional goroutines to run for simplicity. You may want to explore `runtime.NumCPU()` or experiment in your production environment to understand what suits your usecase.)

{{< highlight go "linenos=inline" >}}
// https://play.golang.org/p/_NAoJ3szSyo
package main

import (
        "fmt"
        "sync"
        "time"
)

type Item struct {
        ID            int
        Name          string
        PackingEffort time.Duration
}

func PrepareItems(done <-chan bool) <-chan Item {
        items := make(chan Item)
        itemsToShip := []Item{
                Item{0, "Shirt", 1 * time.Second},
                Item{1, "Legos", 1 * time.Second},
                Item{2, "TV", 5 * time.Second},
                Item{3, "Bananas", 2 * time.Second},
                Item{4, "Hat", 1 * time.Second},
                Item{5, "Phone", 2 * time.Second},
                Item{6, "Plates", 3 * time.Second},
                Item{7, "Computer", 5 * time.Second},
                Item{8, "Pint Glass", 3 * time.Second},
                Item{9, "Watch", 2 * time.Second},
        }
        go func() {
                for _, item := range itemsToShip {
                        select {
                        case <-done:
                                return
                        case items <- item:
                        }
                }
                close(items)
        }()
        return items
}

func PackItems(done <-chan bool, items <-chan Item, workerID int) <-chan int {
        packages := make(chan int)
        go func() {
                for item := range items {
                        select {
                        case <-done:
                                return
                        case packages <- item.ID:
                                time.Sleep(item.PackingEffort)
                                fmt.Printf("Worker #%d: Shipping package no. %d, took %ds to pack\n", workerID, item.ID, item.PackingEffort / time.Second)
                        }
                }
                close(packages)
        }()
        return packages
}

func merge(done <-chan bool, channels ...<-chan int) <-chan int {
        var wg sync.WaitGroup

        wg.Add(len(channels))
        outgoingPackages := make(chan int)
        multiplex := func(c <-chan int) {
                defer wg.Done()
                for i := range c {
                        select {
                        case <-done:
                                return
                        case outgoingPackages <- i:
                        }
                }
        }
        for _, c := range channels {
                go multiplex(c)
        }
        go func() {
                wg.Wait()
                close(outgoingPackages)
        }()
        return outgoingPackages
}

func main() {
        done := make(chan bool)
        defer close(done)

        start := time.Now()

        items := PrepareItems(done)

        workers := make([]<-chan int, 4)
        for i := 0; i<4; i++ {
                workers[i] = PackItems(done, items, i)
        }

        numPackages := 0
        for range merge(done, workers...) {
                numPackages++
        }

        fmt.Printf("Took %fs to ship %d packages\n", time.Since(start).Seconds(), numPackages)
}
{{< / highlight >}}

Here, you can see that on lines 93-96 we setup the additional "workers" to fan-out the problem. This part actually didn't make much sense to me the first few times looking at it. The key part is that they all reference the same channel of `Item`s to read from and they each return a channel that they write to, which in the end we will "fan-in" by merging these channels back into one single channel.

By running this, you can actually see which "worker" is preparing a package:

```
Worker #1: Shipping package no. 1, took 1s to pack
Worker #0: Shipping package no. 0, took 1s to pack
Worker #1: Shipping package no. 4, took 1s to pack
Worker #3: Shipping package no. 3, took 2s to pack
Worker #0: Shipping package no. 5, took 2s to pack
Worker #1: Shipping package no. 6, took 3s to pack
Worker #2: Shipping package no. 2, took 5s to pack
Worker #0: Shipping package no. 8, took 3s to pack
Worker #3: Shipping package no. 7, took 5s to pack
Worker #1: Shipping package no. 9, took 2s to pack
Took 7.000000s to ship 10 packages
```

7 seconds is quite the improvement from 25! It's important to note now, that the order is scrambled. Fan-out, fan-in is useful in scenarios when you have a specific stage of your pipeline that is computationally expensive (aka taking long) and that the order of your stream is not important.

I hope that this serves as a bit more verbose, useful example of the fan-out, fan-in problem. It has really helped me grasp the problem better. If you have any questions, feel free to reach me [@austburn](https://twitter.com/austburn).
