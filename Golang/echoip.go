package main

import (
	"fmt"
	"net/http"
	//"os"
	//"io"
	"time"
	"io/ioutil"
)

func EchoIp() ([]byte, error) {
	timeout := time.Duration(5) * time.Second

	client := &http.Client{
		Timeout: timeout,
	}

	url := "http://ifconfig.me"

	req, err := client.Get(url)
	if err != nil {
		return nil, err
	}

	defer req.Body.Close()

	return ioutil.ReadAll(req.Body)

//	response, _ := client.Do(request)
//
//	stdout := os.Stdout
//
//	fmt.Println(typeof(response.Body))
//
//	_, err = io.Copy(stdout, response.Body)
//
//	status := response.StatusCode
//
//	fmt.Println(status)

}

func main() {
	result, _ := EchoIp()

//	fmt.Println(typeof(result))

	fmt.Println(string(result)) 
}

//func typeof(p interface{}) string {
//    return fmt.Sprintf("%T", p)
//}