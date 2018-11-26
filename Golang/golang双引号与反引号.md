***在Go语言中不倾向于使用单引号来表示字符串，请根据需要使用双引号或反引号。***  
一个Go语言字符串是一个任意字节的常量序列。Go语言的字符串类型在本质上就与其他语言的字符串类型不同。Java的String、C++的std::string以及Python3的str类型都只是定宽字符序列，而Go语言的字符串是一个用UTF-8编码的变宽字符序列，它的每一个字符都用一个或多个字节表示。  
Go语言中的字符串字面量使用`双引号`或`反引号`来创建：  
双引号用来创建可解析的字符串字面量(支持转义，但不能用来引用多行)； 
反引号用来创建原生的字符串字面量，这些字符串可能由多行组成(不支持任何转义序列)，原生的字符串字面量多用于书写多行消息、HTML以及正则表达式。 
### Golang struct tag

    type User struct {
        Name   string `user name`
        Passwd string `user password`
    }
上面代码里反引号间的部分就是tag；  
tag能用来干什么？
tag一般用于表示一个映射关系，最常见的是json解析中：

    type User struct {
        Name   string `json:"name"`
        Passwd string `json:"password"`
    }
这个代码里，解析时可以把json中"name"解析成struct中的"Name"（大小写不一样）。  
tag定义必须用键盘ESC键下面的那个吗？
不是，用双引号也可以：
 
    type User struct {
        Name string "user name"
        Passwd string "user passsword"
    }
怎么获取struct的tag?
用反射：

    package main
    
    import (
        "fmt"
        "reflect" // 这里引入reflect模块
    )
    
    type User struct {
        Name   string `json:"name"`
        Passwd string `json:"password"`
    }
    
    func main() {
        user := &User{"chronos", "pass"}
        s := reflect.TypeOf(user).Elem() //通过反射获取type定义
        for i := 0; i < s.NumField(); i++ {
            fmt.Println(s.Field(i).Tag) //将tag输出出来
        }
    }
输出结果：

    json:”name”
    json:”password”
