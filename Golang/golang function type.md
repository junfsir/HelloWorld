```go
// A function type denotes the set of all functions with the same parameter and result types.
package main

import "fmt"

type Greeting func(name string) string

func (g Greeting) say(str string) {
	fmt.Println(g(str))
}

func withEnglish(name string) string {
	return "Hello, " + name
}

func withFrench(name string) string {
	return "Bonjour, " + name
}

func main() {
	sayHiInEnglish := Greeting(withEnglish)
	sayHiInEnglish.say("Jefferson")

	sayHiInFrench := Greeting(withFrench)
	sayHiInFrench.say("Jefferson")
}
```

