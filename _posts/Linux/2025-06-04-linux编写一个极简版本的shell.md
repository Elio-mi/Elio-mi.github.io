---
title: Linux编写一个极简版本的Shell
date: 2025-06-04 19:41:27 +0800
categories: ['Linux']
tags: ['Linux', 'Shell']
---

# Linux编写一个极简版本的Shell

首先我们观察到：

bash的命令行提示符：**[用户名@主机名 当前目录]**

[mi@lavm-5wklnbmaja demo1]

![image-20231109205329152](https://gitee.com/slow-heating-shaanxi-people/pictrue/raw/master/pmm/image-20231109205329152.png)

所以我们无限循环去打印这个命令行提示符 

```c
#include<stdio.h>    
#include<unistd.h>                                                                                                                                            
int main()    
{    
  while(1)    
  {    
    printf("[xupt@my_machine currpath]#");    
    //这里因为我们不能加换行，所以得刷新缓冲区    
    fflush(stdout);    
    sleep(1);    
  }    
    
  return 0;    
} 
```

运行效果：

![image-20231109210135984](https://gitee.com/slow-heating-shaanxi-people/pictrue/raw/master/pmm/image-20231109210135984.png)

## ①读取命令行

接下来我们就要获取命令输入的命令行参数：

我们创建一个字符数组用来专门存放用户输入的命令行

```c
#define MAX 1024  //因为命令行最长支持到1024
char commondstr[MAX] = {0};
```

我们用`fgets`来获取命令行

```c
fgets(commondstr, sizeof(commondstr), stdin);  
```

我们测试一下：

结果正常，但是我们的命令重新被打印的时候多打印了一个换行符，因为`fgets`读取了换行符，并且存储到了`commondstr`中了.

```bash
[mi@lavm-5wklnbmaja demo1]$ ./myshell 
[xupt@my_machine currpath]#ls -a
ls -a

```

解决方案：

```c
commondstr[strlen(commondstr) - 1] = '\0';//处理fget获取了换行符的问题 
```

运行结果：

![image-20231109212142534](https://gitee.com/slow-heating-shaanxi-people/pictrue/raw/master/pmm/image-20231109212142534.png)

## ②父子进程框架

这个时候我们就需要用到子进程了，因为执行命令行的时候需要用到程序替换，那么如果我们用父进程的话，直接就全崩掉了。

每次输入命令，都把命令交给子进程去执行，而父进程去等待子进程就好了：

```c
    pid_t id = fork();    
    
    assert(id >= 0);    
    (void) id; //和上面的处理原因一样    
    
    if(id == 0)    
    {    
      //child    
    }    
                                                                                                                                                             
    int status = 0;             
    waitpid(id, &status, 0);  
```

在子进程执行之前，我们先要将用户输入进来的命令行进行拆分

## ③切割命令行

切割的原理很简单，我们只需要把命令行中间的空格变成`\0`即可。

`ls -a -l` ----> `ls\0-a\0-l`;

这个时候我们要引入一个C库提供的函数`strtok`,它是一个专门用来分隔字符串的函数。

我们需要封装一下这个函数来达到为我们分割命令行的目的：

注意`strtok`函数第二次切割的时候只需要传入`NULL`即可。

```c
int split(char* commondstr, char* argv[])    
{    
  assert(commondstr);    
  assert(argv);    
    
  argv[0] = strtok(commondstr, SEP);    
    
  int i = 1;    
  while((argv[i++] = strtok(NULL, SEP)));    
//  {    
//      argv[i] = strtok(NULL, SEP);    
//      if(argv[i] == NULL) break;    
//      i++;    
//  }                                                     
  //表示切割成功    
  return 0;    
}  
```

main函数内部这样去调用分割函数

```c
    int n = split(commondstr, argv);
    //等于0表示切割成功
    if(n != 0) continue;
    //DebugPrint(argv);    
```

 我们再设计一个函数来打印我们切割的结果，查看我们切割的结果是否正确：

```c
void DebugPrint(char* argv[])
{
  for(int i = 0; argv[i]; ++i)
  {
    printf("%d : %s\n", i, argv[i]);
  }
}

```

运行结果：

![image-20231109224418103](https://gitee.com/slow-heating-shaanxi-people/pictrue/raw/master/pmm/image-20231109224418103.png)

## ④子进程借用分割的结果来替换程序

因为我们用`split`函数将命令行分装到`argv`字符串指针数组内部了，所以我们只能用带`v`的加载函数。

另外因为我们不能固定路径，所以我们也只能用带`p`的。

所以综上：我们的加载函数就选择到了`execvp`函数：

在子进程内部调用：

```c
    if(id == 0)    
    {    
      //child    
      execvp(argv[0], argv);    
      exit(0);    
    }    
```

那么这时候我们在运行一下：

![image-20231109225424556](https://gitee.com/slow-heating-shaanxi-people/pictrue/raw/master/pmm/image-20231109225424556.png)

---

## ⑤优化：

我们看到我们在用`bash`提供的`ls`的时候，它产生的结果是带有颜色的。

![image-20231110135556660](https://gitee.com/slow-heating-shaanxi-people/pictrue/raw/master/pmm/image-20231110135556660.png)

但是我们自己实现的简易`Shell`是没有颜色的，那么这到底是为什么？

我们`which ls`查看一下，原来系统在`ls`后边面追加了一个参数`--color==auto`;

![image-20231110135703672](https://gitee.com/slow-heating-shaanxi-people/pictrue/raw/master/pmm/image-20231110135703672.png)

那么我们也可以对我们的简易`Shell`进行一些优化让他支持这样的显示：

我们只需要在代码中特判一下即可：

```c
    if(strcmp(argv[0], "ls") == 0)    
    {    
      //先找到末尾    
      int pos  = 0;    
      while(argv[pos]) pos++;    
      //追加color参数    
      argv[pos] = (char*)"--color=auto";    
    
      //安全处理    
      pos++;    
      argv[pos] = NULL;                                                                                                                
    }
```

运行效果：

![image-20231110140325861](https://gitee.com/slow-heating-shaanxi-people/pictrue/raw/master/pmm/image-20231110140325861.png)

---

## ⑥内建命令(重要)

（1）内建命令的概念：

--->首先我们先明确一下**内建命令/内置命令**的概念,就是让我们`bash`自己执行的命令，我们称之为内建命令/内置命令。

（2）`cd`命令

当我们在我们的简易`Shell`中切换目录时：

我们发现不论我们怎么切换目录，结果都是目录没有变化，**原因是我们是在子进程中运行这些命令行的，**进程具有独立性。其实我们切换目录是切换了子进程的目录，但是父进程也就是我们`pwd`显示的目录却没有任何变化,并且这里其实`pwd`的也是子进程的当前目录，但是因为子进程在执行完`cd`命令后，就被`exit`了。当我们再执行`pwd`的时候是一个新的子进程在帮我们完成这个命令，因为我们之前`cd`没有改变父进程的当前目录，那么新创建的子进程的目录也就变成了和父进程一样的，所以看起来我们就是没有改变当前目录一样。

![image-20231110140734849](https://gitee.com/slow-heating-shaanxi-people/pictrue/raw/master/pmm/image-20231110140734849.png)

所以这里的`cd`命令，我们要在父进程中交给一个函数`chdir()`来让我们的`bash`来执行:

代码：

```c
    //当我们输入cd命令的时候    
    if(strcmp(argv[0], "cd") == 0)    
    {    
      if(argv[1] != NULL) chdir(argv[1]);                                                                                              
      continue;    
    }  
```

运行结果：

![image-20231110142305250](https://gitee.com/slow-heating-shaanxi-people/pictrue/raw/master/pmm/image-20231110142305250.png)

（3）`export`命令

此外不止我们的`cd`，包括我们当时去在`bash`中执行我们的`export`添加环境变量的时候，实际上是添加到我们的`bash`内部的，那么如果我们的简易`Shell`去把这个命令交给我们的子进程去执行了，那么就不太合适了，应该让我们的父进程自行去执行这个命令！

所以我们依旧采用内建命令的方式：

```c
    //当我们输入export命令时    
    if(strcmp(argv[0], "export") == 0)    
    {    
      //我们把这个环境变量存储在我们自己设定的数组内部    
      if(argv[1] != NULL)    
      {    
        strcpy(myenv[env_index], argv[1]);    
        //再将数组内部的环境变量放到父进程的环境变量中    
        putenv(myenv[env_index++]);    
      }    
    }  
```

我们尝试测试一下：

![image-20231110151609156](https://gitee.com/slow-heating-shaanxi-people/pictrue/raw/master/pmm/image-20231110151609156.png)

最终我们找到了

![image-20231110151622993](https://gitee.com/slow-heating-shaanxi-people/pictrue/raw/master/pmm/image-20231110151622993.png)

但是我们的`env`打印的好像是子进程的环境变量，这似乎不是我们想要的，我们应该想要的是父进程的环境变量，所以我们再做一下处理：

我们自行实现一个函数去打印我们的环境变量：

```c
    void PrintEnv()
	{
  		extern char **environ;
  		for(int i = 0; environ[i]; ++i)
  		{
    		printf("%d:%s\n",i, environ[i]);
  		}
	}
	//当我们查看环境变量的时候
    if(strcmp(argv[0], "env") == 0)
    {
      PrintEnv();
      continue; 
    }                                                                                     
```

运行效果：

![image-20231110152530084](https://gitee.com/slow-heating-shaanxi-people/pictrue/raw/master/pmm/image-20231110152530084.png)

![image-20231110152557349](https://gitee.com/slow-heating-shaanxi-people/pictrue/raw/master/pmm/image-20231110152557349.png)

**所以其实我们之前学习的几乎所有的环境变量，相关的命令都是内建命令**。

我们在将`echo`支持成内建命令：

```c
    //当我们echo的时候
    if(strcmp(argv[0], "echo") == 0)
    {
      //先确认一下echo后面第一个跟的是$
      if(argv[1][0] == '$')
      {
        char* env_ret = getenv(argv[1] + 1);                                                                                           
        if(env_ret != NULL)
        {
          printf("%s=%s\n", argv[1] + 1, env_ret);
        }
      }
      
      continue;
    }

```

运行结果：

![image-20231110155212975](https://gitee.com/slow-heating-shaanxi-people/pictrue/raw/master/pmm/image-20231110155212975.png)

既然支持了环境变量的查询，我们再来顺便支持一下进程退出码的支持，也就是我们的`echo $?`

```c
    //当我们echo的时候    
    if(strcmp(argv[0], "echo") == 0)    
    {    
      //先确认一下echo后面第一个跟的是$                                                                                                
      if(argv[1][0] == '$')    
      {    
        if(argv[1][1] == '?')    
        {    
          printf("%d\n", last_exit);      
          continue;    
        }    
        else    
        {    
          char* env_ret = getenv(argv[1] + 1);    
          if(env_ret != NULL)  printf("%s=%s \n", argv[1] + 1, env_ret);    
        }    
      }  
        
        
    int status = 0;
    pid_t ret  = waitpid(id, &status, 0);
    if(ret > 0)
    {                                                                                                                                  
      last_exit = WEXITSTATUS(status);//last_exit我们放在main函数里但不要放在循环里，他要长期保留。
    } 

```

测试结果：

![image-20231110160243796](https://gitee.com/slow-heating-shaanxi-people/pictrue/raw/master/pmm/image-20231110160243796.png)

⑦代码汇总：

```c
#include<stdio.h>
#include<unistd.h>
#include<assert.h>
#include<string.h>
#include<stdlib.h>
#include<sys/types.h>
#include<sys/wait.h>

//因为命令行最长支持到1024
#define MAX 1024
//限制最多切割为64段
#define ARGC 64

#define SEP " "


int split(char* commondstr, char* argv[])                                                           
{
  assert(commondstr);
  assert(argv);

  argv[0] = strtok(commondstr, SEP);
    
  int i = 1;
  while((argv[i++] = strtok(NULL, SEP)));
//  {
//      argv[i] = strtok(NULL, SEP);                                                                                                   
//      if(argv[i] == NULL) break;
//      i++;
//  }

  //表示切割成功
  return 0;
}

void PrintEnv()
{
  extern char **environ;
  for(int i = 0; environ[i]; ++i)
  {
    printf("%d:%s\n",i, environ[i]);
  }
}

void DebugPrint(char* argv[])
{
  for(int i = 0; argv[i]; ++i)
  {                                                                                    
    printf("%d : %s\n", i, argv[i]);
  }
}

int main()
{
  int last_exit = 0; //存储上一个进程的退出码
  int env_index = 0; //环境变量数组的下标
  char myenv[32][64];
  while(1)
  {
    //每次进来都初始化一下
    char commondstr[MAX] = {0};
    char* argv[ARGC] = {NULL};
    printf("[xupt@my_machine currpath]#");
    fflush(stdout);
    //这里因为我们不能加换行，所以得刷新缓冲区
    char* s = fgets(commondstr, sizeof(commondstr), stdin);                                                                            
    
    assert(s);
    (void)s;//保证在release发布的时候，因为assert去掉，而导致s没有被使用过而产生的告警，什么都没做，充当一次使用
    
    commondstr[strlen(commondstr) - 1] = '\0'; //解决了fgets读入换行符的问题
      
    int n = split(commondstr, argv);
    //等于0表示切割成功
    if(n != 0) continue;
    //DebugPrint(argv);
    
    //当我们输入export命令时
    if(strcmp(argv[0], "export") == 0)
    {
      //我们把这个环境变量存储在我们自己设定的数组内部
      if(argv[1] != NULL)
        strcpy(myenv[env_index], argv[1]);                                                                                             
        //再将数组内部的环境变量放到父进程的环境变量中
        putenv(myenv[env_index++]);
      }
    }

    //当我们查看环境变量的时候
    if(strcmp(argv[0], "env") == 0)
    {
      PrintEnv();
      continue; 
    }
    
    //当我们echo的时候
    if(strcmp(argv[0], "echo") == 0)
    {
      //先确认一下echo后面第一个跟的是$
      if(argv[1][0] == '$')
      {                                                                                                                                
        if(argv[1][1] == '?')
        {
          printf("%d\n", last_exit);  
          continue;
        }
        else
        {
          char* env_ret = getenv(argv[1] + 1);
          if(env_ret != NULL)  printf("%s=%s \n", argv[1] + 1, env_ret);
        }
      }
      
      continue;
    }

    //当我们输入cd命令的时候
    if(strcmp(argv[0], "cd") == 0)
    {
      if(argv[1] != NULL) chdir(argv[1]);
      continue;
    }                                                                                                                                  
    
    //当我们输入ls命令的时候
    if(strcmp(argv[0], "ls") == 0)
    {
      //先找到末尾
      int pos  = 0;
      while(argv[pos]) pos++;
      //追加color参数
      argv[pos] = (char*)"--color=auto";

      //安全处理
      pos++;
      argv[pos] = NULL;
    }

    pid_t id = fork();
    assert(id >= 0);
    (void) id; //和上面的处理原因一样

    if(id == 0)                                                                                                                        
    {
      //child
      execvp(argv[0], argv);
      exit(0);
    }

    int status = 0;
    pid_t ret  = waitpid(id, &status, 0);
    if(ret > 0)
    {
      last_exit = WEXITSTATUS(status);
    } 

   // printf("%s\n", commondstr);
  }                         
  return 0;
}        
```

