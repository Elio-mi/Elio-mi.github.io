---
title: AVAudioEngine 工作原理深度笔记
date: 2026-06-26 00:00:00 +0800
categories: ['iOS']
tags: ['iOS', 'AVFoundation', 'AVAudioEngine', '音频', 'Swift']
description: 从节点图、渲染时序、音频格式和实时线程约束理解 AVAudioEngine，并覆盖播放、录音、混音、离线渲染与中断恢复。
toc: true
audio_buffer_duration_chart:
  animationDuration: 500
  tooltip:
    trigger: axis
    axisPointer:
      type: cross
  legend:
    data: ['44.1 kHz', '48 kHz']
    top: 8
  grid:
    top: 58
    left: 58
    right: 24
    bottom: 68
  xAxis:
    type: category
    name: Buffer 帧数
    nameLocation: middle
    nameGap: 34
    data: [128, 256, 512, 1024, 2048, 4096]
  yAxis:
    type: value
    name: 理论时长（ms）
    min: 0
  dataZoom:
    - type: inside
      start: 0
      end: 100
    - type: slider
      height: 18
      bottom: 8
  series:
    - name: '44.1 kHz'
      type: line
      smooth: true
      symbolSize: 8
      data: [2.90, 5.80, 11.61, 23.22, 46.44, 92.88]
    - name: '48 kHz'
      type: line
      smooth: true
      symbolSize: 8
      data: [2.67, 5.33, 10.67, 21.33, 42.67, 85.33]
---

`AVAudioEngine` 是 AVFoundation/AVFAudio 中的高级音频图引擎。它不是一个简单播放器，而是一个可以把多个音频节点连接起来的实时音频处理系统：你可以播放文件、采集麦克风、混音、加效果、录音、做离线渲染，甚至自己提供音频数据源。

理解它的关键是把它当成一条“音频流水线”：

```text
音频来源 -> 处理节点 -> 混音节点 -> 输出节点 -> 扬声器/耳机
 input   -> effect -> mixer -> output
```

---

## 目录

1. [先建立整体模型](#1-先建立整体模型)
2. [AVAudioEngine 的图结构](#2-avaudioengine-的图结构)
3. [节点 Node、总线 Bus 与格式 Format](#3-节点-node总线-bus-与格式-format)
4. [Engine 的典型启动流程](#4-engine-的典型启动流程)
5. [播放文件的最小例子](#5-播放文件的最小例子)
6. [录音与 installTap](#6-录音与-installtap)
7. [实时线程约束](#7-实时线程约束)
8. [混音与音频效果](#8-混音与音频效果)
9. [Manual Rendering 离线渲染](#9-manual-rendering-离线渲染)
10. [AVAudioSession 与硬件路由](#10-avaudiosession-与硬件路由)
11. [配置变化、中断与重启](#11-配置变化中断与重启)
12. [常见坑位清单](#12-常见坑位清单)
13. [学习路线与练习](#13-学习路线与练习)
14. [参考资料](#14-参考资料)

---

## 1. 先建立整体模型

`AVAudioEngine` 的职责是管理一张音频处理图。图里的每个点都是 `AVAudioNode`，节点之间用 `connect` 建立音频流向。Engine 负责把这些节点组织起来，并在实时音频线程中持续拉取、处理、输出音频帧。

可以把它拆成三层来理解：

| 层级 | 代表对象 | 作用 |
| :--- | :--- | :--- |
| 系统音频策略层 | `AVAudioSession` | 告诉系统 App 要播放、录音、后台播放、蓝牙、外放还是混音。 |
| 图管理层 | `AVAudioEngine` | 管理节点、连接关系、启动/停止渲染、处理配置变化。 |
| 音频处理层 | `AVAudioNode` 子类 | 真正产生、接收、混合、转换或处理音频数据。 |

一句话记忆：

> `AVAudioSession` 决定“能不能用硬件、怎么用硬件”，`AVAudioEngine` 决定“音频数据在 App 里怎么流动”。

---

## 2. AVAudioEngine 的图结构

Engine 内部是一张有方向的图。音频信号通常从源头节点出发，经过一个或多个处理节点，最后流向输出节点。

下面这张图把 `AVAudioSession` 和 Engine 音频图放在一起：Session 负责选择硬件策略和路由，但它本身不是图中的音频处理节点；真正的 PCM 数据在 Engine 节点之间流动。

{% capture audio_engine_topology %}
@startuml
top to bottom direction
skinparam componentStyle rectangle
skinparam shadowing false

rectangle "App 内的 AVAudioEngine 图" {
  component "AVAudioPlayerNode\n文件 / Buffer" as Player
  component "inputNode\n麦克风输入" as Input
  component "Audio Unit\nEQ / Reverb" as Effect
  component "mainMixerNode\n混音 / 格式汇合" as Mixer
  component "outputNode\n输出边界" as Output

  Player -down-> Effect : PCM
  Effect -down-> Mixer : processed PCM
  Input -down-> Mixer : input PCM
  Mixer -down-> Output : mixed PCM
}

rectangle "AVAudioSession\nCategory / Mode / Route" as Session
cloud "麦克风" as Microphone
cloud "扬声器 / 耳机" as Speaker

Session ..> Input : 配置输入策略
Session ..> Output : 配置输出策略
Microphone -down-> Input : capture
Output -down-> Speaker : playback
@enduml
{% endcapture %}

{% include plantuml.html
  source=audio_engine_topology
  alt="AVAudioSession、AVAudioEngine 节点图与音频硬件之间的关系"
  caption="控制关系使用虚线，PCM 音频流使用实线。点击图片可在 PlantUML 中查看源码。"
%}

常见图结构：

```text
播放本地文件:
AVAudioPlayerNode -> mainMixerNode -> outputNode

播放并加混响:
AVAudioPlayerNode -> AVAudioUnitReverb -> mainMixerNode -> outputNode

麦克风监听:
inputNode -> mainMixerNode -> outputNode

麦克风录音但不外放:
inputNode -- installTap --> 写入文件/分析波形

多个音源混音:
playerNodeA ----\
playerNodeB ----- mainMixerNode -> outputNode
inputNode -------/
```

Engine 默认自带三个重要节点：

| 节点 | 类型 | 说明 |
| :--- | :--- | :--- |
| `inputNode` | `AVAudioInputNode` | 系统输入，通常代表麦克风或外接输入设备。 |
| `mainMixerNode` | `AVAudioMixerNode` | 主混音器，多个输入会在这里混合成一路输出。 |
| `outputNode` | `AVAudioOutputNode` | 系统输出，通常代表扬声器、耳机、蓝牙设备。 |

除了这些系统节点，常用自定义节点还有：

| 节点 | 作用 |
| :--- | :--- |
| `AVAudioPlayerNode` | 播放 `AVAudioFile` 或 `AVAudioPCMBuffer`。 |
| `AVAudioUnitEQ` | 均衡器。 |
| `AVAudioUnitReverb` | 混响。 |
| `AVAudioUnitDelay` | 延迟效果。 |
| `AVAudioSourceNode` | 通过回调主动生成音频数据。 |
| `AVAudioSinkNode` | 在输入链路中实时接收音频数据。 |
| `AVAudioEnvironmentNode` | 3D/空间音频渲染。 |

---

## 3. 节点 Node、总线 Bus 与格式 Format

### 3.1 Node：音频处理单元

所有音频节点都继承自 `AVAudioNode`。不同节点的能力不同：

- 有的节点只有输出，没有输入，比如 `AVAudioPlayerNode`、`AVAudioSourceNode`。
- 有的节点有输入也有输出，比如 `AVAudioUnitReverb`、`AVAudioMixerNode`。
- 有的节点只接收输入，比如 `AVAudioSinkNode`。
- 系统的 `inputNode` 和 `outputNode` 对接真实音频硬件。

使用节点时，一般遵循：

```swift
let engine = AVAudioEngine()
let player = AVAudioPlayerNode()

engine.attach(player)
engine.connect(player, to: engine.mainMixerNode, format: nil)
```

注意：`inputNode`、`outputNode`、`mainMixerNode` 是 Engine 管理的内建节点，不需要手动 `attach`。

### 3.2 Bus：节点上的输入/输出通道口

Bus 可以理解成节点身上的接口。一个节点可能有多个输入 bus 或输出 bus。

`AVAudioMixerNode` 是最典型的多输入节点：

```text
playerA output bus 0 -> mixer input bus 0
playerB output bus 0 -> mixer input bus 1
mic     output bus 0 -> mixer input bus 2
```

常用简化连接：

```swift
engine.connect(player, to: engine.mainMixerNode, format: audioFile.processingFormat)
```

如果需要精确指定 bus，可以使用：

```swift
engine.connect(player,
               to: engine.mainMixerNode,
               fromBus: 0,
               toBus: engine.mainMixerNode.nextAvailableInputBus,
               format: audioFile.processingFormat)
```

### 3.3 Format：音频数据的形状

`AVAudioFormat` 描述一段音频数据的格式，常见信息包括：

- 采样率：例如 `44100 Hz`、`48000 Hz`
- 声道数：单声道、双声道、多声道
- 采样格式：常见为 Float32 PCM
- interleaved/non-interleaved：多声道数据是否交错存储

格式不一致时，Engine 可以在一些节点上自动做转换。特别是 mixer 节点可以接收不同采样率、不同声道数的输入，并转换成自己的输出格式。

但是不要滥用自动转换。音频链路越复杂，越应该主动确认格式：

```swift
let inputFormat = engine.inputNode.outputFormat(forBus: 0)
let mixerFormat = engine.mainMixerNode.outputFormat(forBus: 0)

print("input:", inputFormat)
print("mixer:", mixerFormat)
```

---

## 4. Engine 的典型启动流程

搭建一个 Engine 通常分为六步：

1. 配置 `AVAudioSession`
2. 创建 `AVAudioEngine`
3. 创建需要的自定义节点
4. `attach` 节点
5. `connect` 节点
6. `prepare`、`start`，然后让源节点开始工作

示意代码：

```swift
import AVFoundation

final class AudioEngineController {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    func setup() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)

        engine.prepare()
        try engine.start()
    }
}
```

几个方法的语义要分清楚：

| 方法 | 作用 |
| :--- | :--- |
| `prepare()` | 预分配渲染资源，减少首次启动时的实时开销。 |
| `start()` | 启动 Engine 的渲染流程，可能抛出错误。 |
| `pause()` | 暂停 Engine，但保留已准备好的资源。 |
| `stop()` | 停止 Engine，并释放 `prepare()` 准备的资源。 |
| `reset()` | 重置所有节点状态，通常会清理调度队列和渲染状态。 |

一个重要细节：`engine.start()` 只是启动音频图渲染，`player.play()` 才是让 `AVAudioPlayerNode` 真正开始吐数据。两者缺一不可。

从时序上看，推荐先完成图配置和数据调度，再启动 Engine，最后让 player 进入播放状态：

{% capture audio_engine_start_sequence %}
@startuml
skinparam shadowing false
actor App
participant AVAudioSession as Session
participant AVAudioEngine as Engine
participant AVAudioPlayerNode as Player
participant "实时渲染线程" as Render

App -> Session : setCategory(...)
App -> Session : setActive(true)
App -> Engine : attach(player)
App -> Engine : connect(player, mixer)
App -> Player : scheduleFile(...)
App -> Engine : prepare()
App -> Engine : start()
Engine -> Render : 启动 pull / render
App -> Player : play()

loop 每个 render quantum
  Render -> Player : 请求下一批 frames
  Player --> Render : PCM 数据或静音
end
@enduml
{% endcapture %}

{% include plantuml.html
  source=audio_engine_start_sequence
  alt="AVAudioEngine 启动与 AVAudioPlayerNode 播放时序图"
  caption="Engine 建立渲染时钟，Player 只在已调度且进入 play 状态后提供音频数据。"
%}

---

## 5. 播放文件的最小例子

`AVAudioPlayerNode` 本身不直接持有文件路径。它需要你先创建 `AVAudioFile`，再把文件或 buffer 调度给 player。

```swift
import AVFoundation

final class FilePlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?

    func load(url: URL) throws {
        let file = try AVAudioFile(forReading: url)
        audioFile = file

        engine.attach(player)
        engine.connect(player,
                       to: engine.mainMixerNode,
                       format: file.processingFormat)
    }

    func play() throws {
        guard let audioFile else { return }

        if !engine.isRunning {
            engine.prepare()
            try engine.start()
        }

        player.stop()
        player.scheduleFile(audioFile, at: nil) {
            print("schedule completed")
        }
        player.play()
    }

    func stop() {
        player.stop()
        engine.stop()
    }
}
```

### 播放流程拆解

```text
AVAudioFile
  |
scheduleFile
  |
AVAudioPlayerNode
  |
mainMixerNode
  |
outputNode
  |
扬声器/耳机
```

### player 与 engine 的关系

| 操作 | 影响 |
| :--- | :--- |
| `engine.start()` | 音频图开始渲染，但没有源节点时可能是静音。 |
| `player.scheduleFile(...)` | 把要播放的数据排进 player 的队列。 |
| `player.play()` | player 开始按照渲染时钟输出已调度的数据。 |
| `player.pause()` | 暂停 player，不等于暂停整个 Engine。 |
| `player.stop()` | 停止 player，并清掉未播放完的调度内容。 |

---

## 6. 录音与 installTap

`installTap` 可以在某个节点的指定 bus 上“偷听”音频数据。它常用于录音、波形绘制、音量检测、频谱分析。

最常见的是在 `inputNode` 上安装 tap：

```swift
import AVFoundation

final class MicRecorder {
    private let engine = AVAudioEngine()
    private var outputFile: AVAudioFile?

    func startRecording(to url: URL) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord,
                                mode: .default,
                                options: [.defaultToSpeaker])
        try session.setActive(true)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        outputFile = try AVAudioFile(forWriting: url, settings: format.settings)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self, let outputFile = self.outputFile else { return }

            do {
                try outputFile.write(from: buffer)
            } catch {
                print("write audio failed:", error)
            }
        }

        engine.prepare()
        try engine.start()
    }

    func stopRecording() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        outputFile = nil
    }
}
```

### installTap 的特点

- 可以在 Engine 运行时安装和移除。
- 同一个 bus 上只能安装一个 tap。
- tap block 不在主线程执行，不要直接更新 UI。
- tap 适合观察和录制，不适合做重度阻塞任务。

如果要做高实时性的输入处理，`AVAudioSinkNode` 往往比 tap 更接近实时音频渲染链路。

---

## 7. 实时线程约束

音频系统最怕“卡”。在实时渲染场景下，硬件会按照固定节奏不断要下一批音频帧。如果你的处理代码超时，就会出现爆音、断裂、杂音或静音。

在以下回调里要格外克制：

- `AVAudioSourceNode` render block
- `AVAudioSinkNode` receiver block
- `installTap` block
- 自定义 Audio Unit render block

其中 Source/Sink/Audio Unit 的 render 回调具有最严格的实时约束。`installTap` 的回调也不是主线程，并且跟随音频数据持续到达；即使它不等同于自定义 Audio Unit 的 render block，也应保持轻量，把编码、文件整理和 UI 工作移交给普通工作线程。

实时回调里尽量不要做：

- 不要分配大量内存
- 不要读写磁盘
- 不要同步网络请求
- 不要等待锁、信号量、`DispatchGroup`
- 不要调用可能阻塞的主线程同步逻辑
- 不要做复杂 JSON 解析、数据库写入等业务工作

更好的做法：

```text
实时线程:
采集少量必要数据 -> 写入 lock-free/ring buffer -> 立即返回

普通工作线程:
从 buffer 取数据 -> 分析/编码/写文件/刷新 UI
```

`prepare()` 的意义也在这里：提前准备资源，减少第一次启动渲染时的实时压力。

### Buffer 大小对应多少处理时间

帧数本身不代表时间，需要结合采样率换算：

```text
单个 buffer 的理论时长（ms） = frameCount ÷ sampleRate × 1000
```

{% include echarts.html
  id="audio-buffer-duration-chart"
  option=page.audio_buffer_duration_chart
  height="440px"
  label="44.1 kHz 与 48 kHz 下不同 Buffer 帧数对应的理论时长"
%}

图表可以悬停查看数值、切换采样率系列，并通过底部滑块缩放。几个常用量级：

| Buffer | 44.1 kHz | 48 kHz |
| :--- | ---: | ---: |
| 128 frames | 2.90 ms | 2.67 ms |
| 256 frames | 5.80 ms | 5.33 ms |
| 512 frames | 11.61 ms | 10.67 ms |
| 1024 frames | 23.22 ms | 21.33 ms |

这只是“一批 PCM 数据覆盖多长时间”，不是完整的端到端延迟。真实延迟还会叠加 I/O buffer、硬件、格式转换、效果器预读以及线程调度成本。Buffer 越小，理论响应越快，但回调频率越高，留给每次处理的时间也越少。

---

## 8. 混音与音频效果

混音就是把多路音频合成一路。`mainMixerNode` 已经是一个 mixer，如果需要更复杂的层级，也可以自己创建 `AVAudioMixerNode`。

### 8.1 多个 player 混音

```swift
let engine = AVAudioEngine()
let drum = AVAudioPlayerNode()
let bass = AVAudioPlayerNode()
let vocal = AVAudioPlayerNode()

engine.attach(drum)
engine.attach(bass)
engine.attach(vocal)

engine.connect(drum, to: engine.mainMixerNode, format: nil)
engine.connect(bass, to: engine.mainMixerNode, format: nil)
engine.connect(vocal, to: engine.mainMixerNode, format: nil)
```

每个 `AVAudioPlayerNode` 都遵守 `AVAudioMixing`，可以单独调音量、声像等参数：

```swift
drum.volume = 0.8
bass.volume = 0.7
vocal.volume = 1.0
```

主混音器也可以整体控制输出：

```swift
engine.mainMixerNode.outputVolume = 0.9
```

### 8.2 加效果节点

效果节点通常插在 player 和 mixer 之间：

```swift
let engine = AVAudioEngine()
let player = AVAudioPlayerNode()
let reverb = AVAudioUnitReverb()

reverb.loadFactoryPreset(.largeHall)
reverb.wetDryMix = 35

engine.attach(player)
engine.attach(reverb)

engine.connect(player, to: reverb, format: nil)
engine.connect(reverb, to: engine.mainMixerNode, format: nil)
```

信号路径：

```text
player -> reverb -> mainMixerNode -> outputNode
```

如果要给一组声音统一加效果，可以先把它们混到一个子 mixer，再接效果：

```text
playerA ----\
playerB ----- subMixer -> reverb -> mainMixerNode -> outputNode
playerC ----/
```

---

## 9. Manual Rendering 离线渲染

默认情况下，Engine 由音频硬件驱动，按照真实时间播放。比如一段 60 秒音频，正常听完就要 60 秒。

Manual Rendering 模式下，Engine 不再连接硬件输出，而是由 App 主动调用渲染方法，把音频帧渲染进 buffer。它常用于：

- 离线加效果并导出新文件
- 比实时更快地处理整段音频
- 做音频分析，不需要真正播放出来
- 单元测试音频处理链路

典型流程：

```swift
let maxFrames: AVAudioFrameCount = 4096
let format = engine.mainMixerNode.outputFormat(forBus: 0)

try engine.enableManualRenderingMode(.offline,
                                     format: format,
                                     maximumFrameCount: maxFrames)

try engine.start()
player.play()

let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
                              frameCapacity: engine.manualRenderingMaximumFrameCount)!

while engine.manualRenderingSampleTime < targetFrameCount {
    let framesToRender = min(buffer.frameCapacity,
                             AVAudioFrameCount(targetFrameCount - engine.manualRenderingSampleTime))

    let status = try engine.renderOffline(framesToRender, to: buffer)

    switch status {
    case .success:
        // 将 buffer 写入文件，或送入分析算法
        break
    case .insufficientDataFromInputNode:
        break
    case .cannotDoInCurrentContext:
        break
    case .error:
        break
    @unknown default:
        break
    }
}
```

需要注意：

- Manual Rendering 不依赖真实扬声器或耳机。
- App 自己驱动每一批 frame 的渲染。
- Voice processing 等依赖真实 I/O 的能力通常不能用于离线渲染。
- 不是所有节点都支持 manual rendering，例如 `AVAudioSinkNode` 不支持。

---

## 10. AVAudioSession 与硬件路由

在 iOS 上，很多 AVAudioEngine 问题看起来像 Engine 错误，本质其实是 `AVAudioSession` 没配置好。

### 10.1 常见 Category

| Category | 适用场景 |
| :--- | :--- |
| `.playback` | 音频播放为核心能力，例如音乐、播客、播放器。 |
| `.record` | 只录音，不播放。 |
| `.playAndRecord` | 既录音又播放，例如语音聊天、K 歌、实时监听。 |
| `.ambient` | 声音不是核心能力，可以和其他 App 混合。 |
| `.soloAmbient` | 默认常见行为，会受静音开关影响，并打断其他音频。 |
| `.multiRoute` | 多路输入输出设备，适合更专业的音频场景。 |

播放文件：

```swift
try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
try AVAudioSession.sharedInstance().setActive(true)
```

录音并外放：

```swift
try AVAudioSession.sharedInstance().setCategory(.playAndRecord,
                                                mode: .default,
                                                options: [.defaultToSpeaker])
try AVAudioSession.sharedInstance().setActive(true)
```

语音聊天或回声消除：

```swift
try AVAudioSession.sharedInstance().setCategory(.playAndRecord,
                                                mode: .voiceChat,
                                                options: [.allowBluetooth])
try AVAudioSession.sharedInstance().setActive(true)
```

### 10.2 Session 与 Engine 的关系

```text
AVAudioSession:
决定硬件策略、权限、路由、采样率倾向、输入输出可用性

AVAudioEngine:
在当前硬件策略下组织音频图并渲染
```

所以排查问题时，顺序通常是：

1. 麦克风权限是否开启
2. `AVAudioSession` category 是否匹配
3. session 是否 `setActive(true)`
4. Engine 是否 `start`
5. 源节点是否真的 `play` 或输入是否真的有数据
6. 节点格式、连接方向是否正确

---

## 11. 配置变化、中断与重启

移动设备上的音频硬件环境很不稳定：

- 插入/拔出耳机
- 蓝牙设备连接或断开
- 来电、Siri、闹钟打断
- 系统改变采样率或声道数
- App 进入后台或恢复前台

Engine 可能收到配置变化通知：

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleEngineConfigurationChange),
    name: .AVAudioEngineConfigurationChange,
    object: engine
)

@objc private func handleEngineConfigurationChange(_ notification: Notification) {
    // 重新读取 input/output format
    // 必要时断开并重连节点
    // 重新 start engine
}
```

还需要监听 `AVAudioSession` 中断：

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleInterruption),
    name: AVAudioSession.interruptionNotification,
    object: AVAudioSession.sharedInstance()
)

@objc private func handleInterruption(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
        return
    }

    switch type {
    case .began:
        engine.pause()
    case .ended:
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
        } catch {
            print("restart failed:", error)
        }
    @unknown default:
        break
    }
}
```

这里最重要的思路是：不要假设 Engine 启动后永远稳定。真实 App 需要能在路由变化、中断结束后恢复音频图。

可以把恢复逻辑设计成显式状态机，避免在多个通知回调里零散地调用 `start()`：

{% capture audio_engine_recovery_state %}
@startuml
skinparam shadowing false

[*] --> Idle
Idle --> Configured : 配置 Session\nattach / connect
Configured --> Running : prepare + start
Running --> Interrupted : interruption began
Interrupted --> Rebuilding : interruption ended\n或 route/config changed
Running --> Rebuilding : configuration changed
Rebuilding --> Running : 重读格式\n必要时重连并 start
Rebuilding --> Failed : 恢复失败
Failed --> Rebuilding : 用户重试 / 条件恢复
Running --> Idle : stop
@enduml
{% endcapture %}

{% include plantuml.html
  source=audio_engine_recovery_state
  alt="AVAudioEngine 中断与配置变化恢复状态机"
  caption="把恢复过程集中到一个状态机中，可以避免通知并发触发造成重复 start 或沿用旧格式。"
%}

---

## 12. 常见坑位清单

### 12.1 只 start engine，却没有 player.play

```swift
try engine.start()
player.scheduleFile(file, at: nil)
// 忘了 player.play()
```

Engine 运行不代表 player 自动播放。Engine 是渲染系统，player 是音频源。

### 12.2 忘记 retain 节点

如果节点是局部变量，函数结束后可能被释放。应该把 Engine 和节点作为对象属性保存：

```swift
final class AudioController {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
}
```

### 12.3 对系统节点 attach

`inputNode`、`outputNode`、`mainMixerNode` 是 Engine 自带节点，不要手动 `attach`。

### 12.4 没有移除旧 tap

同一个 bus 只能装一个 tap。重复安装之前先移除：

```swift
engine.inputNode.removeTap(onBus: 0)
engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
    // ...
}
```

### 12.5 在音频回调里更新 UI

tap/render block 通常不是主线程。更新 UI 要切到主线程：

```swift
DispatchQueue.main.async {
    self.levelView.progress = level
}
```

注意：这段异步派发适合 tap 里的轻量状态更新，不适合高频重任务。实时 render block 里更应该避免频繁派发。

### 12.6 录音时听不到外放

如果使用 `.playAndRecord`，系统可能默认走听筒。需要根据产品需求选择：

```swift
try session.setCategory(.playAndRecord,
                        mode: .default,
                        options: [.defaultToSpeaker])
```

### 12.7 采样率/声道变化后还沿用旧 format

耳机、蓝牙、外接声卡切换后，硬件格式可能变化。收到配置变化后应重新读取：

```swift
let newInputFormat = engine.inputNode.outputFormat(forBus: 0)
let newOutputFormat = engine.outputNode.outputFormat(forBus: 0)
```

### 12.8 大规模改图时机不当

Engine 支持运行时连接、断开和移除节点，但复杂图结构、mixer、声道数变化容易导致图失效。简单参数调整可以运行时做；大规模重连更建议暂停或停止后重新配置。

---

## 13. 学习路线与练习

学习 AVAudioEngine 不要只看 API 名字，最好按小实验推进。

### 13.1 第一阶段：播放

目标：能稳定播放本地音频文件。

练习：

- 用 `AVAudioPlayerNode` 播放一个 wav/mp3/m4a。
- 添加播放、暂停、停止按钮。
- 打印 `audioFile.processingFormat`。
- 对比 `engine.start()` 和 `player.play()` 的不同作用。

### 13.2 第二阶段：录音

目标：理解 inputNode 和 tap。

练习：

- 请求麦克风权限。
- 使用 `.playAndRecord` 配置 session。
- 在 `inputNode` 上安装 tap。
- 把 buffer 写入 caf/wav 文件。
- 根据 buffer 计算音量峰值，做一个简单电平条。

### 13.3 第三阶段：混音与效果

目标：理解图结构。

练习：

- 同时播放两段音乐。
- 给每个 player 设置不同音量。
- 插入 `AVAudioUnitReverb` 或 `AVAudioUnitEQ`。
- 画出自己的节点连接图。

### 13.4 第四阶段：离线处理

目标：理解实时渲染与 manual rendering 的差异。

练习：

- 加载一个音频文件。
- 连接 player -> reverb -> mainMixer。
- 开启 offline manual rendering。
- 把处理后的 buffer 写成新文件。
- 对比离线导出的耗时和音频实际时长。

### 13.5 最终心智模型

```text
AVAudioSession 负责系统音频策略
AVAudioEngine 负责音频图生命周期
AVAudioNode    负责具体音频处理
AVAudioFormat  负责描述音频数据形状
Bus            负责节点之间的连接口
Tap            负责旁路观察/录制音频数据
Manual Render  负责脱离硬件的离线渲染
```

真正掌握 AVAudioEngine 的标志是：看到一个需求时，能先画出节点图，再写代码。

---

## 14. 参考资料

- [AVAudioEngine - Apple Developer Documentation](https://developer.apple.com/documentation/avfaudio/avaudioengine)
- [AVAudioMixerNode - Apple Developer Documentation](https://developer.apple.com/documentation/avfaudio/avaudiomixernode)
- [AVAudioPlayerNode - Apple Developer Documentation](https://developer.apple.com/documentation/avfaudio/avaudioplayernode)
- [AVAudioSession - Apple Developer Documentation](https://developer.apple.com/documentation/avfaudio/avaudiosession)
- [Performing offline audio processing - Apple Developer Documentation](https://developer.apple.com/documentation/avfaudio/performing-offline-audio-processing)
- [What's New in AVAudioEngine - WWDC19](https://developer.apple.com/videos/play/wwdc2019/510/)
