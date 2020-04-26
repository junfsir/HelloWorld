### close函数

close函数是用于关闭通道的。 
官方解释（摘自close函数源代码注释）：

```shell
The close built-in function closes a channel, which must be either 
bidirectional or send-only. It should be executed only by the sender, 
never the receiver, and has the effect of shutting down the channel after 
the last sent value is received. After the last value has been received 
from a closed channel c, any receive from c will succeed without 
blocking, returning the zero value for the channel element. The form 
x, ok := <-c 
will also set ok to false for a closed channel.
```

翻译过来就是：

```shell
close函数是一个内建函数， 用来关闭channel，这个channel要么是双向的， 要么是只写的（chan<- Type）。 
这个方法应该只由发送者调用， 而不是接收者。 
当最后一个发送的值都被接收者从关闭的channel(下简称为c)中接收时, 
接下来所有接收的值都会非阻塞直接成功，返回channel元素的零值。 
如下的代码： 
如果c已经关闭（c中所有值都被接收）， x, ok := <- c， 读取ok将会得到false。
```

验证如下：

```go
package main

import "fmt"

func main() {
    ch := make(chan int, 5)

	for i := 0; i < 5; i++ {
	    ch <- i
	}
	
	close(ch) // 关闭ch
	for i := 0; i < 10; i++ {
	    e, ok := <-ch
	    fmt.Printf("%v, %v\n", e, ok)
	
	    if !ok {
	        break
	    }
	}

}

```

输出： 

```shell
0, true 
1, true 
2, true 
3, true 
4, true 
0, false
```



在close之后， 还可以读取， 不过在读取完之后， 再检测ok, 就是false了。

注意事项: 
对于值为nil的channel或者对同一个channel重复close, 都会panic, 关闭只读channel会报编译错误。, 代码示例如下：

关闭值为nil的通道

```shell
var c4 chan int

// 运行时错误：panic: close of nil channel
close(c4)
```

重复关闭同一个通道

```shell
c3 := make(chan int, 1)
close(c3)

// 运行时错误：
// panic: close of closed channel
close(c3)
```


关闭只读通道

```shell
c3 := make(<-chan int, 1)

// 编译错误：
// invalid operation: close(c3) (cannot close receive-only channel)
close(c3)

```

正确的用法

```shell
c1 := make(chan int, 1) // 双向通道 (bidirectional)
c2 := make(chan<- int, 1) // 只写的 (send-only)
close(c1)
close(c2)
```

---

### Go Channel基本操作语法

Go Channel的基本操作语法如下：

```shell
c := make(chan bool) //创建一个无缓冲的bool型Channel

c <- x        //向一个Channel发送一个值

<- c          //从一个Channel中接收一个值

x = <- c      //从Channel c接收一个值并将其存储到x中

x, ok = <- c  //从Channel接收一个值，如果channel关闭了或没有数据，那么ok将被置为false
```

*不带缓冲的Channel*兼具通信和同步两种特性，颇受青睐。

### Channel用作信号(Signal)的场景

1. 等待一个事件(Event)

等待一个事件，有时候通过close一个Channel就足够了。例如：

```go
//testwaitevent1.go

package main

import "fmt"

func main() {

        fmt.Println("Begin doing something!")

        c := make(chan bool)

        go func() {

                fmt.Println("Doing something…")

                *close(c)*

        }()

        *<-c*

        fmt.Println("Done!")

}
```



这里main goroutine通过"<-c"来等待sub goroutine中的“完成事件”，sub goroutine通过close channel促发这一事件。当然也可以通过向Channel写入一个bool值的方式来作为事件通知。main goroutine在channel c上没有任何数据可读的情况下会阻塞等待。

关于输出结果：

根据《[Go memory model](http://golang.org/ref/mem)》中关于close channel与recv from channel的order的定义：*The closing of a channel happens before a receive that returns a zero value because the channel is closed.*

我们可以很容易判断出上面程序的输出结果：

```shell
Begin doing something!

Doing something…

Done!
```

如果将close(c)换成c<-true，则根据《Go memory model》中的定义：*A receive from an unbuffered channel happens before the send on that channel completes.*

"<-c"要先于"c<-true"完成，但也不影响日志的输出顺序，输出结果仍为上面三行。

2. 协同多个Goroutines

同上，close channel还可以用于协同多个Goroutines，比如下面这个例子，我们创建了100个Worker Goroutine，这些Goroutine在被创建出来后都阻塞在"<-start"上，直到我们在main goroutine中给出开工的信号："close(start)"，这些goroutines才开始真正的并发运行起来。

```go
//testwaitevent2.go

package main

import "fmt"

func worker(start chan bool, index int) {

        <-start

        fmt.Println("This is Worker:", index)

}

func main() {

        start := make(chan bool)

        for i := 1; i <= 100; i++ {

                go worker(start, i)

        }

        close(start)

        select {} //deadlock we expected

}
```

3. Select

- [ ] select的基本操作

select是Go语言特有的操作，使用select我们可以同时在多个channel上进行发送/接收操作。下面是select的基本操作。

```shell
select {

case x := <- somechan:

    // … 使用x进行一些操作

case y, ok := <- someOtherchan:

    // … 使用y进行一些操作，

    // 检查ok值判断someOtherchan是否已经关闭

case outputChan <- z:

    // … z值被成功发送到Channel上时

default:

    // … 上面case均无法通信时，执行此分支

}
```

- [ ] 惯用法：for/select

我们在使用select时很少只是对其进行一次evaluation，我们常常将其与for {}结合在一起使用，并选择适当时机从for{}中退出。

```go
for {

        select {

        case x := <- somechan:

            // … 使用x进行一些操作

        case y, ok := <- someOtherchan:

            // … 使用y进行一些操作，

            // 检查ok值判断someOtherchan是否已经关闭

        case outputChan <- z:

            // … z值被成功发送到Channel上时

        default:

            // … 上面case均无法通信时，执行此分支

        }

}
```

- [ ] 终结workers

下面是一个常见的终结sub worker goroutines的方法，每个worker goroutine通过select监视一个die channel来及时获取main goroutine的退出通知。

```go
//testterminateworker1.go

package main

import (

    "fmt"

    "time"

)

func worker(die chan bool, index int) {

    fmt.Println("Begin: This is Worker:", index)

    for {

        select {

        //case xx：

            //做事的分支

        case <-die:

            fmt.Println("Done: This is Worker:", index)

            return

        }

    }

}

func main() {

    die := make(chan bool)

    for i := 1; i <= 100; i++ {

        go worker(die, i)

    }

    time.Sleep(time.Second * 5)

    close(die)

    select {} //deadlock we expected

}
```

- [ ] 终结验证

有时候终结一个worker后，main goroutine想确认worker routine是否真正退出了，可采用下面这种方法：

```go
//testterminateworker2.go

package main

import (

    "fmt"

    //"time"

)

func worker(die chan bool) {

    fmt.Println("Begin: This is Worker")

    for {

        select {

        //case xx：

        //做事的分支

        case <-die:

            fmt.Println("Done: This is Worker")

            die <- true

            return

        }

    }

}

func main() {

    die := make(chan bool)

    go worker(die)

    die <- true

    <-die

    fmt.Println("Worker goroutine has been terminated")

}
```

- [ ] 关闭的Channel永远不会阻塞

下面演示在一个已经关闭了的channel上读写的结果：

```go
//testoperateonclosedchannel.go

package main

	import "fmt"

func main() {

       cb := make(chan bool)

       close(cb)

       x := <-cb

       fmt.Printf("%#v\n", x)

       x, ok := <-cb

       fmt.Printf("%#v %#v\n", x, ok)

       ci := make(chan int)

       close(ci)

       y := <-ci

       fmt.Printf("%#v\n", y)

       cb <- true

}
```

```shell
$go run testoperateonclosedchannel.go

false

false false

0

panic: runtime error: send on closed channel
```

可以看到在一个已经close的unbuffered channel上执行读操作，回返回channel对应类型的零值，比如bool型channel返回false，int型channel返回0。但向close的channel写则会触发panic。不过无论读写都不会导致阻塞。

- [ ] 关闭带缓存的channel

将unbuffered channel换成buffered channel会怎样？我们看下面例子：

```shell
//testclosedbufferedchannel.go

package main

import "fmt"

func main() {

       c := make(chan int, 3)

       c <- 15

       c <- 34

       c <- 65

       close(c)

       fmt.Printf("%d\n", <-c)

       fmt.Printf("%d\n", <-c)

       fmt.Printf("%d\n", <-c)

       fmt.Printf("%d\n", <-c)

       c <- 1

}
```

```shell
$go run testclosedbufferedchannel.go

15

34

65

0

panic: runtime error: send on closed channel
```

可以看出带缓冲的channel略有不同。尽管已经close了，但我们依旧可以从中读出关闭前写入的3个值。第四次读取时，则会返回该channel类型的零值。向这类channel写入操作也会触发panic。

- [ ] range

Golang中的range常常和channel并肩作战，它被用来从channel中读取所有值。下面是一个简单的实例：

```go
//testrange.go

package main

import "fmt"

func generator(strings chan string) {

        strings <- "Five hour's New York jet lag"

        strings <- "and Cayce Pollard wakes in Camden Town"

        strings <- "to the dire and ever-decreasing circles"

        strings <- "of disrupted circadian rhythm."

        close(strings)

}

func main() {

        strings := make(chan string)

        go generator(strings)

        for s := range strings {

                fmt.Printf("%s\n", s)

        }

        fmt.Printf("\n")

}
```

### 隐藏状态

下面通过一个例子来演示一下channel如何用来隐藏状态：

1. 例子：唯一的ID服务

```go
//testuniqueid.go

package main

import "fmt"

func newUniqueIDService() <-chan string {

        id := make(chan string)

        go func() {

                var counter int64 = 0

                for {

                        id <- fmt.Sprintf("%x", counter)

                        counter += 1

                }

        }()

        return id

}

func main() {

        id := newUniqueIDService()

        for i := 0; i < 10; i++ {

                fmt.Println(<-id)

        }

}
```

```shell
$ go run testuniqueid.go

0

1

2

3

4

5

6

7

8

9
```

newUniqueIDService通过一个channel与main goroutine关联，main goroutine无需知道uniqueid实现的细节以及当前状态，只需通过channel获得最新id即可。

### 默认情况

我想这里John Graham-Cumming主要是想告诉我们select的default分支的实践用法。

1. select  for non-blocking receive

```shell
idle:= make(chan []byte, 5) //用一个带缓冲的channel构造一个简单的队列

select {

case b = <-idle: //尝试从idle队列中读取

    …

default:  //队列空，分配一个新的buffer

        makes += 1

        b = make([]byte, size)

}
```

2. select for non-blocking send

```shell
idle:= make(chan []byte, 5) //用一个带缓冲的channel构造一个简单的队列

select {

case idle <- b: //尝试向队列中插入一个buffer

        //…

default: //队列满？

}
```



### Nil Channels

1. nil channels阻塞

对一个没有初始化的channel进行读写操作都将发生阻塞，例子如下：

```shell
package main

func main() {

        var c chan int

        <-c

}
```

```shell
$go run testnilchannel.go

fatal error: all goroutines are asleep – deadlock!
```

```go
package main

func main() {

        var c chan int

        c <- 1

}

$go 
```

```shell
run testnilchannel.go

fatal error: all goroutines are asleep – deadlock!
```

2. nil channel在select中很有用

看下面这个例子：

```go
//testnilchannel_bad.go

package main

	import "fmt"

	import "time"

func main() {

        var c1, c2 chan int = make(chan int), make(chan int)

        go func() {

                time.Sleep(time.Second * 5)

                c1 <- 5

                close(c1)

        }()

        go func() {

                time.Sleep(time.Second * 7)

                c2 <- 7

                close(c2)

        }()

        for {

                select {

                case x := <-c1:

                        fmt.Println(x)

                case x := <-c2:

                        fmt.Println(x)

                }

        }

        fmt.Println("over")

}
```



我们原本期望程序交替输出5和7两个数字，但实际的输出结果却是：

5

0

0

0

… … 0死循环

再仔细分析代码，原来select每次按case顺序evaluate：

​    – 前5s，select一直阻塞；

​    – 第5s，c1返回一个5后被close了，“case x := <-c1”这个分支返回，select输出5，并重新select

​    – 下一轮select又从“case x := <-c1”这个分支开始evaluate，由于c1被close，按照前面的知识，close的channel不会阻塞，我们会读出这个 channel对应类型的零值，这里就是0；select再次输出0；这时即便c2有值返回，程序也不会走到c2这个分支

​    – 依次类推，程序无限循环的输出0

我们利用nil channel来改进这个程序，以实现我们的意图，代码如下：

```go
//testnilchannel.go

package main

	import "fmt"

	import "time"

func main() {

        var c1, c2 chan int = make(chan int), make(chan int)

        go func() {

                time.Sleep(time.Second * 5)

                c1 <- 5

                close(c1)

        }()

        go func() {

                time.Sleep(time.Second * 7)

                c2 <- 7

                close(c2)

        }()

        for {

                select {

                case x, ok := <-c1:

                        if !ok {

                                c1 = nil

                        } else {

                                fmt.Println(x)

                        }

                case x, ok := <-c2:

                        if !ok {

                                c2 = nil

                        } else {

                                fmt.Println(x)

                        }

                }

                if c1 == nil && c2 == nil {

                        break

                }

        }

        fmt.Println("over")

}
```



$go run testnilchannel.go

5

7

over

可以看出：通过将已经关闭的channel置为nil，下次select将会阻塞在该channel上，使得select继续下面的分支evaluation。

### Timers

1. 超时机制Timeout

带超时机制的select是常规的tip，下面是示例代码，实现30s的超时select：

```go
func worker(start chan bool) {

        timeout := time.After(30 * time.Second)

        for {

                select {

                     // … do some stuff

                case <- timeout:

                    return

                }

        }

}
```

2. 心跳HeartBeart

与timeout实现类似，下面是一个简单的心跳select实现：

```go
func worker(start chan bool) {

        heartbeat := time.Tick(30 * time.Second)

        for {

                select {

                     // … do some stuff

                case <- heartbeat:

                    //… do heartbeat stuff

                }

        }

}
```



Related posts:

1. [Go程序设计语言(三)](http://tonybai.com/2012/08/28/the-go-programming-language-tutorial-part3/)
2. [Go中的系统Signal处理](http://tonybai.com/2012/09/21/signal-handling-in-go/)
3. [Go程序设计语言(一)](http://tonybai.com/2012/08/23/the-go-programming-language-tutorial-part1/)
4. [Go与C语言的互操作](http://tonybai.com/2012/09/26/interoperability-between-go-and-c/)
5. [Go程序设计语言(二)](http://tonybai.com/2012/08/27/the-go-programming-language-tutorial-part2/)