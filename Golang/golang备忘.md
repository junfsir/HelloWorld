1. **指针**

	指针是一种存储变量内存地址（Memory Address）的变量；
	指针变量的类型为 *T，该指针指向一个 T 类型的变量；
	& 操作符用于获取变量的地址；
	
	* 号用于指定变量是作为一个指针；
	  在指针类型前面加上 * 号（前缀）来获取指针所指向的内容；
	& 仅用于生成其操作数对应的地址，也就是用于生成指针；
	* 会出现在两个内容上：
		一个是类型， * Type 这样的格式代表了一个指针类型；
		一个是指针， * Pointer 这样的格式用于获取指针所对应的基本值；

	2. **数据结构**

```shell
[]string{}：空数组
[]T：切片
[#]T：数组
interface{}，它表示空interface，按照Golang的Duck Type继承方式，任何类都是空接口的子类；
作为函数参数时，Array传递的是数组的副本，而Slice传递的是指针；

struct{}：空类型和其他类型一样，是一个结构类型，不会占用存储空间

struct{}：一种类型，即是结构体类型；
struct{}{}：是一个空结构体以默认的方式生成的实例；
```

3. **常用的值类型和引用类型**

| Value Types | Reference Types |
| :---------: | :-------------: |
|     int     |     slices      |
|    float    |      maps       |
|   string    |    channels     |
|    bool     |    pointers     |
|   structs   |    functions    |

4. **什么情况下使用指针：**

- 如果receiver是`map`、`func`或者`chan`，不要使用指针
- 如果receiver是`slice`并且该函数并不会修改此slice，不要使用指针
- 如果该函数会修改receiver，此时一定要用指针
- 如果receiver是`struct`并且包含互斥类型`sync.Mutex`，或者是类似的同步变量，receiver必须是指针，这样可以避免对象拷贝
- 如果receiver是较大的`struct`或者`array`，使用指针则更加高效。多大才算大？假设struct内所有成员都要作为函数变量传进去，如果觉得这时数据太多，就是struct太大
- 如果receiver是`struct`，`array`或者`slice`，并且其中某个element指向了某个可变量，则这个时候receiver选指针会使代码的意图更加明显
- 如果receiver使较小的`struct`或者`array`，并且其变量都是些不变量、常量，例如`time.Time`，value receiver更加适合，因为value receiver可以减少需要回收的垃圾量。
- **最后，如果不确定用哪个，使用指针类的receiver**

5. **sync标准库**

> 	sync.WaitGroup：在所有goroutine执行完成之前，阻塞主线程的执行；
> 	sync.Mutex和sync.RWMutex：为临界区添加互斥锁；

6. **context**

控制并发有两种经典的方式，一种是WaitGroup，另外一种就是Context；

WaitGroup是一种控制并发的方式，控制多个goroutine同时完成；尤其适用于，好多个goroutine协同做一件事情的时候，因为每个goroutine做的都是这件事情的一部分，只有全部的goroutine都完成，这件事情才算是完成，这是等待的方式；

Context，称之为上下文，是goroutine的上下文；

7. **解决包下载问题**

```shell
$ go get -v github.com/gohugoio/hugo
github.com/gohugoio/hugo (download)
...
github.com/spf13/nitro (download)
Fetching https://golang.org/x/sync/errgroup?go-get=1
https fetch failed: Get https://golang.org/x/sync/errgroup?go-get=1: dial tcp 216.239.37.1:443: connectex: A connection attempt failed because the connected party did not properly respond after a period of time, or established connection failed because connected host has failed to respond.
package golang.org/x/sync/errgroup: unrecognized import path "golang.org/x/sync/errgroup" (https fetch: Get https://golang.org/x/sync/errgroup?go-get=1: dial tcp 216.239.37.1:443: connectex: A connection attempt failed because the connected party did not properly respond after a period of time, or established connection failed because connected host has failed to respond.)
github.com/cpuguy83/go-md2man (download)
github.com/spf13/fsync (download)
```

解决思路：

在`$GOPATH/src`路径下创建`golang/x`，`cd`到指定路径下`git`即可；

```shell
mkidr -p ~/go/src/golang.org/x
cd ~/go/src/golang.org/x
git clone https://github.com/golang/sync.git
go get -v github.com/gohugoio/hugo
```









​	从GitHub下载依赖包到src，一般是$GOPATH的src目录，$GOROOT是go的安装目录；
​		go get github.com/gorilla/websocket
​	从GitHub下载源码修改后，编译时先将vender下的代码包拷贝到src目录下；

---

> 编译 Go 程序时，编译器只会关注那些直接被引用的库，而不是像 Java、C 和 C++那样，要遍历依赖链中所有依赖的库。

>  Go 语言的并发同步模型来自一个叫作通信顺序进程（Communicating Sequential Processes，CSP）的范型（paradigm）。CSP 是一种消息传递模型，通过在 goroutine 之间传递数据来传递消息，而不是
> 对数据进行加锁来实现同步访问。用于在 goroutine 之间同步和传递数据的关键数据类型叫作通道（channel）。

>  main 函数保存在名为 main 的包里。如果 main 函数不在 main 包里，构建工具就不会生成可执行的文件。

> 个包定义一组编译过的代码，包的名字类似命名空间，可以用来间接访问包内声明的标识符。

> import package时使用下划线'_'：
>
> 让 Go 语言对包做初始化操作，但是并不使用包里的标识符。为了让程序的可读性更强，Go 编译器不允许声明导入某个包却不使用。下划线让编译器接受这类导入，并且调用对应包内的所有代码文件里定义的 init 函数。

> 在 Go 语言中，所有变量都被初始化为其零值。对于数值类型，零值是 0；对于字符串类型，零值是空字符串；对于布尔类型，零值是 false；对于指针，零值是 nil。对于引用类型来说，
> 所引用的底层数据结构会被初始化为对应的零值。但是被声明为其零值的引用类型的变量，会返回 nil 作为其值。

> 在 Go 语言里，标识符要么从包里公开，要么不从包里公开。当代码导入了一个包时，程序可以直接访问这个包中任意一个公开的标识符。这些标识符以大写字母开头。以小写字母开头的标识符是不公开的，不能被其他包中的代码直接访问。但是，其他包可以间接访问不公开的标识符。例如，一个函数可以返回一个未公开类型的值，那么这个函数的任何调用者，哪怕调用者不是在这个包里声明的，都可以访问这个值。

> $ godoc fmt：获取包的使用细节；
>
> $ go get：获取任意指定的 URL 的包，或者一个已经导入的包所依赖的其他包；
>
> $ go build hello.go：编译生成可执行文件；
>
> $ go clean hello.go：清理编译生成的可执行文件；
>
> $ go vet main.go：检测代码的常见错误；
>
> $ go fmt main.go：格式化代码；
>
> 

> 每个包可以包含任意多个 init 函数，这些函数都会在程序执行开始的时候被调用。所有被编译器发现的 init 函数都会安排在 main 函数之前执行。init 函数用在设置包、初始化变量或者其他要在程序运行前优先完成的引导工作。

> Go 语言有 3 种数据结构可以让用户管理集合数据：数组、切片和映射。
>
> 数组是一段连续分配的内存空间；
>
> 切片是围绕动态数组的概念构建的，可以按需自动增长和缩小。

> Go 语言是一种静态类型的编程语言。这意味着，编译器需要在编译时知晓程序里每个值的类型。如果提前知道类型信息，编译器就可以确保程序合理地使用值。这有助于减少潜在的内存异常和 bug，并且使编译器有机会对代码进行一些性能优化，提高执行效率。
>
> 值的类型给编译器提供两部分信息：第一部分，需要分配多少内存给这个值（即值的规模）；第二部分，这段内存表示什么。对于许多内置类型的情况来说，规模和表示是类型名的一部分。int64 类型的值需要 8 字节（64 位），表示一个整数值；float32 类型的值需要 4 字节（32 位），表示一个 IEEE-754 定义的二进制浮点数；bool 类型的值需要 1 字节（8 位），表示布尔值 true和 false。


