# Folia 歌词来源对照与 MiniVoice 优化

核对版本：本机 Folia 0.7.19；公开仓库 chthollyphile/folia-major，研究提交 `7701347918a4177c1c57b538d7556db9606be67a`。

## 为什么看到更多逐字效果

- Folia 查询 QQ 音乐原生 QRC、网易云 YRC、酷狗 KRC 与 AMLL TTML。MiniVoice 之前的 QQ 接口只取同步 LRC，且没有 AMLL 原生 TTML。
- Folia 也会为逐行歌词估算逐字时间；所以视觉上有逐字效果不一定代表资源包含真实逐字时间。其歌词 API 文档用 `wordByWord: false` 区分估算。
- MiniVoice 之前候选数量偏少，可能漏掉其他同名版本中的逐字歌词。增加候选同时需要区分 Live，避免把不同演唱版本排到前面。

## 本次变更

- Swift 原生 QQ QRC 解码，保留真实逐字时间；失败回退原来的 LRC 查询。
- 接入 AMLL 原生 TTML（不是会丢失逐字信息的 LrcLib 兼容接口），支持原文、译文及简繁名称查询。
- 增加网易云、QQ、酷狗候选；酷狗按实际内容判断 KRC/文本，并补充直接歌词搜索。
- 标题规范化和 Live 区分；来源仍标记真实的逐字、逐行或普通文本。
- 逐行歌词新增显示层估算扫描：主界面、音乐墙、桌面歌词、在线预览共用逻辑。高亮在字形内部从左到右移动，换行后按阅读顺序继续；未扫到的部分保持较低亮度。正常行间隔按下一行时间估算，长间奏和末行按字数设置上限。播放时只对当前句做 30 Hz 显示插值，暂停和拖动跟随播放时钟。macOS 15 及以上使用原生字形裁剪；旧系统使用逐字亮度过渡。
- 无 Python、模型或额外大型运行时。估算数据不保存，不冒充真实逐字歌词。

## 验证与限制

在线验证 QQ《年轮说》、AMLL《晴天》、酷狗《年轮说》均返回真实逐字时间。不能据此保证所有歌曲、所有现场版本都有资源。接口可能限流、调整或临时不可用；AMLL 收录范围有限，当前转换不展示背景人声与罗马音。估算扫描无法识别真实停顿、拖音和每字演唱节奏。

回归测试覆盖 QRC 解码、XML 换行、TTML 英文空格与译文、无效时间降级、Live 匹配、酷狗文本回退，以及显示估算不改写原始数据。

## 参考

- [Folia QQ provider](https://github.com/chthollyphile/folia-major/blob/7701347918a4177c1c57b538d7556db9606be67a/src/utils/lyrics/providers/qqLyricProvider.ts)
- [Folia 歌词 API 与估算标记](https://github.com/chthollyphile/folia-major/blob/7701347918a4177c1c57b538d7556db9606be67a/docs/lyric-api.md)
- [AMLL HTTP API](https://amll.dev/reference/http-api/overview)
- [AMLL LrcLib 兼容接口限制](https://amll.dev/reference/http-api/lrclib)

Folia 源码采用 AGPL-3.0；本次研究接口行为，MiniVoice 使用独立 Swift 实现，不直接移植其 TypeScript 源文件。
