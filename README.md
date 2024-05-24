# JBDev

越狱开发利器，比MonkeyDev更强。常见的越狱开发项目类型有：
* 系统App，有根/Applications/???.app或无根/var/jb/Applications/???.app
* Tweak，用于注入并hook某App的动态库
* Tool，用做命令行工具或系统服务
* XPCService，用于通信
* PreferenceBundle，在系统设置中增加菜单和页面实现某些功能

特点：
1. 无需购买开发者账号也无需任何账号，直接使用XCode在越狱设备上进行开发
2. XCode无缝开发普通App，系统App，巨魔App
3. 以上开发均支持调试，包括启动调试和附加调试

todo:
1. 兼容iOS16.x
2. 兼容appex组件
3. JBDev1.0于年底前发布

注意：JBDev和debugserver_azj的区别在于debugserver_azj只是附加调试，可以调试任意进程。

