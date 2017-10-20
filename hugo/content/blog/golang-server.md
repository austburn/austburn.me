+++
author = "Austin Burnett"
categories = [""]
date = "2015-05-26"
description = "In this post, I discuss basic security protocols you encounter everyday and demonstrate how they work using Golang."
title = "Creating a Secure Server in Golang"
type = "post"

+++


As of late, I have become increasingly interested in cryptography and network security. Having had a more frontend centric set of skills, many of these concerns were outside my scope. As I have worked more with web applications and the backends that power them, I have become more and more inquisitive about how we make these applications secure for consumers.

Over the past few months I have been dabbling in [Go](https://golang.org/). As a result, I was made aware of the [Go Challenges](http://golang-challenge.com/). While there are [debates](https://news.ycombinator.com/item?id=9399286) over whether these are meant for beginners trying to grasp the semantics of the language or Go developers competing for prizes, being introduced to interesting challenges provides direction for development. The inspiration of this post derives from the [second Go challenge](http://golang-challenge.com/go-challenge2/). Upon a first try, I was unable to complete the challenge in time, not totally grasping the core concept of the challenge. As a result, I decided to do some research and start from scratch, building working pieces one at a time. The gist of the challenge was to create a secure server you could connect to and emit encrypted messages back and forth. This is the basis for the `https://`, a protocol which layers `http://` on top of [TLS/SSL](http://en.wikipedia.org/wiki/Transport_Layer_Security), both of which are cryptographic protocols. The idea is that you can safely share sensitive information, such as credit card information, over network connections with security against malicious attackers.

Alright, now that we know _what_ `https://` is, let's begin to delve a little deeper. We will begin with some basics for cryptography. The core cryptographic concept that TLS/SSL uses is [public key cryptography](https://developer.mozilla.org/en-US/docs/Introduction_to_Public-Key_Cryptography). For public key cryptography, we utilize a pair of keys:

* **Public key** - This is used to encrypt data. We can share this with anyone. You don't have much power being able to
encrypt messages.
* **Private key** - This is used to decrypt data. DO NOT SHARE! Being able to decrypt
messages that I have encrypted is dangerous.

To demonstrate public key cryptograpy, let's look at some code that utilitzes [`NaCl`](https://godoc.org/golang.org/x/crypto/nacl/box), a popular cryptography toolset ported to Go:

```go
package main

import(
    "fmt"
    "golang.org/x/crypto/nacl/box"
    "crypto/rand"
)

func main() {
    var firstNonce, secondNonce [24]byte

    // This simply creates a random byte array
    rand.Read(firstNonce[:])
    rand.Read(secondNonce[:])

    myPublicKey, myPrivateKey, _ := box.GenerateKey(rand.Reader)
    yourPublicKey, yourPrivateKey, _ := box.GenerateKey(rand.Reader)

    messageToYou := []byte{'g', 'o', 'l', 'a', 'n', 'g'}

    // Now I will encrypt the messageToYou with your public key
    encryptedForYou := box.Seal(nil, messageToYou, &firstNonce, yourPublicKey, myPrivateKey)

    // You can decrypt this with your private key
    decryptedForYou, _ := box.Open(nil, encryptedForYou, &firstNonce, myPublicKey, yourPrivateKey)
    fmt.Printf("%s\n", decryptedForYou) // prints golang

    // You can read the message I sent you...and send me one back!
    messageToMe := []byte{'i', 's', 'c', 'o', 'o', 'l'}

    // Send me back a message that has been encrypted with my public key
    encryptedForMe := box.Seal(nil, messageToMe, &secondNonce, myPublicKey, yourPrivateKey)

    // I can decrypt and read it with my private key
    decryptedForMe, _ := box.Open(nil, encryptedForMe, &secondNonce, yourPublicKey, myPrivateKey)
    fmt.Printf("%s\n", decryptedForMe) // prints iscool
}
```

The only thing in the code example that we haven't really discussed is the idea of a nonce. A **nonce** is a **n**umber that is used **once**. Get it? Basically, the nonce is a mechanism used to further ensure the security of a message. By using a different nonce for each sent message, you further reduce the ability of an attacker being able to decrypt your communications.

Aside from the nonce, you can see that the core concept shown above is public key cryptography. We each have a public/private keypair. I give you my public key, you give me yours. When I send you messages, I encrypt with _your_ public key and you are able to decrypt it with your private key. To respond, you encrypt with _my_ public key and I'll decrypt with my private key. Above we are performing the same operation twice, but I wanted to demonstrate public key cryptography and the sharing of public keys. This demonstration will transcend to our final server implementation - think of 'me' and 'you' as the client and the server.

Now we have the basics of public key cryptography hammered out, let's take a look at our server/client:
```golang
// server.go
package main

import(
    "net"
    "errors"
    "time"
    "fmt"
)

func main() {
    tcpAddr, _ := net.ResolveTCPAddr("tcp", "127.0.0.1:9090")

    // start server
    ln, err := net.ListenTCP("tcp", tcpAddr)
    if err != nil {
        errors.New("Problem setting up server.")
    }

    // continuously accept connections
    for {
        conn, err := ln.AcceptTCP()
        if err != nil {
          errors.New("Error connecting.")
        }
        defer conn.Close()
        go handleConnection(conn)
    }
}

func handleConnection(c *net.TCPConn) {
    const layout = "Jan 2, 2006 at 3:04pm (MST)"
    for {
        msg := make([]byte, 32)
        // read the sent message from the connection
        c.Read(msg)

        // echo it back to the client
        fmt.Fprintf(c, "Echoing back %s at %s", msg,
                    time.Now().Format(layout))
    }
}
```

```gocode
// client.go
package main

import(
    "net"
    "errors"
    "fmt"
    "bufio"
    "os"
)

func main() {
    localAddr, _ := net.ResolveTCPAddr("tcp", "127.0.0.1:9090")
    // connect to 127.0.0.1:9090
    conn, err := net.DialTCP("tcp", nil, localAddr)
    if err != nil {
       errors.New("Problem connecting.")
    }
    // read from stdin
    reader := bufio.NewReader(os.Stdin)
    for {
        fmt.Print("> ")
        msg, _ := reader.ReadBytes(0xA)
        // Kill the newline char
        msg = msg[:len(msg) - 1]
        // write to the connection
        _, err := conn.Write(msg)
        response := make([]byte, 1024)
        // read the response
        _, err = conn.Read(response)
        if err != nil {
            fmt.Print("Connection to the server was closed.\n")
            break
        }
        fmt.Printf("%s\n", response)
    }
}
```

This is a very simple server and client. The server listens for connections and echos your response back with a timestamp. The client starts a connection to the server and displays a prompt to the user. Entering messages sends them to the server and echos back the server response.

Now we have two separate technologies working as expected. We have the elements of public key cryptography and a basic client/server. How can we combine these?

Let's discuss the general flow of a secure connection:

* Connect to the server.
* Generate a key pair on both the server and the client.
* Swap public keys.
* Begin communication between the client and server.

For the most part, the server and the client act the same. The difference being that before we begin our read/write loop on the server and client, we perform a handshake to swap public keys.

```go
// server.go
func handleConnection(conn *net.TCPConn) {
    sharedKey := Handshake(conn)
    secureConnection := SecureConnection{conn: conn, sharedKey: sharedKey}
    // Read/write loop
}

// client.go
func (c *Client) Connect() error {
  // Connect to server...
  sharedKey := Handshake(conn)
  secureConnection := SecureConnection{conn: conn, sharedKey: sharedKey}
  // Read/write loop
}

// secure.go
func Handshake(conn *net.TCPConn) *[32] byte {
    var peerKey, sharedKey [32]byte

    publicKey, privateKey, _ := box.GenerateKey(rand.Reader)

    // Deliver the public key
    conn.Write(publicKey[:])

    // Receive the peer key
    peerKeyArray := make([]byte, 32)
    conn.Read(peerKeyArray)

    copy(peerKey[:], peerKeyArray)

    box.Precompute(&sharedKey, &peerKey, privateKey)

    return &sharedKey
}
```

As you can see, the way we initiate a connection on the server and client are the same. Our `Handshake` function generates a key pair, writes its public key to the connection and reads the peer's key in from the buffer. `box` has a convenience method `Precompute` which provides a speed optimization for when you will be using the same set of keys as we will.

After we have swapped public keys, we can begin to communicate securely. To avoid cluttering the client and server classes and leverage the power of Go, I implemented a `SecureConnection`. From a high level observation, this `SecureConnection` works like the standard `net.Conn` interface. Upon closer inspection, the `Read` and `Write` methods are using the `NaCl` package to encrypt on writes and decrypt on reads:

```go
// secure.go
func (s *SecureConnection) Write(p []byte) (int, error) {
    var nonce [24]byte

    // Create a new nonce for each message sent
    rand.Read(nonce[:])

    encryptedMessage := box.SealAfterPrecomputation(nil, p, &nonce, s.sharedKey)
    sm := SecureMessage{msg: encryptedMessage, nonce: nonce}

    // Write it to the connection
    return s.conn.Write(sm.toByteArray())
}

func (s *SecureConnection) Read(p []byte) (int, error) {
    message := make([]byte, 2048)

    // Read the message from the buffer
    n, err := s.conn.Read(message)

    // Pulls apart the nonce and message from the byte array we received
    secureMessage := ConstructSecureMessage(message)
    decryptedMessage, ok := box.OpenAfterPrecomputation(nil, secureMessage.msg, &secureMessage.nonce, s.sharedKey)

    if !ok {
        return 0, errors.New("Problem decrypting the message.\n")
    }

    // Actually copy it to the destination byte array
    n = copy(p, decryptedMessage)

    return n, err
}
```

On writes, we append the encrypted message to the nonce. What is sent is a random string of bytes. We have to send the nonce because the peer needs it to decrypt. When reading, we basically extract the nonce and the message from the sent byte string and use these to decrypt the message. While this is a pretty simple application, it buys us secure communication. With the web growing and people continuing to trust web applications to hold more and more sensitive data, it is important to know that while communications may not be private, they are secure against attackers trying to sniff your connection.

With that, we have completed our secure server implementation! For the full code sample, you can check it out [here](https://github.com/austburn/gocrypt).
