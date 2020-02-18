# [golang如何获取变量的类型：反射，类型断言](https://ieevee.com/tech/2017/07/29/go-type.html)

如果某个函数的入参是interface{}，有下面几种方式可以获取入参的方法：

1 fmt:

```go
import "fmt"
func main() {
    v := "hello world"
    fmt.Println(typeof(v))
}
func typeof(v interface{}) string {
    return fmt.Sprintf("%T", v)
}
```

2 反射：

```go
import (
    "reflect"
    "fmt"
)
func main() {
    v := "hello world"
    fmt.Println(typeof(v))
}
func typeof(v interface{}) string {
    return reflect.TypeOf(v).String()
}
```

3 [类型断言](https://golang.org/ref/spec#Type_assertions)：

```go
func main() {
    v := "hello world"
    fmt.Println(typeof(v))
}
func typeof(v interface{}) string {
    switch t := v.(type) {
    case int:
        return "int"
    case float64:
        return "float64"
    //... etc
    default:
        _ = t
        return "unknown"
    }
}
```

其实前两个都是用了反射，fmt.Printf(“%T”)里最终调用的还是`reflect.TypeOf()`。

```go
func (p *pp) printArg(arg interface{}, verb rune) {
    ...
	// Special processing considerations.
	// %T (the value's type) and %p (its address) are special; we always do them first.
	switch verb {
	case 'T':
		p.fmt.fmt_s(reflect.TypeOf(arg).String())
		return
	case 'p':
		p.fmtPointer(reflect.ValueOf(arg), 'p')
		return
	}
```

reflect.TypeOf()的参数是`v interface{}`，golang的反射是怎么做到的呢？

在golang中，interface也是一个结构体，记录了2个指针：

- 指针1，指向该变量的类型
- 指针2，指向该变量的value

如下，空接口的结构体就是上述2个指针，第一个指针的类型是`type rtype struct`；非空接口由于需要携带的信息更多(例如该接口实现了哪些方法)，所以第一个指针的类型是itab，在itab中记录了该变量的动态类型: `typ *rtype`。

```go
// emptyInterface is the header for an interface{} value.
type emptyInterface struct {
	typ  *rtype
	word unsafe.Pointer
}

// nonEmptyInterface is the header for a interface value with methods.
type nonEmptyInterface struct {
	// see ../runtime/iface.go:/Itab
	itab *struct {
		ityp   *rtype // static interface type
		typ    *rtype // dynamic concrete type
		link   unsafe.Pointer
		bad    int32
		unused int32
		fun    [100000]unsafe.Pointer // method table
	}
	word unsafe.Pointer
}
```

我们来看看reflect.TypeOf():

```go
// TypeOf returns the reflection Type that represents the dynamic type of i.
// If i is a nil interface value, TypeOf returns nil.
func TypeOf(i interface{}) Type {
	eface := *(*emptyInterface)(unsafe.Pointer(&i))
	return toType(eface.typ)
}
```

TypeOf看到的是空接口interface{}，它将变量的地址转换为空接口，然后将将得到的rtype转为Type接口返回。需要注意，当调用reflect.TypeOf的之前，已经发生了一次隐式的类型转换，即将具体类型的向空接口转换。这个过程比较简单，只要拷贝`typ *rtype`和`word unsafe.Pointer`就可以了。

例如`w := os.Stdout`，该变量的接口值在内存里是这样的：

![A *os.File interface value](https://ieevee.com/assets/go-type.png)

那么对于第三种，类型断言是怎么判断是不是某个接口呢？回到最初，在golang中，接口是一个松耦合的概念，一个类型是不是实现了某个接口，就是看该类型是否实现了该接口要求的所有函数，所以，类型断言判断的方法就是检查该类型是否实现了接口要求的所有函数。

走读k8s代码的时候，可以看到比较多的类型断言的用法：

```go
func LeastRequestedPriorityMap(pod *api.Pod, meta interface{}, nodeInfo *schedulercache.NodeInfo) (schedulerapi.HostPriority, error) {
	var nonZeroRequest *schedulercache.Resource
	if priorityMeta, ok := meta.(*priorityMetadata); ok {
		nonZeroRequest = priorityMeta.nonZeroRequest
	} else {
		// We couldn't parse metadata - fallback to computing it.
		nonZeroRequest = getNonZeroRequests(pod)
	}
	return calculateUnusedPriority(pod, nonZeroRequest, nodeInfo)
}
```

类型断言的实现在src/runtime/iface.go里(?)，不过这块代码没看懂，等以后再更新吧。

```go
func assertI2I2(inter *interfacetype, i iface) (r iface, b bool) {
	tab := i.tab
	if tab == nil {
		return
	}
	if tab.inter != inter {
		tab = getitab(inter, tab._type, true)
		if tab == nil {
			return
		}
	}
	r.tab = tab
	r.data = i.data
	b = true
	return
}

func assertE2I2(inter *interfacetype, e eface) (r iface, b bool) {
	t := e._type
	if t == nil {
		return
	}
	tab := getitab(inter, t, true)
	if tab == nil {
		return
	}
	r.tab = tab
	r.data = e.data
	b = true
	return
}
```

Ref:

- [the go programming language](http://docs.ruanjiadeng.com/gopl-zh/ch7/ch7-05.html)
- [go internal](https://tiancaiamao.gitbooks.io/go-internals/content/zh/07.2.html)
- [how to find a type of a object in golang](https://stackoverflow.com/questions/20170275/how-to-find-a-type-of-a-object-in-golang)