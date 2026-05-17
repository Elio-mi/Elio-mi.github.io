---
title: UIViewController 核心技术解析与纯代码开发实践
date: 2026-05-17 11:30:00 +0800
categories: ['iOS']
tags: ['UIKit', 'UIViewController', 'Objective-C', '纯代码开发']
---

# UIViewController 核心技术解析

## 目录
1. [基本定义与职责](#1-基本定义与职责)
2. [视图生命周期详解](#2-视图生命周期详解)
3. [纯代码开发中的关键方法](#3-纯代码开发中的关键方法)
    - [loadView 的重写规范](#loadview-的重写规范)
    - [viewDidLoad 的初始化建议](#viewdidload-的初始化建议)
4. [UI 控件的组织与初始化 (Lazy Loading)](#4-ui-控件的组织与初始化-lazy-loading)
5. [控制器间的导航与跳转](#5-控制器间的导航与跳转)
6. [内存管理与闭包/Block 规范](#6-内存管理与闭包block-规范)

---

## 1. 基本定义与职责
`UIViewController` 是 UIKit 框架中 MVC 模式的核心控制器。其主要职责包括：
- 管理视图层次结构（View Hierarchy）。
- 处理用户交互事件。
- 负责视图的加载、展示及销毁。
- 协调模型数据与视图展示之间的同步。

## 2. 视图生命周期详解
系统通过一组预定义的生命周期方法通知控制器其视图状态的变化。

| 方法名称 | 触发时机 | 典型用途 |
| :--- | :--- | :--- |
| `loadView` | 视图加载的起点 | 纯代码创建/替换根视图 |
| `viewDidLoad` | 视图加载到内存后 | 初始配置、添加子视图、UI 布局 |
| `viewWillAppear:` | 视图即将显示 | 刷新数据、更新状态栏 |
| `viewDidAppear:` | 视图已经显示 | 启动动画、开始视频播放 |
| `viewWillDisappear:` | 视图即将消失 | 停止计时器、收起键盘 |
| `viewDidDisappear:` | 视图已经消失 | 释放非必要资源 |
| `dealloc` | 控制器被销毁时 | 移除通知监听、释放指针 |

## 3. 纯代码开发中的关键方法

### loadView 的重写规范
在纯代码开发中，如果需要自定义根视图（如将 `self.view` 设置为 `UIScrollView` 或自定义的 `UIView` 子类），应重写此方法。

**Objective-C:**
```objective-c
- (void)loadView {
    // 纯代码重写时不建议调用 [super loadView]
    self.view = [[MyCustomRootView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.backgroundColor = [UIColor whiteColor];
}
```

### viewDidLoad 的初始化建议
该方法用于在根视图加载完成后进行二次配置。必须调用 `[super viewDidLoad]`。

**Objective-C:**
```objective-c
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 初始化 UI 布局、注册通知、发起网络请求
    [self.view addSubview:self.submitButton];
    [self setupConstraints];
}
```

## 4. UI 控件的组织与初始化 (Lazy Loading)
为了保证代码的条理性，建议使用属性（Property）并通过懒加载（Lazy Loading/Getter）模式初始化 UI 控件。

**Objective-C 实现逻辑：**
```objective-c
@property (nonatomic, strong) UIButton *submitButton;

- (UIButton *)submitButton {
    if (!_submitButton) {
        _submitButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_submitButton setTitle:@"提交" forState:UIControlStateNormal];
        [_submitButton addTarget:self action:@selector(handleSubmit) forControlEvents:UIControlEventTouchUpInside];
    }
    return _submitButton;
}
```

**Swift 对照：**
```swift
private lazy var submitButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("提交", for: .normal)
    button.addTarget(self, action: #selector(handleSubmit), for: .touchUpInside)
    return button
}()
```

## 5. 控制器间的导航与跳转

### 导航控制器 (Push/Pop)
适用于具有层级结构的关系流。

```objective-c
// Objective-C
DetailViewController *detailVC = [[DetailViewController alloc] init];
[self.navigationController pushViewController:detailVC animated:YES];
```

### 模态弹出 (Present/Dismiss)
适用于相对独立的任务。iOS 13+ 默认显示为卡片样式，如需全屏需设置 `modalPresentationStyle`。

```objective-c
// Objective-C
LoginViewController *loginVC = [[LoginViewController alloc] init];
loginVC.modalPresentationStyle = UIModalPresentationFullScreen;
[self presentViewController:loginVC animated:YES completion:nil];
```

## 6. 内存管理与闭包/Block 规范
在 Objective-C 中，使用 Block 时必须注意防止循环引用（Retain Cycle）。

**Weak-Strong Dance 模式：**
```objective-c
__weak typeof(self) weakSelf = self;
[service fetchDataWithCompletion:^(id data) {
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (!strongSelf) return;
    
    // 使用 strongSelf 更新 UI 或存储数据
    strongSelf.dataArray = data;
    [strongSelf.tableView reloadData];
}];
```

**Swift 对照：**
```swift
service.fetchData { [weak self] data in
    guard let self = self else { return }
    self.dataArray = data
    self.tableView.reloadData()
}
```

## 7. 最佳实践
- **单一职责原则**：控制器应主要负责视图管理与事件分发，业务逻辑应剥离至 Model 或 Service 层。
- **布局代码分离**：建议将复杂的 Auto Layout 约束代码封装在独立的方法（如 `setupConstraints`）中调用。
- **状态恢复**：在内存警告（`didReceiveMemoryWarning`）时，及时释放可重新创建的缓存数据。
