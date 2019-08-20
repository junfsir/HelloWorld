package main

import (
        "fmt"
)

func say(hello string) func (world string) string {
        reserve := hello
        return func (world string) string {
                hw := world
                return reserve + " " + hw
        }
}

func main() {
        helloworld := say("hello")
        fmt.Println(helloworld("world"))
}