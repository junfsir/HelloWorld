```shell
# portrange：指定端口范围
tcpdump -i br0 -s0 -t ip dst host 10.200.0.195 and tcp portrange 30000-33000 -nnN

#只捕获TCP SYN包：
tcpdump -i br0 "tcp[tcpflags] & (tcp-syn) != 0"

# 只捕获TCP ACK包：
tcpdump -i br0 "tcp[tcpflags] & (tcp-ack) != 0"

# 只捕获TCP FIN包：
tcpdump -i br0 "tcp[tcpflags] & (tcp-fin) != 0"

# 之捕获TCP SYN或ACK包：
tcpdump -i br0 "tcp[tcpflags] & (tcp-syn|tcp-ack) != 0"
```

