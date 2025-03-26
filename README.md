* [For English](#Introduction)

![](https://raw.githubusercontent.com/lich4/JBDev/main/screenshots/launch_debug_sysapp.png)  

![](https://raw.githubusercontent.com/lich4/JBDev/main/screenshots/launch_debug_tweak.png)  

## 简介

JBDev用于Xcode越狱开发及巨魔开发，提供和普通App一样的开发体验，使用Xcode进行编译——安装——调试，已测试环境：
* Xcode12-15
* iOS12-16
* arm64/arm64e
* Checkra1n/Unc0ver/Taurine/Palera1n/Dopamine
* 有根/无根/隐根

### 主要功能

* 支持越狱(有根/无根/隐根)App开发&源码级调试
* 支持巨魔App开发&源码级调试
* 支持Xcode调试任意进程

> 注意事项
* JBDev只能用于越狱设备上调试
* 使用JBDev越狱开发时，打包功能依赖于Theos
* 使用JBDev巨魔开发时，确保已安装TrollStore

> 常见项目类型调试方式一览

|项目类型        |Xcode调试         |调试类型               |
|--------------|------------------|----------------------|
|越狱App        |JBDev             |启动调试/附加调试/等待调试|
|越狱Tweak/Tool |JBDev             |附加调试/等待调试        |
|巨魔App        |JBDev             |启动调试/附加调试/等待调试|
|非越狱App      |MonkeyDev         |启动调试/附加调试/等待调试|

注：
* 启动调试，使用Xcode启动App并使其等待调试器附加
* 附加调试，进程已启动情况下附加调试，lldb使用方式`debugserver --attach=[pid|name]`，Xcode同理
* 等待调试，等待进程启动并自动附加调试，lldb使用方式`debugserver -waitfor=[name]`，Xcode同理

### JBDev核心

> JBDev核心文件
* `jbdev.plist`，控制JBDev在iOS端行为配置文件，开发阶段需随App一起打包，字段如下
* * `type`: 指定JBDev以何种方式打包安装，可指定`app/jailbreak/trollstore`
* `jbdev.build.sh`，控制JBDev打包的脚本

> JBDev核心设置(环境变量)
* `THEOS`，用于JBDev定位Theos以便打包
* `JBDEV_PACKAGE`，应用于App类型Target，用于控制最终打包&安装&调试

## JBDev开发越狱项目

详细实例见JBDevJBTest

### 建立项目

以下配置不依赖于iOSOpenDev/MonkeyDev

> 使用Xcode建立等同于`theos/application`的项目  
* File - New - Target - iOS - App
* 此为主Target，用于JBDev交互打包/安装/调试

> 使用Xcode建立等同于`theos/tweak`的项目
* File - New - Target - macOS - Library
* Build Settings - `Base SDK`设置为`iOS`，同时部署Device设置为iOS设备

> 使用Xcode建立等同于`theos/tool`的项目
* File - New - Target - macOS - CommandLineTool
* Build Settings - `Base SDK`设置为`iOS`，同时部署Device设置为iOS设备

> 配置文件
* 所有需要ldid签名的Target在自身目录下添加plist文件
* 将`jbdev.build.sh`放在`.xcodeproj`同级目录
* 将`jbdev.plist`放在`.xcodeproj`同级目录，设置`type`为`jailbreak`

> 配置`Build Settings`
* 所有Target调整`Installation Directory`
* Project新增`CODE_SIGNING_ALLOWED`，设置为NO
* Project新增`THEOS`，设置为theos路径
* 主Target新增`JBDEV_PACKAGE`，设置为YES(此变量控制是否打包)

> 配置`Build Phase`
* 所有Target添加`Run Script`最后执行，设置为`bash jbdev.build.sh`
* 主Target将其他项目设置为依赖项

### 无根/隐根配置

> Theos支持为有根/无根/隐根提供layout扩展
* `layout_root`目录，存放有根与无根/隐根文件diff
* `layout_rootless`目录，存放无根与有根/隐根文件diff
* `layout_roothide`目录，存放隐根与有根/无根文件diff

> 常用diff文件如下
* `layout*/DEBIAN/control`，
* * 有根`Architecture`为`iphoneos-arm`
* * 无根`Architecture`为`iphoneos-arm64`
* * 隐根`Architecture`为`iphoneos-arm64e`
* `layout*/DEBIAN/{preinst,postinst,extrainst_,prerm,postrm}`
* `layout*/Library/LaunchDaemons/*.plist`

> 注意事项  
* `layout/DEBIAN/control`的`Architecture`和`Xcode Build Settings`的`Architecture`没有关系，有根包的实际arch可以为`armv7/arm64/arm64e`，无根包/隐根包的实际arch可以为`arm64/arm64e`
* 必须在`layout/DEBIAN`的`postinst`或`extrainst_`中执行`uicache`否则因系统App未注册而安装失败

#### 有根/无根/隐根编译切换

此方式每次可编译有根/无根/隐根中的一种，操作方式如下

> 通用
* Tweak设置`Runpath Search Paths` `Header Search Paths` `Framework Search Paths`
* Tweak链接`libsubstrate.tbd`
> 有根
* 所有Target的`Build Settings`的`THEOS_PACKAGE_SCHEME`删除
> 无根
* 所有Target的`Build Settings`的`THEOS_PACKAGE_SCHEME`设置为`rootless`
* `Preprocessor Macros`中设置`THEOS_PACKAGE_SCHEME_ROOTLESS`
> 隐根
* 所有Target的`Build Settings`的`THEOS_PACKAGE_SCHEME`设置为`roothide`
* `Preprocessor Macros`中设置`THEOS_PACKAGE_SCHEME_ROOTHIDE`
* Tweak链接`libroothide.tbd`

## 单独启动调试Tweak

详细实例见JBDevTweakTest。由于JBDev可以调试任意App，因此可以源码级调试注入App的Tweak。原理如下：
* 建立一个和目标App的BundleID相同的空App(`FakeApp`)
* Xcode执行打包安装调试，JBDev跳过安装
* 目标App启动，开始调试Tweak

> 使用Xcode建立`FakeApp`
* File - New - Target - iOS - App

> 配置文件
* 将`jbdev.build.sh`放在`.xcodeproj`同级目录
* 将`jbdev.plist`放在`.xcodeproj`同级目录，设置`type`为`jailbreak`

> 配置`Build Settings`
* 所有Target新增`CODE_SIGNING_ALLOWED`，设置为NO
* `FakeApp`新增`JBDEV_PACKAGE`，设置为YES(此变量控制是否打包)
* `FakeApp`新增`JBDEV_NO_COPY`，防止安装FakeApp本身

> 配置`Build Phase`
* 所有Target添加`Run Script`最后执行，设置为`bash jbdev.build.sh`
* `FakeApp`将Tweak设置为依赖项 

> 注意
* `SpringBoard`不属于App类型，不可调试
* 由于Xcode不支持非源码下断点，因此不支持调试logos语法的Tweak，如果谁有黑科技可以实现强制下断点请在issue里提交

## JBDev开发巨魔项目

详细实例见JBDevTSTest。前置条件：iOS系统需要能越狱且能使用巨魔

> 使用Xcode建立普通iOS-App的项目
* File - New - Target - iOS - App

> 配置文件
* 在自身Target目录下添加需要签名的plist文件
* 将`jbdev.build.sh`放在`.xcodeproj`同级目录
* 将`jbdev.plist`放在`.xcodeproj`同级目录，设置`type`为`trollstore`

> 配置`Build Settings`
* Target新增`CODE_SIGNING_ALLOWED`，设置为NO
* Target新增`JBDEV_PACKAGE`，设置为YES(此变量控制是否打包)

> 配置`Build Phase`
* 所有Target添加`Run Script`最后执行，设置为`bash jbdev.build.sh`

> 注意事项
* 巨魔App开发，由于纯巨魔环境与越狱环境有较大差异，因此后续需要在纯巨魔环境进一步测试

## JBDev编译

```bash
cd JBDev
make clean; make package
make clean; make package THEOS_PACKAGE_SCHEME=rootless
make clean; make package THEOS_PACKAGE_SCHEME=roothide
```

## 问题排查

在使用JBDev遇到问题时，可以
* 查看系统日志(前缀`JBDev`)
* 查看文件日志`/tmp/jbdev.log`

其他注意事项
* 对于iOS>=15，首次连接Mac必须使用XCode>=13，否则会因生成的符号缓存有误导致lldb初始化时间巨长，若已生成错误的符号缓存可以在此目录手动删除`~/Library/Developer/Xcode/iOS DeviceSupport/[设备]`

------

```
A system application with the given bundle identifier is already installed on the device and cannot be replaced.
```
* 原因：安装成功但获取App信息失败(如`extrainst_`未执行`uicache`)
* 解决：直接dpkg卸载报错，需要先手动安装deb，再卸载deb；或者手动删App目录再uicache
* 注意：`uicache`根据越狱工具不同参数不同

---

```
Failed to start remote service "com.apple.debugserver" on device.
```
* 解决：插拔usb重试

## Introduction

JBDev is a powerful tool for Jailbreak/TrollStore development with Xcode, suppling the same experience as common app development: compile - install - debug app with Xcode, tested on
* Xcode12-15
* iOS12-16
* arm64/arm64e
* Checkra1n/Unc0ver/Taurine/Palera1n/Dopamine
* rootful/rootless/roothide

### Features

* Jailbreak(rootful/rootless/roothide) development with sourcecode-level debugging with Xcode
* TrollStore development with sourcecode-level debugging with Xcode
* Debug any process with Xcode

> Notice
* JBDev is used on jailbreak devices
* For Jailbreak development, JBDev use Theos to package 
* For TrollStore development, make sure TrollStore is installed

## Jailbreak development demo

See JBDevJBTest for details

### Set up a project

> Set up a project identical to `theos/application` 
* File - New - Target - iOS - App
* This is the main target

> Set up a project identical to `theos/tweak`
* File - New - Target - macOS - Library
* Build Settings - set `Base SDK` to `iOS`，and set the deployment target to your iOS device

> Set up a project identical to `theos/tool`
* File - New - Target - macOS - CommandLineTool
* Build Settings - set `Base SDK` to `iOS`，and set the deployment target to your iOS device

> Prepare files
* Add entitlement plist files to the target sourcecode directory for each target
* Put `jbdev.build.sh` to the same directory level of `.xcodeproj`
* Put`jbdev.plist` to the same directory level of `.xcodeproj`, and set `type` to `jailbreak`

> Configure `Build Settings`
* Set `Installation Directory` for all targets
* Add `CODE_SIGNING_ALLOWED` to project and set to NO
* Add `THEOS` to project according to the path of your theos
* Add `JBDEV_PACKAGE` to the main target and set to YES

> Configure `Build Phase`
* Add `Run Script` to all target as the last phase，and set content to `bash jbdev.build.sh`
* Add all other targets to the main target as dependency

### rootless/roothide configuration

> JBDev support rootful/rootless/roothide well as follows
* `layout_root` directory，stores the diffs from rootful to rootless/roothide  
* `layout_rootless` directory，stores the diffs from rootless to rootful/roothide  
* `layout_roothide` directory，stores the diffs from roothide to rootful/rootless

> Commonly used diffs
* `layout*/DEBIAN/control`，
* * `Architecture` is `iphoneos-arm` for rootful
* * `Architecture` is `iphoneos-arm64` for rootless
* * `Architecture` is `iphoneos-arm64e` for roothide
* `layout*/DEBIAN/{preinst,postinst,extrainst_,prerm,postrm}`
* `layout*/Library/LaunchDaemons/*.plist`

#### Switch between rootful/rootless/roothide

> general
* For tweak target, set `Runpath Search Paths` `Header Search Paths` `Framework Search Paths`
* For tweak target, link `libsubstrate.tbd` for tweak target
> rootful
* For all targets, remove `THEOS_PACKAGE_SCHEME` from `Build Settings`
> rootless
* For all targets, set `THEOS_PACKAGE_SCHEME` in `Build Settings` to `rootless`
* Set `THEOS_PACKAGE_SCHEME_ROOTLESS` in `Preprocessor Macros`
> roothide
* For all targets, set `THEOS_PACKAGE_SCHEME` in `Build Settings` to `roothide`
* Set `Preprocessor Macros` in `THEOS_PACKAGE_SCHEME_ROOTHIDE`
* For tweak target, link `libroothide.tbd`

## TrollStore development demo

See JBDevTSTest for details

> Set up an iOS App project
* File - New - Target - iOS - App

> Prepare files
* Add entitlement plist files to the target sourcecode directory for each target
* Put `jbdev.build.sh` to the same directory level of `.xcodeproj`
* Put`jbdev.plist` to the same directory level of `.xcodeproj`, and set `type` to `trollstore`

> Configure `Build Settings`
* Add `CODE_SIGNING_ALLOWED` to project and set to NO
* Add `JBDEV_PACKAGE` to the target and set to YES

> Configure `Build Phase`
* Add `Run Script` to the target as the last phase，and set content to `bash jbdev.build.sh`

> Notice
* Due to the huge difference between Jailbreak and pure TrollStore environment, Further testing on pure TrollStore is required

## Compile JBDev

```bash
cd JBDev
make clean; make package
make clean; make package THEOS_PACKAGE_SCHEME=rootless
make clean; make package THEOS_PACKAGE_SCHEME=roothide
```

