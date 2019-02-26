```go
package main
import (
	"os"
	"fmt"
)

func main() {
	var (
		directory string
		count     int
		err       error
	)
	if len(os.Args) == 1 {
		if directory,err = os.Getwd();err != nil {
			fmt.Println(err)
			os.Exit(1)
		}

	}else {
		directory = os.Args[1]
	}
	f,err := os.Open(directory)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	list,err := f.Readdir(-1)
	f.Close()
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	for _,info := range list {
		fmt.Println(info.Name())
	}
	count = len(list)
	fmt.Println("file_counts:",count)
	return
}
```

