```shell
docker build -f Dockerfile -t TAG .
	构建上下文的3种来源：PATH、-、URL
	将本地主机的一个包含Dockerfile的目录中的所有内容作为上下文；


除了FROM指令，其他每一条指令都会在上一条指令所生成镜像的基础上执行，执行完后会生成一个新的镜像层，新的镜像层覆盖在原来的镜像之上从而形成新的镜像；

ENV：ENV <key> <value>或 ENV <key>=<value>
	为镜像创建出来的容器声明环境变量；ENV声明的环境变量会被后面的特定指令(即ENV、ADD、COPY、WORKDIR、EXPOSE等)解释使用；其他指令使用环境变量时，格式为$variable_name或${variable_name}，在变量前面使用\进行转义；
FROM：FROM <image> 或 FROM <image>:<tag>
	为后面的指令提供基础镜像；
COPY：COPY <src> <dest>
	<src>：必须是上线文根目录的相对路径，可以使用通配符；
	<dest>：必须是镜像中的绝对路径或者相对于WORKDIR的相对路径；
ADD：ADD <src> <dest>
RUN：
	RUN <command> (shell格式)
	RUN ["executable","param1","param2"] (exec格式，推荐格式，必须使用双引号)
	在前一条命令创建出的镜像的基础上创建一个容器，并在容器中执行命令；
CMD：
	CMD <command> (shell格式)
	CMD ["executable","param1","param2"] (exec格式，推荐格式，必须使用双引号)
	CMD ["param1","param2"] (为ENTRYPOINT指令提供参数)
	提供容器运行时的默认值；
	RUN指令在构建镜像时执行命令，并生成新的镜像；CMD指令在构建镜像时不执行任何命令，而是在容器启动时默认将CMD指令作为第一条执行的命令；如果用户在命令行运行docker run时指定了命令参数，则会覆盖CMD指令中的命令；
ENTRYPOINT：
	ENTRYPOINT <command> (shell格式)
	ENTRYPOINT ["executable","param1","param2"] (exec格式，推荐格式，必须使用双引号)
	ENTRYPOINT和CMD类似，都可以让容器在每次启动时执行相同的命令；一个Dockerfile中可以有多条ENTRYPOINT指令，但只有最后一条ENTRYPOINT指令有效；
```



```shell
官方文档：https://docs.docker.com/compose/compose-file/

compose文件是yaml格式的包含service、networks和volume配置段；
service配置段：
	定义应用于该服务容器启动时的配置，类似于命令行中的docker container create，另外，networks配置段和volume配置段也是类似于docker network create和docker volume create；
	包含的配置项：
		build：路径字符串用于指定创建容器时的上下文；
			version: '3'
			services:
			  webapp:
			    build: ./dir
		或者是一个指定上下文的路径对象和可选的Dockerfile及args：
			version: '3'
			services:
			  webapp:
			    build:
			      context: ./dir
			      dockerfile: Dockerfile-alternate
			      args:
			        buildno: 1
		若使用image进行构建：
			build: ./dir
			image: webapp:tag


args：
	仅在容器构建过程中可访问的环境变量；
	首先在Dockerfile中指定参数，然后在build下指定参数；

tty: true

extra_hosts：
	主机名映射，使用与docker client --add-host参数相同的值；

depends_on：
	表明服务间的依赖关系；

volumes_from：
	从另外的服务或者容器挂载volume，可选择使用只读(ro)和可读写(rw)，默认使用rw；
	volumes_from:
	 - service_name
	 - service_name:ro
	 - container:container_name
	 - container:container_name:rw
	
links：
	关联其他服务的容器，可以使用服务名和一个链接别名("SERVICE:ALIAS")，或者只使用服务名；
	web:
	  links:
	   - "db"
	   - "db:database"
	   - "redis"

entrypoint：
	覆盖默认的entrypoint；
	entrypoint: /code/entrypoint.sh
	也可以使用列表，类似于Dockerfile；

command：
	覆盖默认的command；
	command: bundle exec thin -p 3000
	command: ["bundle", "exec", "thin", "-p", "3000"]


    logging:
      driver: "json-file"
      options:
        max-size: "200k"
        max-file: "10"


docker-compose环境变量：

	在compose文件中引用环境变量
	可以在compose文件中引用运行docker-compose所在的shell中的环境变量，如:

	web:
	  image: "webapp:${TAG}"
	在容器中设置环境变量
	可以在compose文件中的environment关键词下设置容器的环境变量，就像docker run -e VARIABLE=VALUE …:

	web:
	  environment:
	    - DEBUG=1
	将环境变量传递到容器
	可以在compose文件中的environment关键词下定义一个环境变量而不赋值，就像docker run -e VARIABLE …:

	web:
	  environment:
	    - DEBUG
	容器中环境变量DEBUG的值是从执行compose文件所在的shell的同一个环境变量取得。

	env_file配置选项
	可以使用compose文件中的env_file选项从一个外部的文件传递多个环境变量到容器中，就像docker run –env-file=FILE …:

	web:
	  env_file:
	    - web-variables.env
	使用docker-compose run设置环境变量
	就像docker run -e，可以使用docker-compose run -e为一次性容器设置环境变量：

	docker-compose run -e DEBUG=1 web python console.py
	也可以不赋值从shell变量中取值：

	docker-compose run -e DEBUG web python console.py
	DEBUG的值是从执行compose文件所在的shell的同一个环境变量取得。

	.env文件
	可以在环境文件.env设置默认的环境变量，这些环境变量可以在compose文件引用：

	$ cat .env
	TAG=v1.5
	 
	$ cat docker-compose.yml
	version: '2.0'
	services:
	  web:
	    image: "webapp:${TAG}"
	当执行docker-compose up命令，上面定义的web服务将使用webapp:v1.5镜像。可以使用config命令来打印出来：

	$ docker-compose config
	version: '2.0'
	services:
	  web:
	    image: 'webapp:v1.5'
	在shell中的环境变量将比定义在.env文件中的环境变量优先。如果在shell中设置了一个不同的TAG，镜像将使用shell中定义的而不是.env文件中的：

	$ export TAG=v2.0
	$ docker-compose config
	version: '2.0'
	services:
	  web:
	    image: 'webapp:v2.0'
```

