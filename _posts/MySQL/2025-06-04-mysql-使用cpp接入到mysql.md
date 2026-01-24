---
title: MySQL-使用CPP接入到MySQL
date: 2025-06-04 19:41:27 +0800
categories: ['MySQL']
---

# MySQL-使用CPP接入到MySQL

## 1.准备工作

> 首先我们确保我们的当前的设备中有对应的MySQL的动静态库,以及对应的头文件
>
> 查看头文件：
>
> ```mysql
> [mi@lavm-5wklnbmaja MySQL]$ ls /usr/include/mysql/
> ....
> ```
>
> 若没有：执行如下的语句让yum帮我们去安装
>
> ```bash
> sudo yum install mysql-devel
> ```
>
> 检查是否存在所需要的库
>
> ```mysql
> [mi@lavm-5wklnbmaja MySQL]$ ls /lib64/mysql/
> libmysqlclient.a            libmysqlclient.so         libmysqlclient.so.20       mecab
> libmysqlclient_r.so.18      libmysqlclient.so.18      libmysqlclient.so.20.3.31  plugin
> libmysqlclient_r.so.18.1.0  libmysqlclient.so.18.1.0  libmysqlservices.a
> ```
>
> 若不存在:执行如下语句
>
> ```mysql
> [root@lavm-5wklnbmaja MySQL]# yum install -y mysql-community-server
> ```

其中 include 包含所有的方法声明， lib 包含所有的方法实现（打包成库）,尝试链接mysql client.

通过 mysql_get_client_info() 函数，来验证我们的引入是否成功  

```cpp
#include <iostream>
#include <mysql/mysql.h>

int main()
{
    std::cout << "mysql client version: " << mysql_get_client_info() << std::endl; 
    
    return 0;
}
```

  如何编译：

首先我们要连接动态库中的：`libmysqlclient.so`

> -l:用于告诉编译器链接哪个库
>
> -L:告诉编译器对应的库的位置

```bash
g++ -o testcon testcon.cpp -L/lib64/mysql -lmysqlclient
```

运行结果：

```bash
[mi@lavm-5wklnbmaja MySQL]$ ./testcon 
mysql client version: 5.7.44
```

## 2.MySQL接口介绍

> - 初始化mysql_init()  

要使用库，必须先进行初始化！

`MYSQL *mysql_init(MYSQL *mysql);  `

如：`MYSQL *mfp = mysql_init(NULL)`  

> - 链接数据库mysql_real_connect  

初始化完毕之后，必须先链接数据库，在进行后续操作。（mysql网络部分是基于TCP/IP的）  

```cpp
MYSQL *mysql_real_connect(MYSQL *mysql, const char *host,
const char *user,
const char *passwd,
const char *db,
unsigned int port,
const char *unix_socket,
unsigned long clientflag);
//建立好链接之后，获取英文没有问题，如果获取中文是乱码：
//设置链接的默认字符集是utf8，原始默认是latin1
mysql_set_character_set(myfd, "utf8");
```

第一个参数 MYSQL是 C api中一个非常重要的变量（mysql_init的返回值），里面内存非常丰富，有port,dbname,charset等连接基本参数。它也包含了一个叫 st_mysql_methods的结构体变量，该变量
里面保存着很多函数指针，这些函数指针将会在数据库连接成功以后的各种数据操作中被调用。
`mysql_real_connect`函数中各参数，基本都是顾名思意  

> - 下发mysql命令mysql_query  

```cpp
int mysql_query(MYSQL *mysql, const char *q);
```

第一个参数上面已经介绍过，第二个参数为要执行的sql语句,如“select * from table”。  

> - 获取执行结果mysql_store_result  

sql执行完以后，如果是查询语句，我们当然还要读取数据，如果update，insert等语句，那么就看下操
作成功与否即可。我们来看看如何获取查询结果： 如果mysql_query返回成功，那么我们就通过
mysql_store_result这个函数来读取结果。原型如下：  

```cpp
MYSQL_RES *mysql_store_result(MYSQL *mysql);
```

该函数会调用MYSQL变量中的st_mysql_methods中的 read_rows 函数指针来获取查询的结果。同时该
函数会返回MYSQL_RES 这样一个变量，该变量主要用于保存查询的结果。同时该函数malloc了一片内
存空间来存储查询过来的数据，所以我们一定要记的 free(result),不然是肯定会造成内存泄漏的。 执行
完mysql_store_result以后，其实数据都已经在MYSQL_RES 变量中了，下面的api基本就是读取
MYSQL_RES 中的数据

> - 获取结果行数mysql_num_rows  

```cpp
my_ulonglong mysql_num_rows(MYSQL_RES *res);
```

> - 获取结果列数mysql_num_fields  

```cpp
unsigned int mysql_num_fields(MYSQL_RES *res);
```

> - 获取列名mysql_fetch_fields  

```cpp
MYSQL_FIELD *mysql_fetch_fields(MYSQL_RES *res);
```

如：

```cpp
int fields = mysql_num_fields(res);
MYSQL_FIELD *field = mysql_fetch_fields(res);
int i = 0;
for(; i < fields; i++){
cout<<field[i].name<<" ";
} c
out<<endl;
```

> - 获取结果内容mysql_fetch_row  

```cpp
MYSQL_ROW mysql_fetch_row(MYSQL_RES *result);
```

它会返回一个MYSQL_ROW变量，MYSQL_ROW其实就是char **.就当成一个二维数组来用吧  

```cpp
i = 0;
MYSQL_ROW line;
for(; i < nums; i++){
line = mysql_fetch_row(res);
int j = 0;
for(; j < fields; j++){
cout<<line[j]<<" ";
} c
out<<endl;
}
```

> - 关闭mysql链接mysql_close  

```cpp
void mysql_close(MYSQL *sock);
```

另外，mysql C api还支持事务等常用操作:  

```cpp
my_bool STDCALL mysql_autocommit(MYSQL * mysql, my_bool auto_mode);
my_bool STDCALL mysql_commit(MYSQL * mysql);
my_bool STDCALL mysql_rollback(MYSQL * mysql);
```

