package main

import (
        "fmt"
)

type person struct {
        name  string
        age   string
}

type sayhello interface {
        hello()
        world()
}

func testhello(s sayhello) {
        s.hello()
//      s.world()
}

func (p person) hello() {
        fmt.Println("hello, I am " + p.name)
}

func (p person) world() {
        fmt.Println("Hi, I am " + p.age + " years old")
}

func main() {
        l := person{"jeason", "25"}
        testhello(l)
}
