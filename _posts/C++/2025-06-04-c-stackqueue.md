---
title: C++ Stack＆queue
date: 2025-06-04 19:41:27 +0800
categories: ['C++']
---

# C++ Stack＆queue＆deque

## 1.1 stack的介绍

> [官方文档介绍stack](https://cplusplus.com/reference/stack/stack/?kw=stack)
>
> ①stack是一种容器适配器，专门用在具有后进先出操作的上下文环境中，其删除只能从容器的一端进行
>
> 元素的插入与提取操作
>
> ② stack是作为容器适配器被实现的，容器适配器即是对特定类封装作为其底层的容器，并提供一组特定
>
> 的成员函数来访问其元素，将特定类作为其底层的，元素特定容器的尾部(即栈顶)被压入和弹出
>
> ③stack的底层容器可以是任何标准的容器类模板或者一些其他特定的容器类，这些容器类应该支持以下
>
> 操作：
>
> - empty：判空操作
> - back：获取尾部元素操作
> - push_back：尾部插入元素操作
> - pop_back：尾部删除元素操作
>
> ④标准容器vector、<font color='orange'>deque</font>、list均符合这些需求，默认情况下，如果没有为stack指定特定的底层容器，
>
> 默认情况下使用<font color='orange'>deque</font>（一种将list和vector结合起来的容器）。
>
> <!-- 图片已移除：Windows 绝对路径无法访问 -->

## 1.2 stack的使用

> |                           函数说明                           |         接口说明          |
> | :----------------------------------------------------------: | :-----------------------: |
> | [stack()](https://cplusplus.com/reference/stack/stack/stack/) |      构造一个空的栈       |
> | [empty()](https://cplusplus.com/reference/stack/stack/empty/) |     判断stack是否为空     |
> | [size()](https://cplusplus.com/reference/stack/stack/size/)  | **返回**stack中元素的个数 |
> |  [top()](https://cplusplus.com/reference/stack/stack/top/)   |    返回stack的栈顶元素    |
> | [push()](https://cplusplus.com/reference/stack/stack/push/)  |   将元素val压入stack中    |
> |  [pop()](https://cplusplus.com/reference/stack/stack/pop/)   |    将栈顶的元素val出栈    |

## 1.3 stack的模拟实现

:bell: 对于栈的模拟实现，我们阅读文档知道stack是不同于之前学习的vector和list是采用一种适配器的设计模式。至于如何通俗的理解适配器设计模式，我们日常生活中使用的充电器其实也被称为适配器的一种，所以stack的这种适配器设计模式可以认为是利用已有的容器来设计一种可以适用于我们需求的容器。

:bell:  以下是stack的模拟实现，对于stack来说官方的源代码底层采用的是`deque`来实现的，`deque`也是一种采用了适配器设计模式的容器，后面会有所介绍。

> ```cpp
> #pragma once
> #include<iostream>
> #include<vector>
> #include<list>
> #include<deque>
> using namespace std;
> 
> namespace xupt
> {
> 
> 	template<class T, class Container = deque<int>>
> 	class stack
> 	{
> 	public:
> 		void push(const T& x)
> 		{
> 			_con.push_back(x);
> 		}
> 		void pop()
> 		{
> 			_con.pop_back();
> 		}
> 		const T top()
> 		{
> 			return _con.back();
> 		}
> 		size_t size()
> 		{
> 			return _con.size();
> 		}
> 		bool empty()
> 		{
> 			return _con.empty();
> 		}
> 	private:
> 		Container _con;
> 	};
> 
> 
> 
> 	void stack_test1()
> 	{
> 		stack<int> st;
> 		st.push(1);
> 		st.push(2);
> 		st.push(3);
> 		st.push(4);
> 		st.push(5);
> 
> 		while (!st.empty())
> 		{
> 			cout << st.top() << " ";
> 			st.pop();
> 		}
> 	}
> }
> ```

## 1.4 stack相关的一些oj

> [155. 最小栈 - 力扣（LeetCode）](https://leetcode.cn/problems/min-stack/)
>
> [栈的压入、弹出序列_牛客题霸_牛客网 (nowcoder.com)](https://www.nowcoder.com/practice/d77d11405cc7470d82554cb392585106?tpId=13&&tqId=11174&rp=1&ru=/activity/oj&qru=/ta/coding-interviews/question-ranking)
>
> [150. 逆波兰表达式求值 - 力扣（LeetCode）](https://leetcode.cn/problems/evaluate-reverse-polish-notation/)
>
> [232. 用栈实现队列 - 力扣（LeetCode）](https://leetcode.cn/problems/implement-queue-using-stacks/)

## 2.1 queue介绍

> [queue的官方文档](https://cplusplus.com/reference/queue/queue/)
>
>  ①队列是一种容器适配器，专门用于在FIFO上下文(先进先出)中操作，其中从容器一端插入元素，另一端
>
> 提取元素。
>
> ② 队列作为容器适配器实现，容器适配器即将特定容器类封装作为其底层容器类，queue提供一组特定的
>
> 成员函数来访问其元素。元素从队尾入队列，从队头出队列
>
> ③底层容器可以是标准容器类模板之一，也可以是其他专门设计的容器类。该底层容器应至少支持以下操
>
> 作:
>
> - empty：检测队列是否为空
> - size：返回队列中有效元素的个数
> - front：返回队头元素的引用
> - back：返回队尾元素的引用
> - push_back：在队列尾部入队列
> - pop_front：在队列头部出队列
>
> ④ 标准容器类deque和list满足了这些要求。默认情况下，如果没有为queue实例化指定容器类，则使用标
>
> 准容器deque。

## 2.2 queue的使用

> | [**queue()**](https://cplusplus.com/reference/queue/queue/queue/) | 构造一个空的queue      |
> | ------------------------------------------------------------ | ---------------------- |
> | [**empty()**](https://cplusplus.com/reference/queue/queue/empty/) | 判断队列内是否为空     |
> | [**size()**](https://cplusplus.com/reference/queue/queue/size/) | 返回队列中的元素个数   |
> | [**front()**](https://cplusplus.com/reference/queue/queue/front/) | 返回队头的元素         |
> | [**back()**](https://cplusplus.com/reference/queue/queue/back/) | 返回队尾的元素         |
> | [**push()**](https://cplusplus.com/reference/queue/queue/push/) | 向队列中插入新的元素   |
> | [**pop()**](https://cplusplus.com/reference/queue/queue/pop/) | 删除队列中的下一个元素 |

## 2.3 queue的模拟实现

> 因为queue的接口中存在头删和尾插，因此使用vector来封装效率太低，故可以借助list来模拟实现queue，
>
> 具体如下：
>
> ```cpp
> #pragma once
> 
> #pragma once
> #include<iostream>
> #include<vector>
> #include<list>
> #include<deque>
> using namespace std;
> 
> namespace xupt
> {
> 
> 	template<class T, class Container = deque<int>>
> 	class queue
> 	{
> 	public:
> 		void push(const T& x)
> 		{
> 			_con.push_back(x);
> 		}
> 		void pop()
> 		{
> 			_con.pop_front();
> 		}
> 		const T& front()
> 		{
> 			return _con.front();
> 		}
> 		const T& back()
> 		{
> 			return _con.back();
> 		}
> 
> 		size_t size()
> 		{
> 			return _con.size();
> 		}
> 		bool empty()
> 		{
> 			return _con.empty();
> 		}
> 	private:
> 		Container _con;
> 	};
> 
> 	void queue_test1()
> 	{
> 		queue<int> q;
> 		q.push(1);
> 		q.push(2);
> 		q.push(3);
> 		q.push(4);
> 		q.push(5);
> 
> 		while (!q.empty())
> 		{
> 			cout << q.front() << " ";
> 			q.pop();
> 		}
> 	}
> 
> 
> }
> 
> ```

# 3.deque的介绍

## 3.1duque的原理介绍

> deque(双端队列)：是一种双开口的"连续"空间的数据结构，双开口的含义是：可以在头尾两端进行插入和删除操作，且时间复杂度为O(1)，与vector比较，头插效率高，不需要搬移元素；与list比较，空间利用率比较高。
>
> <!-- 图片已移除：Windows 绝对路径无法访问 -->
>
>   实际上deque并不是一段连续的空间，它实际上的结构如下图所示：
>
> <!-- 图片已移除：Windows 绝对路径无法访问 -->
>
> 那么为了维护deque看似连续的结构，以及随机访问的特性，deque的迭代器设计有些复杂如下图所示：
>
> 我们可以看到deque的迭代器中<font color='orange'>有四个参数</font>分别是`cur`,`first`,`last`,`node`.
>
> 其中：
>
> - cur指向的是当前的数据的位置。
> - first指向的当前buffer的首位地址。
> - last指向的当前buffer的最后一个元素的地址。
> - node指向的中控器中的存贮当前buffer的地址的位置。
>
> <!-- 图片已移除：Windows 绝对路径无法访问 -->
>
> deque::begin() 传回迭代器 start，deque::end() 传回迭代器finish。这两个迭代器都是 deque 的 data members。

## 3.2 deque的缺陷

> **与vector比较**，deque是具有优势的，头插和尾插的时候不需要挪动元素，效率非常的高。另外一点是扩容的的优势，它的扩容的开销相对于vector来说也是具有优势的，也不需要搬运全部的元素。
>
> **与list比较**，底层是一个相对连续的空间，空间的利用率高，不需要存储额外的字段。
>
> 看起来似乎deque结合了两者的优点，那么它有什么缺点呢？
>
> :bell: deque不适合去遍历，因为它的迭代器相对来说比较复杂，因为deque的迭代器要频繁的去检测其是否移动到某段小空间的边界，导致效率低下。

## 3.3 为什么选择deque作为stack和queue的底层默认容器

> - stack和queue不需要遍历(因此stack和queue没有迭代器)，只需要在固定的一端或者两端进行操作。
>
> - 在stack中元素增长时，deque比vector的效率高(扩容时不需要搬移大量数据)；queue中的元素增长时，deque不仅效率高，而且内存使用率高。



