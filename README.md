# 离线翻译

中文与英语、日语、韩语、法语互译的手机 App，iOS 和 Android 共用一套 Flutter 代码。下载语言包之后，不联网也能用。

## 功能

- **整句翻译**：使用 Google ML Kit 的端上翻译模型，每种语言约 30MB，第一次用到时下载，之后离线可用。可以自动识别输入的语言。
- **查词**：词典内置在 App 里，中文词条带拼音，英文词条带音标，输入时会实时给出联想。
- **记录**：自动保存翻译历史（最近 200 条），可以收藏常用的句子。
- **朗读**：使用手机系统自带的语音朗读原文或译文。
- **设置**：管理已下载的语言包，查看数据来源和许可。

## 词典数据

| 方向 | 来源 | 许可 |
| --- | --- | --- |
| 中 → 英 | CC-CEDICT（约 12 万词条） | CC BY-SA 4.0 |
| 英 → 中 | ECDICT（常用词约 6 万） | MIT |
| 中 ⇄ 法、日、韩 | 维基词典翻译表（kaikki.org 整理） | CC BY-SA 4.0 |

词典文件是 `assets/dict/dictionary.db.gz`，由 `tools/build_dictionary.py` 生成：

```sh
python3 tools/build_dictionary.py               # 只生成中英词典
python3 tools/build_dictionary.py --wiktionary  # 加上法语、日语、韩语（需下载数 GB 的维基词典数据）
```

也可以在 GitHub 的 Actions 页面手动运行 **Build dictionary**，它会生成完整词典并提交到当前分支。

## 开发

需要 Flutter 3.47（Dart 3.13）或更高版本。iOS 最低支持 15.5（ML Kit 的要求），Android 使用 Flutter 默认的最低版本。

```sh
flutter pub get
flutter run          # 连接手机或模拟器运行
flutter test         # 运行测试
```

ML Kit 不支持 Apple 芯片 Mac 上的 iOS 模拟器（arm64），iOS 请用真机或 Rosetta 模拟器测试。

## 目录结构

```
lib/
  main.dart                  启动、加载词典
  models/                    语言、词条、翻译记录
  services/                  翻译、词典、历史收藏、朗读、语言识别
  screens/                   翻译、词典、记录、设置四个页面
  widgets/                   共用组件
tools/build_dictionary.py    生成词典数据
```
