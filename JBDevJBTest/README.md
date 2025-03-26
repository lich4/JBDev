## 项目说明

JBDevJBTest用于测试JBDev的如下开发能力：
* 如何用JBDev进行有根越狱开发调试
* 如何用JBDev进行无根越狱开发调试
* 如何用JBDev进行隐根越狱开发调试
* 如何用JBDev调试Tweak

## 准备

* macOS确保安装XCode，Theos，ldid，rsync等基础工具

## 建立项目

&emsp;&emsp;JBDevJBTest是已经配置好的项目，如果要全新配置需要如下操作

>> 新建名为`JBDevTestApp`的Target，等同于`theos/application`，`JBDevTestApp`为主项目
* File - New - Target - iOS - App

>> 新建名为`JBDevTestTweak`的Target，等同于`theos/tweak`
* File - New - Target - macOS - Library
* Build Settings - Base SDK 设置为 iOS，同时部署Device设置为iOS设备

>> 新建名为`JBDevTestDaemon/JBDevTestTool`的Target，等同于`theos/tool`的项目
* File - New - Target - macOS - CommandLineTool
* Build Settings - Base SDK 设置为 iOS，同时部署Device设置为iOS设备

&emsp;&emsp;配置文件
* 确保theos项目的layout目录存在，同目录下增加layout_root/layout_rootless/layout_roothide分别对应有根/无根/隐根的diff
* `JBDevTestApp`需要显式ldid签名，在其目录下配置`JBDevTestApp.plist`
* `JBDevTestDaemon`需要显式ldid签名，在其目录下配置`JBDevTestDaemon.plist`
* `JBDevTestTool`需要显式ldid签名，在其目录下配置`JBDevTestTool.plist`
* 将`jbdev.build.sh`放在`.xcodeproj`同级目录
* 将`jbdev.plist`放在`.xcodeproj`同级目录，设置`type`为`jailbreak`

&emsp;&emsp;配置`Build Settings`
* Project新增`CODE_SIGNING_ALLOWED`，设置为NO
* Project新增`THEOS`，设置为theos路径
* `JBDevTestApp`的`Installation Directory`设置为`/Applications`
* `JBDevTestTweak`的`Installation Directory`设置为`/Library/MobileSubstrate/DynamicLibraries`
* `JBDevTestDaemon/JBDevTestTool`的`Installation Directory`设置为`/usr/bin`
* `JBDevTestApp`新增`JBDEV_PACKAGE`，设置为YES(此变量控制是否打包)

&emsp;&emsp;配置`Build Phase`
* `JBDevTestApp/JBDevTestTweak/JBDevTestDaemon/JBDevTestTool`添加`Run Script`最后执行，设置为`bash jbdev.build.sh`
* `JBDevTestApp`将`JBDevTestTweak/JBDevTestDaemon/JBDevTestTool`设置为依赖项
* `JBDevTestApp`将`jbdev.plist`加入`Copy Bundle Resources`

## 编译&安装&调试

* XCode执行Run会执行安装并开始调试`JBDevTestApp`
* XCode附加调试`JBDevTestDaemon`
* XCode附加调试`系统设置App`以调试`JBDevTestTweak`

## 启动调试Tweak

&emsp;&emsp;启动调试Tweak的原理是建立一个和原App同BundleID的空壳App，在XCode执行Run后JBDev跳过安装直接启动目标App。  
&emsp;&emsp;在本项目中JBDevTestTweak注入`系统设置App`，以下是操作过程
* 建立iOS-App类型的名为`TestTweak`的Target
* `Signing & Capabilities`的`Bundle Identifier`设置`com.apple.Preferences`
* 将`jbdev.plist`放在主项目`TestTweak`下，设置`type`为`jailbreak`
* 在`JBDevTestTweak.m`设置断点，XCode执行Run开始调试

