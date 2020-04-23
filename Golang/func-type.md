```go
package main

import "fmt"

type Greeting func(name string) string

func (g Greeting) say(s string) {
    fmt.Println(g(s))
}

func withEnglish(n string) string {
    return "Hello, " + n
}

func withFrench(n string) string {
    return "Bonjour, " + n
}

func main() {
    sayh := Greeting(withEnglish)
    sayh.say("Jefferson")

    sayh = Greeting(withFrench)
    sayh.say("Jefferson")
}
```

