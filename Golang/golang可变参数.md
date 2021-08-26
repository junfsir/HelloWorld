*Go语言函数中有三个点...表示为可变参数，可以接受任意个数的参数，可变参数本质上是slice；*

```go
package main

import "fmt"

func Greeting(prefix string, who ...string) {
	fmt.Println(prefix)
	for _, name := range who {
		fmt.Println(name)
	}
}
func main() {
	Greeting("Hello:", "tom", "jeason", "nike")
}
```

