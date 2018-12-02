## golang的语言结构：

	包声明
	引入包
	函数
	变量
	语句 & 表达式
	注释

示例：
	
	package main

	import "fmt"

	func main(){
		/* print hello world */
		fmt.Println("hello world")
	}


	go run test.go



1、第一行代码 `package main` 定义了包名。必须在源文件中非注释的第一行指明这个文件属于哪个包，如：`package main`。`package main`表示一个可独立执行的程序，每个 Go 应用程序都包含一个名为 main 的包；
2、下一行 `import "fmt"` 告诉 Go 编译器这个程序需要使用 fmt 包（的函数，或其他元素），fmt 包实现了格式化 IO（输入/输出）的函数；
3、下一行 `func main()` 是程序开始执行的函数。main 函数是每一个可执行程序所必须包含的，一般来说都是在启动后第一个执行的函数（如果有 init() 函数则会先执行该函数）；
4、下一行 `/*...*/` 是注释，在程序执行时将被忽略。单行注释是最常见的注释形式，可以在任何地方使用以 // 开头的单行注释。多行注释也叫块注释，均已以 /* 开头，并以 */ 结尾，且不可以嵌套使用，多行注释一般用于包的文档描述或注释成块的代码片段；
5、下一行 `fmt.Println(...)` 可以将字符串输出到控制台，并在最后自动增加换行字符 \n。 

	使用 fmt.Print("hello, world\n") 可以得到相同的结果。 
	Print 和 Println 这两个函数也支持使用变量，如：fmt.Println(arr)。如果没有特别指定，它们会以默认的打印格式将变量 arr 输出到控制台。
	当标识符（包括常量、变量、类型、函数名、结构字段等等）以一个大写字母开头，如：Group1，那么使用这种形式的标识符的对象就可以被外部包的代码所使用（客户端程序需要先导入这个包），这被称为导出（像面向对象语言中的 public）；标识符如果以小写字母开头，则对包外是不可见的，但是他们在整个包的内部是可见并且可用的（像面向对象语言中的 protected ）。


## golang变量：
      var identifier type

### 声明方式：

(1) 指定变量类型，声明后若不赋值，使用默认值；

	var v_name v_type
	v_name = value
(2) 根据值自行判定变量类型；

	var v_name = value
(3) 省略var, 注意 :=左侧的变量不应该是已经声明过的，否则会导致编译错误；

	v_name := value

	// 例如
	var a int = 10
	var b = 10
	c : = 10


### 多变量声明

	//类型相同的多个变量, 非全局变量；
	var vname1, vname2, vname3 type
	vname1, vname2, vname3 = v1, v2, v3

	var vname1, vname2, vname3 = v1, v2, v3 //和python很像,不需要显示声明类型，自动推断

	vname1, vname2, vname3 := v1, v2, v3 //出现在:=左侧的变量不应该是已经被声明过的，否则会导致编译错误


	// 这种因式分解关键字的写法一般用于声明全局变量
	var (
	    vname1 v_type1
	    vname2 v_type2
	)

示例：

	package main

	var x, y int
	var (  // 这种因式分解关键字的写法一般用于声明全局变量
	    a int
	    b bool
	)

	var c, d int = 1, 2
	var e, f = 123, "hello"

	//这种不带声明格式的只能在函数体中出现
	//g, h := 123, "hello"

	func main(){
	    g, h := 123, "hello"
	    Println(x, y, a, b, c, d, e, f, g, h)
	}




*简短形式，使用 := 赋值操作符*

	可以在变量的初始化时省略变量的类型而由系统自动推断，声明语句写上 var 关键字其实是显得有些多余了，因此可以将它们简写为 a := 50 或 b := false。
	a 和 b 的类型（int 和 bool）将由编译器自动推断。
	这是使用变量的首选形式，但是它只能被用在函数体内，而不可以用于全局变量的声明与赋值。使用操作符 := 可以高效地创建一个新的变量，称之为初始化声明。

### 注意事项

如果在相同的代码块中，不可以再次对于相同名称的变量使用初始化声明，例如：*a := 20* 就是不被允许的，编译器会提示错误 *no new variables on left side of :=*，但是 *a = 20 是可以的，因为这是给相同的变量赋予一个新的值*。
如果你在定义变量 a 之前使用它，则会得到编译错误 *undefined: a*。
如果你声明了一个局部变量却没有在相同的代码块中使用它，同样会得到编译错误，例如下面这个例子当中的变量 a：

	package main

	import "fmt"

	func main() {
	   var a string = "abc"
	   fmt.Println("hello, world")
	}

尝试编译这段代码将得到错误 *a declared and not used*。此外，单纯地给 a 赋值也是不够的，*这个值必须被使用*，所以使用*fmt.Println("hello, world", a)*会移除错误。但是*全局变量是允许声明但不使用*。 
同一类型的多个变量可以声明在同一行，如：

      var a, b, c int
多变量可以在同一行进行赋值，如：

      a, b, c = 5, 7, "abc"
上面这行假设了变量 a，b 和 c 都已经被声明，否则的话应该这样使用：

      a, b, c := 5, 7, "abc"
右边的这些值以相同的顺序赋值给左边的变量，所以 a 的值是 5， b 的值是 7，c 的值是 "abc"。
这被称为 并行 或 同时 赋值。
*如果你想要交换两个变量的值，则可以简单地使用 a, b = b, a。*
*空白标识符 _ 也被用于抛弃值*，如值 5 在：*_, b = 5, 7* 中被抛弃。
*_ 实际上是一个只写变量，你不能得到它的值。这样做是因为 Golang中你必须使用所有被声明的变量，但有时你并不需要使用从一个函数得到的所有返回值。*
并行赋值也被用于当一个函数返回多个返回值时，比如这里的 val 和错误 err 是通过调用 Func1 函数同时得到：val, err = Func1(var1)。


## Golang常量

常量是一个简单值的标识符，在程序运行时，不会被修改的量。
常量中的数据类型只可以是布尔型、数字型（整数型、浮点型和复数）和字符串型。
常量的定义格式：

      const identifier [type] = value
**可以省略类型说明符 [type]，因为编译器可以根据变量的值来推断其类型。**

显式类型定义： *const b string = "abc"*
隐式类型定义： *const b = "abc"*

多个相同类型的声明可以简写为：

      const c_name1, c_name2 = value1, value2
实例：

      package main

      import "fmt"

      func main() {
         const LENGTH int = 10
         const WIDTH int = 5   
         var area int
         const a, b, c = 1, false, "str" //多重赋值

         area = LENGTH * WIDTH
         fmt.Printf("面积为 : %d", area)
         println()
         println(a, b, c)   
      }

常量还可以用作枚举：

      const (
          Unknown = 0
          Female = 1
          Male = 2
      )
数字 0、1 和 2 分别代表未知性别、女性和男性。
常量可以用*len(), cap(), unsafe.Sizeof()*常量计算表达式的值。*常量表达式中，函数必须是内置函数*，否则编译不过：

      package main

      import "unsafe"
      const (
          a = "abc"
          b = len(a)
          c = unsafe.Sizeof(a)
      )

      func main(){
          println(a, b, c)
      }

### iota
iota，特殊常量，可以认为是一个*可以被编译器修改的常量*。
*在每一个const关键字出现时，被重置为0，然后再下一个const出现之前，每出现一次iota，其所代表的数字会自动增加1。*

iota 可以被用作枚举值：

      const (
          a = iota
          b = iota
          c = iota
      )
第一个 iota 等于 0，每当 iota 在新的一行被使用时，它的值都会自动加 1；所以 a=0, b=1, c=2 可以简写为如下形式：

      const (
          a = iota
          b
          c
      )
iota 用法：

      package main

      import "fmt"

      func main() {
          const (
                  a = iota   //0
                  b          //1
                  c          //2
                  d = "ha"   //独立值，iota += 1
                  e          //"ha"   iota += 1
                  f = 100    //iota +=1
                  g          //100  iota +=1
                  h = iota   //7,恢复计数
                  i          //8
          )
          fmt.Println(a,b,c,d,e,f,g,h,i)
      }

再看个有趣的的 iota 实例：

      package main

      import "fmt"
      const (
          i=1<<iota
          j=3<<iota
          k
          l
      )

      func main() {
      	fmt.Println("i=",i)
      	fmt.Println("j=",j)
      	fmt.Println("k=",k)
      	fmt.Println("l=",l)
      }
以上实例运行结果为：

      i= 1
      j= 6
      k= 12
      l= 24
iota表示*从0开始自动加1*，所以*i=1<<0,j=3<<1*(**<<表示左移的意思**)，即：*i=1,j=6*，这没问题，关键在k和l，从输出结果看，k=3<<2，l=3<<3。



## Golang函数

Golang至少有个 main() 函数。
可以通过函数来划分不同功能，逻辑上每个函数执行的是指定的任务。
函数声明告诉编译器函数的名称，返回类型，和参数。
Golang标准库提供了多种可动用的内置的函数。例如，len() 函数可以接受不同类型参数并返回该类型的长度。如果我们传入的是字符串则返回字符串的长度，如果传入的是数组，则返回数组中包含的函数个数。

函数定义

Golang函数定义格式如下：

      func function_name( [parameter list] ) [return_types] {
         函数体
      }
函数定义解析：

      func：函数由 func 开始声明
      function_name：函数名称，函数名和参数列表一起构成了函数签名。
      parameter list：参数列表，参数就像一个占位符，当函数被调用时，你可以将值传递给参数，这个值被称为实际参数。参数列表指定的是参数类型、顺序、及参数个数。参数是可选的，也就是说函数也可以不包含参数。
      return_types：返回类型，函数返回一列值。return_types 是该列值的数据类型。有些功能不需要返回值，这种情况下 return_types 不是必须的。
      函数体：函数定义的代码集合。
实例
以下实例为 max() 函数的代码，该函数传入两个整型参数 num1 和 num2，并返回这两个参数的最大值：

      /* 函数返回两个数的最大值 */
      func max(num1, num2 int) int {
         /* 声明局部变量 */
         var result int

         if (num1 > num2) {
            result = num1
         } else {
            result = num2
         }
         return result 
      }
函数调用
当创建函数时，你定义了函数需要做什么，通过调用改函数来执行指定任务。
调用函数，向函数传递参数，并返回值，例如：

      package main

      import "fmt"

      func main() {
         /* 定义局部变量 */
         var a int = 100
         var b int = 200
         var ret int

         /* 调用函数并返回最大值 */
         ret = max(a, b)

         fmt.Printf( "最大值是 : %d\n", ret )
      }

      /* 函数返回两个数的最大值 */
      func max(num1, num2 int) int {
         /* 定义局部变量 */
         var result int

         if (num1 > num2) {
            result = num1
         } else {
            result = num2
         }
         return result 
      }

### 函数返回多个值

      package main

      import "fmt"

      func swap(x, y string) (string, string) {
         return y, x
      }

      func main() {
         a, b := swap("Mahesh", "Kumar")
         fmt.Println(a, b)
      }




## 声明数组
Golang数组声明需要指定元素类型及元素个数，语法格式如下：

      var variable_name [SIZE] variable_type
以上为一维数组的定义方式。数组长度必须是整数且大于 0。例如以下定义了数组：

      balance 长度为 10 类型为 float32：
      var balance [10] float32

### 初始化数组

      var balance = [5]float32{1000.0, 2.0, 3.4, 7.0, 50.0}
初始化数组中 {} 中的元素个数不能大于 [] 中的数字。
如果忽略 [] 中的数字不设置数组大小，Golang会根据元素的个数来设置数组的大小：

      var balance = [...]float32{1000.0, 2.0, 3.4, 7.0, 50.0}
该实例与上面的实例是一样的，虽然没有设置数组的大小。

      balance[4] = 50.0

### 访问数组元素
数组元素可以通过索引（位置）来读取。格式为数组名后加中括号，中括号中为索引的值。例如：

      float32 salary = balance[9]
以上实例读取了数组balance第10个元素的值。
以下演示了数组完整操作（声明、赋值、访问）的实例：

      package main

      import "fmt"

      func main() {
         var n [10]int /* n 是一个长度为 10 的数组 */
         var i,j int

         /* 为数组 n 初始化元素 */         
         for i = 0; i < 10; i++ {
            n[i] = i + 100 /* 设置元素为 i + 100 */
         }

         /* 输出每个数组元素的值 */
         for j = 0; j < 10; j++ {
            fmt.Printf("Element[%d] = %d\n", j, n[j] )
         }
      }





## Golang指针

Golang中使用指针可以更简单的执行一些任务。
变量是一种使用方便的占位符，用于引用计算机内存地址。
Golang的*取地址符是 &*，放到一个变量前使用就会返回相应变量的内存地址。

示例：

      package main

      import "fmt"

      func main() {
         var a int = 10   

         fmt.Printf("变量的地址: %x\n", &a  )
      }

### 什么是指针
一个指针变量可以指向任何一个值的内存地址它指向那个值的内存地址。
类似于变量和常量，在使用指针前你需要声明指针。指针声明格式如下：

      var var_name *var-type
**var-type 为指针类型，var_name 为指针变量名，* 号用于指定变量是作为一个指针。**
以下是有效的指针声明：

      var ip *int        /* 指向整型*/
      var fp *float32    /* 指向浮点型 */

指针使用流程：

      定义指针变量；
      为指针变量赋值；
      访问指针变量中指向地址的值；
      在指针类型前面加上 * 号（前缀）来获取指针所指向的内容；

      package main

      import "fmt"

      func main() {
         var a int= 20   /* 声明实际变量 */
         var ip *int        /* 声明指针变量 */

         ip = &a  /* 指针变量的存储地址 */

         fmt.Printf("a 变量的地址是: %x\n", &a  )

         /* 指针变量的存储地址 */
         fmt.Printf("ip 变量储存的指针地址: %x\n", ip )

         /* 使用指针访问值 */
         fmt.Printf("*ip 变量的值: %d\n", *ip )
      }

### Golang 空指针

当一个指针被定义后没有分配到任何变量时，它的值为 nil。
nil 指针也称为空指针。
nil在概念上和其它语言的null、None、nil、NULL一样，都指代零值或空值。
一个指针变量通常缩写为 ptr。
实例：

      package main

      import "fmt"

      func main() {
         var  ptr *int

         fmt.Printf("ptr 的值为 : %x\n", ptr  )
      }

空指针判断：

      if(ptr != nil)     /* ptr 不是空指针 */
      if(ptr == nil)    /* ptr 是空指针 */





Golang结构体

Golang中数组可以存储同一类型的数据，但在结构体中我们可以为不同项定义不同的数据类型。
结构体是由一系列具有相同类型或不同类型的数据构成的数据集合。
结构体表示一项记录，比如保存图书馆的书籍记录，每本书有以下属性：

      Title ：标题
      Author ： 作者
      Subject：学科
      ID：书籍ID
#### 定义结构体
结构体定义需要使用 type 和 struct 语句。struct 语句定义一个新的数据类型，结构体有中一个或多个成员。type 语句设定了结构体的名称。结构体的格式如下：

      type struct_variable_type struct {
         member definition;
         member definition;
         ...
         member definition;
      }
一旦定义了结构体类型，它就能用于变量的声明，语法格式如下：

      variable_name := structure_variable_type {value1, value2...valuen}
### 访问结构体成员
如果要访问结构体成员，需要使用点号 (.) 操作符，格式为："*结构体.成员名*"。
结构体类型变量使用struct关键字定义；
实例：

      package main

      import "fmt"

      type Books struct {
         title string
         author string
         subject string
         book_id int
      }

      func main() {
         var Book1 Books        /* 声明 Book1 为 Books 类型 */
         var Book2 Books        /* 声明 Book2 为 Books 类型 */

         /* book 1 描述 */
         Book1.title = "Golang"
         Book1.author = "www.runoob.com"
         Book1.subject = "Golang教程"
         Book1.book_id = 6495407

         /* book 2 描述 */
         Book2.title = "Python 教程"
         Book2.author = "www.runoob.com"
         Book2.subject = "Python 语言教程"
         Book2.book_id = 6495700

         /* 打印 Book1 信息 */
         fmt.Printf( "Book 1 title : %s\n", Book1.title)
         fmt.Printf( "Book 1 author : %s\n", Book1.author)
         fmt.Printf( "Book 1 subject : %s\n", Book1.subject)
         fmt.Printf( "Book 1 book_id : %d\n", Book1.book_id)

         /* 打印 Book2 信息 */
         fmt.Printf( "Book 2 title : %s\n", Book2.title)
         fmt.Printf( "Book 2 author : %s\n", Book2.author)
         fmt.Printf( "Book 2 subject : %s\n", Book2.subject)
         fmt.Printf( "Book 2 book_id : %d\n", Book2.book_id)
      }
   
### 结构体作为函数参数
可以向其他数据类型一样将结构体类型作为参数传递给函数。并以以上实例的方式访问结构体变量：

      package main

      import "fmt"

      type Books struct {
         title string
         author string
         subject string
         book_id int
      }

      func main() {
         var Book1 Books        /* 声明 Book1 为 Books 类型 */
         var Book2 Books        /* 声明 Book2 为 Books 类型 */

         /* book 1 描述 */
         Book1.title = "Golang"
         Book1.author = "www.runoob.com"
         Book1.subject = "Golang教程"
         Book1.book_id = 6495407

         /* book 2 描述 */
         Book2.title = "Python 教程"
         Book2.author = "www.runoob.com"
         Book2.subject = "Python 语言教程"
         Book2.book_id = 6495700

         /* 打印 Book1 信息 */
         printBook(Book1)

         /* 打印 Book2 信息 */
         printBook(Book2)
      }

      func printBook( book Books ) {
         fmt.Printf( "Book title : %s\n", book.title);
         fmt.Printf( "Book author : %s\n", book.author);
         fmt.Printf( "Book subject : %s\n", book.subject);
         fmt.Printf( "Book book_id : %d\n", book.book_id);
      }

###结构体指针
可以定义指向结构体的指针类似于其他指针变量，格式如下：

      var struct_pointer *Books
以上定义的指针变量可以存储结构体变量的地址。查看结构体变量地址，可以将 & 符号放置于结构体变量前：

      struct_pointer = &Book1;
使用结构体指针访问结构体成员，使用 "." 操作符：

      struct_pointer.title;
使用结构体指针重写以上实例，代码如下：

      package main

      import "fmt"

      type Books struct {
         title string
         author string
         subject string
         book_id int
      }

      func main() {
         var Book1 Books        /* Declare Book1 of type Book */
         var Book2 Books        /* Declare Book2 of type Book */

         /* book 1 描述 */
         Book1.title = "Golang"
         Book1.author = "www.runoob.com"
         Book1.subject = "Golang教程"
         Book1.book_id = 6495407

         /* book 2 描述 */
         Book2.title = "Python 教程"
         Book2.author = "www.runoob.com"
         Book2.subject = "Python 语言教程"
         Book2.book_id = 6495700

         /* 打印 Book1 信息 */
         printBook(&Book1)

         /* 打印 Book2 信息 */
         printBook(&Book2)
      }
      func printBook( book *Books ) {
         fmt.Printf( "Book title : %s\n", book.title);
         fmt.Printf( "Book author : %s\n", book.author);
         fmt.Printf( "Book subject : %s\n", book.subject);
         fmt.Printf( "Book book_id : %d\n", book.book_id);
      }


## Golang切片(Slice)

Golang切片是对数组的抽象。
Go 数组的长度不可改变，在特定场景中这样的集合就不太适用，Go中提供了一种灵活，功能强悍的内置类型切片("动态数组"),与数组相比切片的长度是不固定的，可以追加元素，在追加时可能使切片的容量增大。

### 定义切片
声明一个未指定大小的数组来定义切片：

      var identifier []type
切片不需要说明长度。
或使用make()函数来创建切片:

      var slice1 []type = make([]type, len)

也可以简写为：

      slice1 := make([]type, len)
也可以指定容量，其中capacity为可选参数。

      make([]T, length, capacity)
这里 len 是数组的长度并且也是切片的初始长度。

### 切片初始化

      s :=[] int {1,2,3 } 
直接初始化切片，[]表示是切片类型，{1,2,3}初始化值依次是1,2,3.其cap=len=3

      s := arr[:] 
初始化切片s,是数组arr的引用

      s := arr[startIndex:endIndex] 
将arr中从下标startIndex到endIndex-1 下的元素创建为一个新的切片  

      s := arr[startIndex:] 
缺省endIndex时将表示一直到arr的最后一个元素

      s := arr[:endIndex] 
缺省startIndex时将表示从arr的第一个元素开始

      s1 := s[startIndex:endIndex] 
通过切片s初始化切片s1

      s :=make([]int,len,cap) 
通过内置函数make()初始化切片s,[]int 标识为其元素类型为int的切片
len() 和 cap() 函数
切片是可索引的，并且可以由 len() 方法获取长度。
切片提供了计算容量的方法 cap() 可以测量切片最长可以达到多少。

实例：

      package main

      import "fmt"

      func main() {
         var numbers = make([]int,3,5)

         printSlice(numbers)
      }

      func printSlice(x []int){
         fmt.Printf("len=%d cap=%d slice=%v\n",len(x),cap(x),x)
      }

### 空(nil)切片
一个切片在未初始化之前默认为 nil，长度为 0，实例如下：

      package main

      import "fmt"

      func main() {
         var numbers []int

         printSlice(numbers)

         if(numbers == nil){
            fmt.Printf("切片是空的")
         }
      }

      func printSlice(x []int){
         fmt.Printf("len=%d cap=%d slice=%v\n",len(x),cap(x),x)
      }

### 切片截取

可以通过设置下限及上限来设置截取切片 [lower-bound:upper-bound]，实例如下：


      import "fmt"

      func main() {
         /* 创建切片 */
         numbers := []int{0,1,2,3,4,5,6,7,8}   
         printSlice(numbers)

         /* 打印原始切片 */
         fmt.Println("numbers ==", numbers)

         /* 打印子切片从索引1(包含) 到索引4(不包含)*/
         fmt.Println("numbers[1:4] ==", numbers[1:4])

         /* 默认下限为 0*/
         fmt.Println("numbers[:3] ==", numbers[:3])

         /* 默认上限为 len(s)*/
         fmt.Println("numbers[4:] ==", numbers[4:])

         numbers1 := make([]int,0,5)
         printSlice(numbers1)

         /* 打印子切片从索引  0(包含) 到索引 2(不包含) */
         number2 := numbers[:2]
         printSlice(number2)

         /* 打印子切片从索引 2(包含) 到索引 5(不包含) */
         number3 := numbers[2:5]
         printSlice(number3)

      }

      func printSlice(x []int){
         fmt.Printf("len=%d cap=%d slice=%v\n",len(x),cap(x),x)
      }

### append() 和 copy() 函数
如果想增加切片的容量，我们必须创建一个新的更大的切片并把原分片的内容都拷贝过来。
下面的代码描述了从拷贝切片的 copy 方法和向切片追加新元素的 append 方法：

      package main

      import "fmt"

      func main() {
         var numbers []int
         printSlice(numbers)

         /* 允许追加空切片 */
         numbers = append(numbers, 0)
         printSlice(numbers)

         /* 向切片添加一个元素 */
         numbers = append(numbers, 1)
         printSlice(numbers)

         /* 同时添加多个元素 */
         numbers = append(numbers, 2,3,4)
         printSlice(numbers)

         /* 创建切片 numbers1 是之前切片的两倍容量*/
         numbers1 := make([]int, len(numbers), (cap(numbers))*2)

         /* 拷贝 numbers 的内容到 numbers1 */
         copy(numbers1,numbers)
         printSlice(numbers1)   
      }

      func printSlice(x []int){
         fmt.Printf("len=%d cap=%d slice=%v\n",len(x),cap(x),x)
      }





## GolangMap(集合)
Map 是一种无序的键值对的集合。Map 最重要的一点是通过 key 来快速检索数据，key 类似于索引，指向数据的值。
Map 是一种集合，所以我们可以像迭代数组和切片那样迭代它。不过，Map 是无序的，我们无法决定它的返回顺序，这是因为 Map 是使用 hash 表来实现的。

### 定义 Map
可以使用内建函数 make 也可以使用 map 关键字来定义 Map:

      /* 声明变量，默认 map 是 nil */
      var map_variable map[key_data_type]value_data_type

      /* 使用 make 函数 */
      map_variable := make(map[key_data_type]value_data_type)
如果不初始化 map，那么就会创建一个 nil map。nil map 不能用来存放键值对；

实例：

      package main

      import "fmt"

      func main() {
         var countryCapitalMap map[string]string
         /* 创建集合 */
         countryCapitalMap = make(map[string]string)
         
         /* map 插入 key-value 对，各个国家对应的首都 */
         countryCapitalMap["France"] = "Paris"
         countryCapitalMap["Italy"] = "Rome"
         countryCapitalMap["Japan"] = "Tokyo"
         countryCapitalMap["India"] = "New Delhi"
         
         /* 使用 key 输出 map 值 */
         for country := range countryCapitalMap {
            fmt.Println("Capital of",country,"is",countryCapitalMap[country])
         }
         
         /* 查看元素在集合中是否存在 */
         captial, ok := countryCapitalMap["United States"]
         /* 如果 ok 是 true, 则存在，否则不存在 */
         if(ok){
            fmt.Println("Capital of United States is", captial)  
         }else {
            fmt.Println("Capital of United States is not present") 
         }
      }

### delete() 函数
delete() 函数用于删除集合的元素, 参数为 map 和其对应的 key。
实例：

      package main

      import "fmt"

      func main() {   
         /* 创建 map */
         countryCapitalMap := map[string] string {"France":"Paris","Italy":"Rome","Japan":"Tokyo","India":"New Delhi"}
         
         fmt.Println("原始 map")   
         
         /* 打印 map */
         for country := range countryCapitalMap {
            fmt.Println("Capital of",country,"is",countryCapitalMap[country])
         }
         
         /* 删除元素 */
         delete(countryCapitalMap,"France");
         fmt.Println("Entry for France is deleted")  
         
         fmt.Println("删除元素后 map")   
         
         /* 打印 map */
         for country := range countryCapitalMap {
            fmt.Println("Capital of",country,"is",countryCapitalMap[country])
         }
      }
