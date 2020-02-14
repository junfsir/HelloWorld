**1. 在go语言中，new和make的区别？**

> new 的作用是初始化一个指向类型的指针(*T)
>
> new函数是内建函数，函数定义：func new(Type) *Type
>
> 使用new函数来分配空间；传递给`new` 函数的是一个类型，不是一个值；返回值是 指向这个新分配的零值的指针；

> make 的作用是为 slice，map 或 chan 初始化并返回引用(T)；
>
> make函数是内建函数，函数定义：func make(Type, size IntegerType) Type
>
> ·    第一个参数是一个类型，第二个参数是长度
>
> ·    返回值是一个类型
>
> `make(T, args)`函数的目的与`new(T)`不同；它仅仅用于创建 Slice, Map 和 Channel，并且返回类型是 T（不是T*）的一个初始化的（不是零值）的实例；

**2. 在go语言中，Printf()、Sprintf()、Fprintf()函数的区别用法是什么？**

> 都是把格式好的字符串输出，只是输出的目标不一样：
>
> Printf()，是把格式字符串输出到标准输出（一般是屏幕，可以重定向）；
>
> Printf() 是和标准输出文件(stdout)关联的,Fprintf 则没有这个限制；
>
> Sprintf()，是把格式字符串输出到指定字符串中，所以参数比printf多一个char*；那就是目标字符串地址；
>
> Fprintf()， 是把格式字符串输出到指定文件设备中，所以参数笔printf多一个文件指针FILE*；主要用于文件操作；Fprintf()是格式化输出到一个stream，通常是到文件；

**3. 说说go语言中，数组与切片的区别？**

> (1). 数组
> 数组是具有固定长度且拥有零个或者多个相同数据类型元素的序列。
> 数组的长度是数组类型的一部分，所以[3]int 和 [4]int 是两种不同的数组类型。
>
> 数组需要指定大小，不指定也会根据初始化的自动推算出大小，不可改变 ;
>
> 数组是值传递;
>
> 数组是内置(build-in)类型,是一组同类型数据的集合，它是值类型，通过从0开始的下标索引访问元素值。在初始化后长度是固定的，无法修改其长度。当作为方法的参数传入时将复制一份数组而不是引用同一指针。数组的长度也是其类型的一部分，通过内置函数len(array)获取其长度。
>
>  数组定义：var array [10]int
>
> ​      var array = [5]int{1,2,3,4,5}

 

> (2). 切片
> 切片表示一个拥有相同类型元素的可变长度的序列。
> 切片是一种轻量级的数据结构，它有三个属性：指针、长度和容量。
>
> 切片不需要指定大小；
>
> 切片是地址传递；
>
> 切片可以通过数组来初始化，也可以通过内置函数make()初始化 .初始化时len=cap,在追加元素时如果容量cap不足时将按len的2倍扩容；
>
> 切片定义：var slice []type = make([]type, len)

**4. 解释以下命令的作用？**

> go env:  #用于查看go的环境变量
>
> go run:  #用于编译并运行go源码文件
>
> go build: #用于编译源码文件、代码包、依赖包
>
> go get:  #用于动态获取远程代码包
>
> go install: #用于编译go文件，并将编译结构安装到bin、pkg目录
>
> go clean: #用于清理工作目录，删除编译和安装遗留的目标文件
>
> go version: #用于查看go的版本信息

**5. 说说go语言中的协程？**

> 协程和线程都可以实现程序的并发执行；
>
> 通过channel来进行协程间的通信；
>
> 只需要在函数调用前添加go关键字即可实现go的协程，创建并发任务；
>
> 关键字go并非执行并发任务，而是创建一个并发任务单元；

 

**6. 说说go语言中的for循环？**

> for循环支持continue和break来控制循环，但是它提供了一个更高级的break，可以选择中断哪一个循环
> for循环不支持以逗号为间隔的多个赋值语句，必须使用平行赋值的方式来初始化多个变量 

 

**7. 说说go语言中的switch语句？**

> 单个case中，可以出现多个结果选项
>
> 只有在case中明确添加fallthrough关键字，才会继续执行紧跟的下一个case

 

**8. go语言中没有隐藏的this指针，这句话是什么意思？**

> 方法施加的对象显式传递，没有被隐藏起来
>
> golang的面向对象表达更直观，对于面向过程只是换了一种语法形式来表达
>
> 方法施加的对象不需要非得是指针，也不用非得叫this

 **9. go语言中的引用类型包含哪些？**

> 数组切片、字典(map)、通道（channel）、接口（interface）

 

**10. go语言中指针运算有哪些？**

> 可以通过“&”取指针的地址
>
> 可以通过“*”取指针指向的数据

 

**11.说说go语言的main函数**

> main函数不能带参数
>
> main函数不能定义返回值
>
> main函数所在的包必须为main包
>
> main函数中可以使用flag包来获取和解析命令行参数

 

**12. 说说go语言的同步锁？**

> (1) 当一个goroutine获得了Mutex后，其他goroutine就只能乖乖的等待，除非该goroutine释放这个Mutex
>
> (2) RWMutex在读锁占用的情况下，会阻止写，但不阻止读
>
> (3) RWMutex在写锁占用情况下，会阻止任何其他goroutine（无论读和写）进来，整个锁相当于由该goroutine独占

 

**13. 说说go语言的channel特性？**

> A. 给一个 nil channel 发送数据，造成永远阻塞
>
> B. 从一个 nil channel 接收数据，造成永远阻塞
>
> C. 给一个已经关闭的 channel 发送数据，引起 panic
>
> D. 从一个已经关闭的 channel 接收数据，如果缓冲区中为空，则返回一个零值
>
> E. 无缓冲的channel是同步的，而有缓冲的channel是非同步的

 

**14. go语言触发异常的场景有哪些？**

> A. 空指针解析
>
> B. 下标越界
>
> C. 除数为0
>
> D. 调用panic函数

 

**15. 说说go语言的beego框架？**

> A. beego是一个golang实现的轻量级HTTP框架
>
> B. beego可以通过注释路由、正则路由等多种方式完成url路由注入
>
> C. 可以使用bee new工具生成空工程，然后使用bee run命令自动热编译

 

**16. 说说go语言的goconvey框架？**

> A. goconvey是一个支持golang的单元测试框架
>
> B. goconvey能够自动监控文件修改并启动测试，并可以将测试结果实时输出到web界面
>
> C. goconvey提供了丰富的断言简化测试用例的编写

 

**17. go语言中，GoStub的作用是什么？**

> A. GoStub可以对全局变量打桩
>
> B. GoStub可以对函数打桩
>
> C. GoStub不可以对类的成员方法打桩
>
> D. GoStub可以打动态桩，比如对一个函数打桩后，多次调用该函数会有不同的行为

 

**18. 说说go语言的select机制？**

> A. select机制用来处理异步IO问题
>
> B. select机制最大的一条限制就是每个case语句里必须是一个IO操作
>
> C. golang在语言级别支持select关键字

 

**19. 说说进程、线程、协程之间的区别？**

> 进程是资源的分配和调度的一个独立单元，而线程是CPU调度的基本单元；
>
> 同一个进程中可以包括多个线程；
>
> 进程结束后它拥有的所有线程都将销毁，而线程的结束不会影响同个进程中的其他线程的结束；
>
> 线程共享整个进程的资源（寄存器、堆栈、上下文），一个进程至少包括一个线程；
>
> 进程的创建调用fork或者vfork，而线程的创建调用pthread_create；
>
> 线程中执行时一般都要进行同步和互斥，因为他们共享同一进程的所有资源；

> 进程是资源分配的单位 
>
> 线程是操作系统调度的单位 
>
> 进程切换需要的资源很最大，效率很低 
>
> 线程切换需要的资源一般，效率一般 
> 协程切换任务资源很小，效率高 
> 多进程、多线程根据cpu核数不一样可能是并行的 也可能是并发的。协程的本质就是使用当前进程在不同的函数代码中切换执行，可以理解为并行。 协程是一个用户层面的概念，不同协程的模型实现可能是单线程，也可能是多线程。

> 进程拥有自己独立的堆和栈，既不共享堆，亦不共享栈，进程由操作系统调度。（全局变量保存在堆中，局部变量及函数保存在栈中）
>
> 线程拥有自己独立的栈和共享的堆，共享堆，不共享栈，线程亦由操作系统调度(标准线程是这样的)。
>
> 协程和线程一样共享堆，不共享栈，协程由程序员在协程的代码里显示调度。
>
> 一个应用程序一般对应一个进程，一个进程一般有一个主线程，还有若干个辅助线程，线程之间是平行运行的，在线程里面可以开启协程，让程序在特定的时间内运行。
>
> 协程和线程的区别是：协程避免了无意义的调度，由此可以提高性能，但也因此，程序员必须自己承担调度的责任，同时，协程也失去了标准线程使用多CPU的能力。

---

1. 写出下面代码输出内容；

```go
package main

import (
	"fmt"
)

func main() {
	defer_call()
}

func defer_call() {
	defer func() { fmt.Println("打印前") }()
	defer func() { fmt.Println("打印中") }()
	defer func() { fmt.Println("打印后") }()

	panic("触发异常")
}
```

> 考点：defer执行顺序
> 解答：
> defer 是后进先出。
> panic 需要等defer 结束后才会向上传递。 出现panic恐慌时候，会先按照defer的后入先出的顺序执行，最后才会执行panic。
>
> 打印后
> 打印中
> 打印前
> panic: 触发异常

2. [以下代码有什么问题，说明原因](https://learnku.com/articles/26861)；

```go
type student struct {
    Name string
    Age  int
}

func pase_student() {
    m := make(map[string]*student)
    stus := []student{
        {Name: "zhou", Age: 24},
        {Name: "li", Age: 23},
        {Name: "wang", Age: 22},
    }
    for _, stu := range stus {
        m[stu.Name] = &stu
    }

}
```

> 考点：foreach
> 解答：
> 这样的写法初学者经常会遇到的，很危险！ 与Java的foreach一样，都是使用副本的方式。所以m[stu.Name]=&stu实际上一致指向同一个指针， 最终该指针的值为遍历的最后一个struct的值拷贝。 就像想修改切片元素的属性：
>
> ```go
> for _, stu := range stus {
>     stu.Age = stu.Age+10
> }
> ```
>
> 也是不可行的。 大家可以试试打印出来：
>
> ```go
> func pase_student() {
>     m := make(map[string]*student)
>     stus := []student{
>         {Name: "zhou", Age: 24},
>         {Name: "li", Age: 23},
>         {Name: "wang", Age: 22},
>     }        // 错误写法
>     for _, stu := range stus {
>         m[stu.Name] = &stu
>     }         for k,v:=range m{              println(k,"=>",v.Name)
>     }          // 正确
>     for i:=0;i<len(stus);i++  {
>         m[stus[i].Name] = &stus[i]
>     }         for k,v:=range m{               println(k,"=>",v.Name)
>     }
> }
> ```

3. 下面的代码会输出什么，并说明原因

```go
package main

import (
	"fmt"
	"runtime"
	"sync"
)

func main() {
	runtime.GOMAXPROCS(1)
	wg := sync.WaitGroup{}
	wg.Add(20)
	for i := 0; i < 10; i++ {
		go func() {
			fmt.Println("A: ", i)
			wg.Done()
		}()
	}
	for i := 0; i < 10; i++ {
		go func(i int) {
			fmt.Println("B: ",i)
			wg.Done()
		}(i)
	}
	wg.Wait()
}
```

> 考点：go执行的随机性和闭包
> 解答：
> 谁也不知道执行后打印的顺序是什么样的，所以只能说是随机数字。 但是A:均为输出10，B:从0~9输出(顺序不定)。 第一个go func中i是外部for的一个变量，地址不变化。遍历完成后，最终i=10。 故go func执行时，i的值始终是10。
>
> 第二个go func中i是函数参数，与外部for中的i完全是两个变量。 尾部(i)将发生值拷贝，go func内部指向值拷贝地址。

4. 下面代码会输出什么

```go
type People struct{}
func (p *People) ShowA() {
    fmt.Println("showA")
    p.ShowB()
}
func (p *People) ShowB() {
    fmt.Println("showB")
}
type Teacher struct {
    People
}
func (t *Teacher) ShowB() {
    fmt.Println("teacher showB")
}
func main() {
    t := Teacher{}
    t.ShowA()
}
```

> 考点：go的组合继承
> 解答：
> 这是Golang的组合模式，可以实现OOP的继承。 被组合的类型People所包含的方法虽然升级成了外部类型Teacher这个组合类型的方法（一定要是匿名字段），但它们的方法(ShowA())调用时接受者并没有发生变化。 此时People类型并不知道自己会被什么类型组合，当然也就无法调用方法时去使用未知的组合者Teacher类型的功能。
>
> ```
> showA
> showB
> ```

5. 下面代码会触发异常吗？请详细说明

```go
func main() {
    runtime.GOMAXPROCS(1)
    int_chan := make(chan int, 1)
    string_chan := make(chan string, 1)
    int_chan <- 1
    string_chan <- "hello"
    select {    
        case value := <-int_chan:
            fmt.Println(value)
        case value := <-string_chan:        
            panic(value)
    }
}
```

> 考点：select随机性
> 解答：
> select会随机选择一个可用通用做收发操作。 所以代码是有可能触发异常，也有可能不会。 单个chan如果无缓冲时，将会阻塞。但结合 select可以在多个chan间等待执行。有三点原则：
>
> select 中只要有一个case能return，则立刻执行。
> 当如果同一时间有多个case均能return则伪随机方式抽取任意一个执行。
> 如果没有一个case能return则可以执行”default”块。

6. 下面代码会输出什么

```go
func calc(index string, a, b int) int {
    ret := a + b
    fmt.Println(index, a, b, ret)
    return ret
}

func main() {    
    a := 1
    b := 2
    defer calc("1", a, calc("10", a, b))    a = 0
    defer calc("2", a, calc("20", a, b))    b = 1

}
```

> 考点：defer执行顺序
> 解答：
> 这道题类似第1题 需要注意到defer执行顺序和值传递 index:1肯定是最后执行的，但是index:1的第三个参数是一个函数，所以最先被调用calc("10",1,2)==>10,1,2,3 执行index:2时,与之前一样，需要先调用calc("20",0,2)==>20,0,2,2 执行到b=1时候开始调用，index:2==>calc("2",0,2)==>2,0,2,2 最后执行index:1==>calc("1",1,3)==>1,1,3,4
>
> ```
> 10 1 2 320 0 2 22 0 2 21 1 3 4
> ```

7. 请写出以下输出内容

```go
func main() {    
    s := make([]int, 5)
    s = append(s, 1, 2, 3)
    fmt.Println(s)
}
```

> 考点：make默认值和append
> 解答：
> make初始化是有默认值的，此处默认值为0
>
> [0 0 0 0 0 1 2 3]
> 大家试试改为:
>
> ```
> s := make([]int, 0)
> s = append(s, 1, 2, 3)
> fmt.Println(s)//[1 2 3]
> ```

8. 下面代码有什么问题

```go
type UserAges struct {
	ages map[string]int
	sync.Mutex
}
func (ua *UserAges) Add(name string, age int) {
	ua.Lock()	
    defer ua.Unlock()
	ua.ages[name] = age
}
func (ua *UserAges) Get(name string) int {	
      if age, ok := ua.ages[name]; ok {		
         return age
	}	
      return -1

}
```

> 考点：map线程安全
> 解答：
> 可能会出现fatal error: concurrent map read and map write. 修改一下看看效果
>
> ```
> func (ua *UserAges) Get(name string) int {
>     ua.Lock()         
>     defer ua.Unlock()          
>     if age, ok := ua.ages[name]; ok {                 
>         return age
>     }          
>     return -1
> }
> ```

9. 下面迭代有什么问题

```go
func (set *threadSafeSet) Iter() <-chan interface{} {
	ch := make(chan interface{})	
    go func() {
		set.RLock()		
        for elem := range set.s {
			ch <- elem
		}		
        close(ch)
		set.RUnlock()

	}()	
    return ch
}
```

> 考点：chan缓存池
> 解答：
> 看到这道题，我也在猜想出题者的意图在哪里。 chan?sync.RWMutex?go?chan缓存池?迭代? 所以只能再读一次题目，就从迭代入手看看。 既然是迭代就会要求set.s全部可以遍历一次。但是chan是为缓存的，那就代表这写入一次就会阻塞。 我们把代码恢复为可以运行的方式，看看效果
>
> ```
> package main
> import (          
>     "sync"
>     "fmt"
> )
> //下面的迭代会有什么问题？
> type threadSafeSet struct {
>     sync.RWMutex
>     s []interface{}
> }
> func (set *threadSafeSet) Iter() <-chan interface{} {    
> // ch := make(chan interface{}) 
> // 解除注释看看！
>     ch := make(chan interface{},len(set.s))   
>     go func() {
>         set.RLock()        
>         for elem,value := range set.s {
>             ch <- elem            
>             println("Iter:",elem,value)
>         }        
>         close(ch)
>         set.RUnlock()
>     }()    
>     return ch
> }
> func main()  {
> 
>     th:=threadSafeSet{
>         s:[]interface{}{"1","2"},
>     }
>     v:=<-th.Iter()
>     fmt.Sprintf("%s%v","ch",v)
> }
> ```

10. 以下代码能否编译通过？为什么

```go
package main

import ("fmt")
type People interface {
	Speak(string) string
}
type Stduent struct{}

func (stu *Stduent) Speak(think string) (talk string) {	
if think == "bitch" {
		talk = "You are a good boy"
	} else {
		talk = "hi"
	}
	return
}

func main() {
	var peo People = Stduent{}
	think := "bitch"
	fmt.Println(peo.Speak(think))
}
```

> 考点：golang的方法集
> 解答：
> 编译不通过！ 做错了！？说明你对golang的方法集还有一些疑问。 一句话：golang的方法集仅仅影响接口实现和方法表达式转化，与通过实例或者指针调用方法无关。

11. 以下代码的打印结果，并说明原因

```go
package main

import ("fmt")
type People interface {
	Show()
}
type Student struct{}

func (stu *Student) Show() {

}

func live() People {
	var stu *Student
	return stu
}

func main() {	if live() == nil 
{
		fmt.Println("AAAAAAA")
	} else {
		fmt.Println("BBBBBBB")
	}
}
```

> 考点：interface内部结构
> 解答：
> 很经典的题！ 这个考点是很多人忽略的interface内部结构。 go中的接口分为两种一种是空的接口类似这样：
>
> `var in interface{}`
> 另一种如题目：
>
> ```
> type People interface {
>     Show()
> }
> ```
>
> 他们的底层结构如下：
>
> ```go
> type eface struct {      //空接口
>     _type *_type         //类型信息
>     data  unsafe.Pointer //指向数据的指针(go语言中特殊的指针类型unsafe.Pointer类似于c语言中的void*)}type iface struct {      //带有方法的接口
>     tab  *itab           //存储type信息还有结构实现方法的集合
>     data unsafe.Pointer  //指向数据的指针(go语言中特殊的指针类型unsafe.Pointer类似于c语言中的void*)}type _type struct {
>     size       uintptr  //类型大小
>     ptrdata    uintptr  //前缀持有所有指针的内存大小
>     hash       uint32   //数据hash值
>     tflag      tflag
>     align      uint8    //对齐
>     fieldalign uint8    //嵌入结构体时的对齐
>     kind       uint8    //kind 有些枚举值kind等于0是无效的
>     alg        *typeAlg //函数指针数组，类型实现的所有方法
>     gcdata    *byte    str       nameOff
>     ptrToThis typeOff
> }type itab struct {
>     inter  *interfacetype  //接口类型
>     _type  *_type          //结构类型
>     link   *itab
>     bad    int32
>     inhash int32
>     fun    [1]uintptr      //可变大小 方法集合}
> ```
>
> 可以看出iface比eface 中间多了一层itab结构。 itab 存储_type信息和[]fun方法集，从上面的结构我们就可得出，因为data指向了nil 并不代表interface 是nil， 所以返回值并不为空，这里的fun(方法集)定义了接口的接收规则，在编译的过程中需要验证是否实现接口 结果：
>
> BBBBBBB

12. 是否可以编译通过？如果通过，输出什么？

```go
func main() {
	i := GetValue()	switch i.(type) {	
        case int:		
        println("int")	
        case string:		
        println("string")	
        case interface{}:		
        println("interface")	
        default:		
         println("unknown")
	}

}
func GetValue() int {	
return 1

}
```

> 考点：type
>
> 编译失败，因为type只能使用在interface

13. 下面函数有什么问题

```go
func funcMui(x,y int)(sum int,error){    return x+y,nil}
```

> 考点：函数返回值命名
> 在函数有多个返回值时，只要有一个返回值有指定命名，其他的也必须有命名。 如果返回值有有多个返回值必须加上括号； 如果只有一个返回值并且有命名也需要加上括号； 此处函数第一个返回值有sum名称，第二个未命名，所以错误。

14. 是否可以编译通过？如果通过，输出什么？

```go
package mainfunc main() {	println(DeferFunc1(1))	println(DeferFunc2(1))	println(DeferFunc3(1))
}func DeferFunc1(i int) (t int) {
	t = i	defer func() {
		t += 3
	}()	return t
}func DeferFunc2(i int) int {
	t := i	defer func() {
		t += 3
	}()	return t
}func DeferFunc3(i int) (t int) {	defer func() {
		t += i
	}()	return 2}
```

> 考点:defer和函数返回值
> 需要明确一点是defer需要在函数结束前执行。 函数返回值名字会在函数起始处被初始化为对应类型的零值并且作用域为整个函数 DeferFunc1有函数返回值t作用域为整个函数，在return之前defer会被执行，所以t会被修改，返回4; DeferFunc2函数中t的作用域为函数，返回1; DeferFunc3返回3

15. 是否可以编译通过？如果通过，输出什么？

```go
func main() {	list := new([]int)
	list = append(list, 1)
	fmt.Println(list)
}
```

> 考点：new
> `list:=make([]int,0)`

16. 是否可以编译通过？如果通过，输出什么？

```go
package mainimport "fmt"func main() {
	s1 := []int{1, 2, 3}
	s2 := []int{4, 5}
	s1 = append(s1, s2)
	fmt.Println(s1)
}
```

> 考点：append
> append切片时候别漏了'...'

17. 是否可以编译通过？如果通过，输出什么？

```go
func main() {

	sn1 := struct {
		age  int
		name string
	}{age: 11, name: "qq"}
	sn2 := struct {
		age  int
		name string
	}{age: 11, name: "qq"}	if sn1 == sn2 {
		fmt.Println("sn1 == sn2")
	}

	sm1 := struct {
		age int
		m   map[string]string
	}{age: 11, m: map[string]string{"a": "1"}}
	sm2 := struct {
		age int
		m   map[string]string
	}{age: 11, m: map[string]string{"a": "1"}}	
            if sm1 == sm2 {
		fmt.Println("sm1 == sm2")
	}
}
```

> 考点:结构体比较
> 进行结构体比较时候，只有相同类型的结构体才可以比较，结构体是否相同不但与属性类型个数有关，还与属性顺序相关。
>
> ```
> sn3:= struct {
>     name string
>     age  int}{age:11,name:"qq"}
> ```
>
> sn3与sn1就不是相同的结构体了，不能比较。 还有一点需要注意的是结构体是相同的，但是结构体属性中有不可以比较的类型，如map,slice。 如果该结构属性都是可以比较的，那么就可以使用“==”进行比较操作。
>
> 可以使用reflect.DeepEqual进行比较
>
> ```
> if reflect.DeepEqual(sn1, sm) {
>     fmt.Println("sn1 ==sm")
> }else {
>     fmt.Println("sn1 !=sm")
> }
> ```
>
> 所以编译不通过： `invalid operation: sm1 == sm2`

18. 是否可以编译通过？如果通过，输出什么？

```go
func Foo(x interface{}) {
	if x == nil {
		fmt.Println("empty interface")
		return
	}
	fmt.Println("non-empty interface")
}

func main() {
	var x *int = nil
	Foo(x)
}
```

> 考点：interface内部结构
>
> ```
> non-empty interface
> ```

19. 是否可以编译通过？如果通过，输出什么？

```go
func GetValue(m map[int]string, id int) (string, bool) {
	if _, exist := m[id]; exist {
		return "存在数据", true
	}
	return nil, false
}

func main() {
	intmap := map[int]string {
		1:"a",
		2:"bb",
		3:"ccc",
	}
	v,err := GetValue(intmap,3)
	fmt.Println(v,err)
}
```

> 考点：函数返回值类型
> nil 可以用作 interface、function、pointer、map、slice 和 channel 的“空值”。但是如果不特别指定的话，Go 语言不能识别类型，所以会报错。报:cannot use nil as type string in return argument.

20. 是否可以编译通过？如果通过，输出什么？

```go
const (
	x = iota
	y
	z = "zz"
	k
	p = iota)
func main() {
	fmt.Println(x,y,z,k,p)
}
```

> 考点：iota
> 结果:
>
> 0 1 zz zz 4

21. 编译下面代码会出现什么

```go
package main
var (
    size := 1024
    max_size = size*2
)
func main()  {    
    println(size,max_size)
}
```

> 考点:变量简短模式
> 变量简短模式限制：
>
> 定义变量同时显式初始化
> 不能提供数据类型
> 只能在函数内部使用
> 结果：
>
> syntax error: unexpected :=

22. 下面函数有什么问题

```go
package main

const cl  = 100
var bl = 123

func main()  {    
    println(&bl,bl)    
    println(&cl,cl)
}
```

> 考点:常量
> 常量不同于变量的在运行时分配内存，常量通常会被编译器在预处理阶段直接展开，作为指令数据使用，
>
> ```
> cannot take the address of cl
> ```

23. 编译下面代码会出现什么

```go
package main

func main() {
	for i := 0; i < 10; i++ {
		loop:
		println(i)
	}
	goto loop
}
```

> 考点：goto
> goto不能跳转到其他函数或者内层代码
>
> ```
> goto loop jumps into block starting at
> ```

24. 编译下面代码会出现什么

```go
package main

import "fmt"

func main()  {    
    type MyInt1 int    
    type MyInt2 = int
    var i int = 9
    var i1 MyInt1 = i
    var i2 MyInt2 = i
    fmt.Println(i1,i2)
}
```

> 考点：**Go 1.9 新特性 Type Alias **
> 基于一个类型创建一个新类型，称之为defintion；基于一个类型创建一个别名，称之为alias。 MyInt1为称之为defintion，虽然底层类型为int类型，但是不能直接赋值，需要强转； MyInt2称之为alias，可以直接赋值。
>
> 结果:
>
> ```
> cannot use i (type int) as type MyInt1 in assignment
> ```

25. 编译下面代码会出现什么

```go
package main
import "fmt"

type User struct {}
type MyUser1 User
type MyUser2 = User
 
func (i MyUser1) m1(){
    fmt.Println("MyUser1.m1")
}
func (i User) m2(){
    fmt.Println("User.m2")
}

func main() {
    var i1 MyUser1
    var i2 MyUser2
    i1.m1()
    i2.m2()
}
```

> 考点：**Go 1.9 新特性 Type Alias **
> 因为MyUser2完全等价于User，所以具有其所有的方法，并且其中一个新增了方法，另外一个也会有。 但是
>
> `i1.m2()`
> 是不能执行的，因为MyUser1没有定义该方法。 结果:
>
> ```
> MyUser1.m1User.m2
> ```

26. 编译下面代码会出现什么

```go
package main

import "fmt"

type T1 struct {}
func (t T1) m1() {
    fmt.Println("T1.m1")
}
type T2 = T1
type MyStruct struct {
    T1
    T2
}
func main() {
    my := MyStruct{}
    my.m1()
}
```

> 考点：**Go 1.9 新特性 Type Alias **
> 是不能正常编译的,异常：
>
> `ambiguous selector my.m1`
> 结果不限于方法，字段也也一样；也不限于type alias，type defintion也是一样的，只要有重复的方法、字段，就会有这种提示，因为不知道该选择哪个。 改为:
>
> ```
> my.T1.m1()
> my.T2.m1()
> ```
>
> type alias的定义，本质上是一样的类型，只是起了一个别名，源类型怎么用，别名类型也怎么用，保留源类型的所有方法、字段等。

27. 编译下面代码会出现什么

```go
package main

import (
	"errors"
	"fmt"
)

var ErrDidNotwork = errors.New("did not work")
func DoTheThing(reallyDoIt bool) (err error) {
	if reallyDoIt {
		result, err := tryTheThing()
		if err != nil || result != "it worked" {
			err = ErrDidNotwork
		}
	}
	return err
}

func tryTheThing() (string,error) {
	return "", ErrDidNotwork
}

func main() {
	fmt.Println(DoTheThing(true))
	fmt.Println(DoTheThing(false))
}
```

```go
考点：变量作用域
因为 if 语句块内的 err 变量会遮罩函数作用域内的 err 变量，结果：

改为：

func DoTheThing(reallyDoIt bool) (err error) {
	var result string
	if reallyDoIt {
		result, err = tryTheThing()
		if err != nil || result != "it worked" {
			err = ErrDidNotwork
		}
	}
	return err
}

```

28. 编译下面代码会出现什么

```go
package main 

func test() []func() {
	var funs []func()
	for i := 0; i < 2; i++ {
		funs = append(funs, func() {
			println(&i,i)
		})
	}
	return funs
}

func main() {
	funs := test()
	for _,f := range funs {
		f()
	}
}
```

> 考点：闭包延迟求值
> for循环复用局部变量i，每一次放入匿名函数的应用都是想一个变量。 结果：
>
> 0xc042046000 2
> 0xc042046000 2
> 如果想不一样可以改为：
>
> ```go
> func test() []func() {
> 	var funs []func()
> 	for i := 0; i < 2; i++ {
> 		x := i
> 		funs = append(funs, func() {
> 			println(&x,x)
> 		})
> 	}
> 	return funs
> }
> ```

29. 编译下面代码会出现什么

```go
package main 

func test(x int) (func(), func()) {
	return func() {
		println(x)
		x += 10
	}, func() {
		println(x)
	}
}

func main() {
	a,b := test(100)
	a()
	b()
}
```

> 考点：闭包引用相同变量
> 结果：
>
> 100
> 110

30. 编译下面代码会出现什么

```go
package main

import (
	"fmt"
	"reflect"
)

func main1() {
	defer func() {
		if err := recover(); err != nil {
			fmt.Println(err)
		} else {
			fmt.Println("fatal")
		}
	}()
	defer func() {
		panic("defer panic")
	}()
	panic("panic")
}

func main() {
	defer func() {
		if err := recover(); err != nil{
			fmt.Println("++++")
			f := err.(func() string)
			fmt.Println(err,f(),reflect.TypeOf(err).Kind().String())
		} else {
			fmt.Println("fatal")
		}
	}()
	defer func() {
		panic(func() string {
			return "defer panic"
		})
	}()
	panic("panic")
}
```

> 考点：panic仅有最后一个可以被revover捕获
> 触发panic("panic")后顺序执行defer，但是defer中还有一个panic，所以覆盖了之前的panic("panic")
>
> defer panic

