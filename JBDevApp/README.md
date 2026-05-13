## 项目说明

JBDevApp用于测试JBDev的如下开发能力：
* 用JBDev免签名在真机上开发&测试普通App

## 准备

* macOS确保安装XCode，ldid等基础工具
* iOS确保安装appsync

## 建立项目

&emsp;&emsp;JBDevApp是已经配置好的项目，如果要全新配置需要如下操作

>> 新建名为`JBDevApp`的普通iOS App

&emsp;&emsp;配置文件
* `JBDevApp`需要显式ldid签名，在其目录下配置`JBDevApp.ent`
* 将`jbdev.build.sh`放在`.xcodeproj`同级目录
* 将`jbdev.plist`放在`.xcodeproj`同级目录，设置`type`为`app`

&emsp;&emsp;配置`Build Settings`
* Project新增`CODE_SIGNING_ALLOWED`，设置为NO

&emsp;&emsp;配置`Build Phase`
* `JBDevApp`添加`Run Script`最后执行，设置为`bash jbdev.build.sh`
* `JBDevApp`将`jbdev.plist`加入`Copy Bundle Resources`

