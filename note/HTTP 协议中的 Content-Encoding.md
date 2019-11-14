# [HTTP 协议中的 Content-Encoding]( https://imququ.com/post/content-encoding-header-in-http.html )

Accept-Encoding 和 Content-Encoding 是 HTTP 中用来对「采用何种编码格式传输正文」进行协定的一对头部字段。它的工作原理是这样：浏览器发送请求时，通过 Accept-Encoding 带上自己支持的内容编码格式列表；服务端从中挑选一种用来对正文进行编码，并通过 Content-Encoding 响应头指明选定的格式；浏览器拿到响应正文后，依据 Content-Encoding 进行解压。当然，服务端也可以返回未压缩的正文，但这种情况不允许返回 Content-Encoding。这个过程就是 HTTP 的内容编码机制。

内容编码目的是优化传输内容大小，通俗地讲就是进行压缩。一般经过 gzip 压缩过的文本响应，只有原始大小的 1/4。对于文本类响应是否开启了内容压缩，是我们做性能优化时首先要检查的重要项目；而对于 JPG / PNG 这类本身已经高度压缩过的二进制文件，不推荐开启内容压缩，效果微乎其微还浪费 CPU。

内容编码针对的只是传输正文。在 HTTP/1 中，头部始终是以 ASCII 文本传输，没有经过任何压缩。这个问题在 HTTP/2 中得以解决，详见：[HTTP/2 头部压缩技术介绍](https://imququ.com/post/header-compression-in-http2.html)。

内容编码使用特别广泛，理解起来也很简单，随手打开一个网页抓包看下请求响应就能明白。唯一要注意的是不要把它与 HTTP 中的另外一个概念：传输编码（[Transfer-Encoding](https://imququ.com/post/transfer-encoding-header-in-http.html)）搞混即可。

有关 HTTP 内容编码机制我打算只介绍这么多，下面重点介绍两种具体的内容编码格式：gzip 和 deflate，具体会涉及到两个问题：1）gzip 和 deflate 分别是什么编码？2）为什么很少见到 Content-Encoding: deflate？

开始之前，先来介绍三种数据压缩格式：

- DEFLATE，是一种使用 Lempel-Ziv 压缩算法（LZ77）和哈夫曼编码的数据压缩格式。定义于 [RFC 1951 : DEFLATE Compressed Data Format Specification](http://tools.ietf.org/html/rfc1951)；
- ZLIB，是一种使用 DEFLATE 的数据压缩格式。定义于 [RFC 1950 : ZLIB Compressed Data Format Specification](http://tools.ietf.org/html/rfc1950)；
- GZIP，是一种使用 DEFLATE 的文件格式。定义于 [RFC 1952 : GZIP file format specification](http://tools.ietf.org/html/rfc1952)；

这三个名词有太多的含义，很容易让人晕菜。所以本文有如下约定：

- DEFLATE、ZLIB、GZIP 这种大写字符，表示数据压缩格式；
- deflate、gzip 这种小写字符，表示 HTTP 中 Content-Encoding 的取值；
- Gzip 特指 GUN zip 文件压缩程序，Zlib 特指 Zlib 库；

在 HTTP/1.1 的初始规范 RFC 2616 的「[3.5 Content Codings](http://tools.ietf.org/html/rfc2616#section-3.5)」这一节中，这样定义了 Content-Encoding 中的 gzip 和 deflate：

- gzip，一种由文件压缩程序「Gzip，GUN zip」产生的编码格式，描述于 RFC 1952。这种编码格式是一种具有 32 位 CRC 的 Lempel-Ziv 编码（LZ77）；
- deflate，由定义于 RFC 1950 的「ZLIB」编码格式与 RFC 1951 中描述的「DEFLATE」压缩机制组合而成的产物；

RFC 2616 对 Content-Encoding 中的 gzip 的定义很清晰，它就是指在 RFC 1952 中定义的 GZIP 编码格式；但对 deflate 的定义含糊不清，实际上它指的是 RFC 1950 中定义的 ZLIB 编码格式，但 deflate 这个名字特别容易产生误会。

在 Zlib 库的官方网站，有这么一条 FAQ：[What's the difference between the "gzip" and "deflate" HTTP 1.1 encodings?](http://www.gzip.org/zlib/zlib_faq.html#faq38) 就是在讨论 HTTP/1.1 对 deflate 的错误命名：

> Q：在 HTTP/1.1 的 Content-Encoding 中，gzip 和 deflate 的区别是什么？
>
> A：gzip 是指 GZIP 格式，deflate 是指 ZLIB 格式。HTTP/1.1 的作者或许应该将后者称之为 `zlib`，从而避免与原始的 DEFLATE 数据格式产生混淆。虽然 HTTP/1.1 RFC 2016 正确指出，Content-Encoding 中的 deflate 就是 RFC 1950 描述的 ZLIB，但仍然有报告显示部分服务器及浏览器错误地生成或期望收到原始的 DEFLATE 格式，特别是微软。所以虽然使用 ZLIB 更为高效（实际上这正是 ZLIB 的设计目标），但使用 GZIP 格式可能更为可靠，这一切都是因为 HTTP/1.1 的作者不幸地选择了错误的命名。
>
> 结论：在 HTTP/1.1 的 Content-Encoding 中，请使用 gzip。

在 HTTP/1.1 的修订版 RFC 7230 的 [4.2 Compression Codings](https://tools.ietf.org/html/rfc7230#section-4.2) 这一节中，彻底明确了 deflate 的含义，对 gzip 也做了补充：

- deflate，包含「使用 Lempel-Ziv 压缩算法（LZ77）和哈夫曼编码的 DEFLATE 压缩数据流（RFC 1951）」的 ZLIB 数据格式（RFC 1950）。注：一些不符合规范的实现会发送没有经过 ZLIB 包装的 DEFLATE 压缩数据；
- gzip，具有 32 位循环冗余检查（CRC）的 LZ77 编码，通常由 Gzip 文件压缩程序（RFC 1952）产生。接受方应该将 x-gzip 视为 gzip；

总结一下，HTTP 标准中定义的 Content-Encoding: deflate，实际上指的是 ZLIB 编码（RFC 1950）。但由于 RFC 2616 中含糊不清的定义，导致 IE 错误地实现为只接受原始 DEFLATE（RFC 1951）。为了兼容 IE，我们只能用 Content-Encoding: gzip 进行内容编码，它指的是 GZIP 编码（RFC 1952）。

其实上，ZLIB 和 DEFLATE 的差别很小：ZLIB 数据去掉 2 字节的 ZLIB 头，再忽略最后 4 字节的校验和，就变成了 DEFLATE 数据。在 Fiddler 增加以下处理，就可以让 IE 支持标准的 Content-Encoding: deflate（ZLIB 编码），很好奇为啥微软一直不改。

```js
JSif ((compressedData.Length > 2) &&
    ((compressedData[0] & 0xF) == 0x8) &&                         // Low 4-bits must be 8
    ((compressedData[0] & 0x80) == 0) &&                          // High-bit must be clear
    ((((compressedData[0] << 8) + compressedData[1]) % 31) == 0)) // Validate checksum
{
    Debug.Write("Fiddler: Ignoring RFC1950 Header bytes for DEFLATE");
    iStartOffset = 2;
}
```

由于其它浏览器也能解析原始 DEFLATE，所以有些 WEB 应用干脆为了迁就 IE 直接输出原始 DEFLATE，个人觉得这种不遵守标准的做法不值得推荐，还是推荐直接用 GZIP 编码来获得更好的兼容性。

另外 Google 提出的 sdch 这种内容编码方式，我之前关注过一段时间，不过只停留在理论阶段，所以本文没有提及，感兴趣的同学可以自己去研究。