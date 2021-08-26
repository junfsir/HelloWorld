`map`为引用类型，引用类型的变量未初始化时其零值默认为`nil`，直接向`nil map`写入数据会导致运行时错误`panic: assignment to entry in nil map`

```go
package main

import "fmt"

func main() {
	var m map[string]int 
  /* 声明但未初始化，其值为nil
  var m = map[string]int{}
  m := make(map[string]int)
  */
	chars := []string{"a", "b", "c"}
	l := len(chars)
	for i := 0; i < l; i++ {
		m[chars[i]] = i
	}

	fmt.Printf("%v", m)
}
```

