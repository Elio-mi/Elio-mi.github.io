---
title: C++ priority_queue
date: 2025-06-04 19:41:27 +0800
categories: ['C++']
tags: ['C++', 'IO']
---

# C++ priority_queue

## 1. priority_queue的介绍和使用

> 首先我们可以将`priority_queue`理解为我们在数据结构中学习的堆,但是这里个人觉得是堆的升级版，因为它的名字叫”优先“队列。
>
> 也就是**<font color='orange'>说我们可以人为的控制堆中的元素是以何种方式比较</font>**。
>
> 也可以阅读[priority_queue的官方文档](https://cplusplus.com/reference/queue/priority_queue/)
>
> 以下是`priority_queue` 的相关介绍：
>
> - 优先队列是一种容器适配器，根据[严格的弱排序](https://blog.csdn.net/River_Lethe/article/details/78618788)标准，它的第一个元素总是它所包含的元素中最大的。
>
> - 此上下文类似于堆，在堆中可以随时插入元素，并且只能检索最大堆元素(优先队列中位于顶部的元素)。
>
> - 优先队列被实现为容器适配器，容器适配器即将特定容器类封装作为其底层容器类，queue提供一组特定的成员函数来访问其元素。元素从特定容器的“尾部”弹出，其称为优先队列的顶部。
>
> - 底层容器可以是任何标准容器类模板，也可以是其他特定设计的容器类。容器应该可以通过随机访问迭代器访问，并支持以下操作：
>
>   - empty()：检测容器是否为空
>   - size()：返回容器中有效元素个数
>   - front()：返回容器中第一个元素的引用
>   - push_back()：在容器尾部插入元素
>   - pop_back()：删除容器尾部元素
>
> - 标准容器类vector和deque满足这些需求。默认情况下，如果没有为特定的priority_queue类实例化指
>
>   定容器类，则使用vector。
>
> -  需要支持随机访问迭代器，以便始终在内部保持堆结构。容器适配器通过在需要时自动调用算法函数
>
>   make_heap、push_heap和pop_heap来自动完成此操作。

## 2. priority_queue的使用

> 优先级队列默认使用vector作为其底层存储数据的容器，在vector上又使用了堆算法将vector中元素构造成堆的结构，因此priority_queue就是堆，所有需要用到堆的位置，都可以考虑使用priority_queue。注意：默认情况下priority_queue是大堆。
>
> |                           函数声明                           |                          接口说明                           |
> | :----------------------------------------------------------: | :---------------------------------------------------------: |
> | [priority_queue()/priority_queue(first, last)](https://cplusplus.com/reference/queue/priority_queue/priority_queue/) | **构造一个空的优先级队列/使用迭代器构造一个非空优先级队列** |
> | [empty()](https://cplusplus.com/reference/queue/priority_queue/empty/) |                 判断当前优先级队列是否为空                  |
> | [top()](https://cplusplus.com/reference/queue/priority_queue/top/) |                 返回堆顶元素即最大/最小元素                 |
> | [push(x)](https://cplusplus.com/reference/queue/priority_queue/push/) |                 **在优先级队列中插入元素**x                 |
> | [pop()](https://www.cplusplus.com/reference/queue/priority_queue/pop/) |               删除堆顶的元素即最大/最小的元素               |
>
> 【注意】
>
> 1.默认情况下，priority_queue是大堆。
>
> ```cpp
> #include <vector>
> #include <queue>
> #include <functional> // greater算法的头文件
> void TestPriorityQueue()
> {
>  // 默认情况下，创建的是大堆，其底层按照小于号比较
>  vector<int> v{3,2,7,6,0,4,1,9,8,5};
>  priority_queue<int> q1;
>  for (auto& e : v)
>  q1.push(e);
>  cout << q1.top() << endl;
>  // 如果要创建小堆，将第三个模板参数换成greater比较方式
>  priority_queue<int, vector<int>, greater<int>> q2(v.begin(), v.end());
>  cout << q2.top() << endl;
> }
> ```
>
> 2.当我们想在priority_queue中放入自定义类型，那么我们需要在自定义类型中给出`<`或者`>`的重载
>
> ```cpp
> class Date
> {
> public:
>  Date(int year = 1900, int month = 1, int day = 1)
>  : _year(year)
>  , _month(month)
>  , _day(day)
>  {}
>  bool operator<(const Date& d)const
>  {
>  return (_year < d._year) ||
>  (_year == d._year && _month < d._month) ||
>  (_year == d._year && _month == d._month && _day < d._day);
>  }
>  bool operator>(const Date& d)const
>  {
>  return (_year > d._year) ||
>  (_year == d._year && _month > d._month) ||
>  (_year == d._year && _month == d._month && _day > d._day);
>  }
>  friend ostream& operator<<(ostream& _cout, const Date& d)
>  {
>  _cout << d._year << "-" << d._month << "-" << d._day;
>  return _cout;
>  }
> private:
>  int _year;
>  int _month;
>  int _day;
> };
> void TestPriorityQueue()
> {
>  // 大堆，需要用户在自定义类型中提供<的重载
>  priority_queue<Date> q1;
>  q1.push(Date(2018, 10, 29));
>  q1.push(Date(2018, 10, 28));
>  q1.push(Date(2018, 10, 30));
>  cout << q1.top() << endl;
>  // 如果要创建小堆，需要用户提供>的重载
>  priority_queue<Date, vector<Date>, greater<Date>> q2;
>  q2.push(Date(2018, 10, 29));
>  q2.push(Date(2018, 10, 28));
>  q2.push(Date(2018, 10, 30));
>  cout << q2.top() << endl;
> }
> ```

## 3.相关的oj题

[215. 数组中的第K个最大元素 - 力扣（LeetCode）](https://leetcode.cn/problems/kth-largest-element-in-an-array/)