# 轻量歌词 AI 原型

独立实验，未接入正式应用。现有 stable-ts/Python/PyTorch 和 small.pt 均保留。

原型由 whisper.cpp（Metal）、small-q5_1 量化模型、Swift 编排器和原生 C++ 局部强制对齐器组成。V1 的识别后匹配模式保留供对比。V2 先用识别结果定位粗略窗口，再约束解码严格按原歌词顺序进行，使用跨注意力 DTW 提取时间。重叠窗口结果须一致，且需独立的无歌词提示识别结果支持。低声学得分、时序不合法或缺乏独立证据的行返回空时间，不按全曲时长平分。

V3 增加语言感知的 Unicode 规范化、跨 token 组合字符重组、语言代码别名、文本/音频联合选语、局部语种窗口与跨语言上下文。`NaturalLanguage` 使用系统框架，不额外打包语言识别模型。多语言验证和限制见 `V3多语言报告.md`。

## 复现

1. 安装 CMake，或用独立环境 `python3 -m venv .build/cache/lyrics-lite-tools`、`.build/cache/lyrics-lite-tools/bin/pip install cmake`。Python 仅用于构建工具和基准测试，原型运行程序不需要 Python。
2. 克隆 <https://github.com/ggml-org/whisper.cpp> 到 `.build/cache/whisper-lite-source`，检出 `0c7be696371069e0baa2515ed7aa08d5a5473aa6`。
3. 准备 [small-q5_1 模型](https://huggingface.co/ggerganov/whisper.cpp/blob/5359861/ggml-small-q5_1.bin) 到 `.build/work/experiments/lyrics-lite/models/ggml-small-q5_1.bin`。SHA-256：`ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb`。本次文件来自 hf-mirror，字节校验与模型仓库 LFS 元数据一致。
4. 执行 `bash Experiments/LyricsLite/build.sh`。实验包生成于 `.build/work/experiments/lyrics-lite/package`，包含原生二进制、动态库、模型及许可。没有将实验大文件加入正式 Vendor 或发行包。
5. `python3 Experiments/LyricsLite/benchmark.py` 对当前本地曲库四个指定片段做只读测试；自定义目录使用 `MINIVOICE_LITE_MUSIC`。脚本中的曲目序号对应本机测试集，其他曲库需先调整 fixtures。`--resume` 可以复用已经完成的结果。

正式版本的比较基线是 `.build/work/native/MiniVoice.app/Contents/Resources` 中的 worker 与 small 模型；请先准备正式应用产物。

## 输入和输出

`lyrics-lite request.json output.json`。请求包含 `audioPath`、`duration`、`lines`、`language`、`modelPath`、`cliPath`、`ffmpegPath`，以及可选的 `useLyricsPrompt`。将 `forceAlignerPath` 指向实验包 `bin/lyrics-force` 即启用 V2。输出保留每一行的 `text`、`start`、`end`、`confidence`，未匹配时间为 null。调试音频、ASR JSON 和日志只写到输出旁的实验目录，歌曲源文件与歌词文件不修改。

`language` 支持 `auto` 或模型的语言代码，常见 BCP-47 标记如 `zh-Hant-TW`、`ko_KR`、`fr-CA` 会转成模型代码。`auto` 优先使用高置信的歌词文本语言提示，无法判断时由音频识别；它不是“音频与文本一定同语种”的保证。输出旁的 `*.diagnostics.json` 记录请求、选择的语言及各语种窗口数量。不能以推理库识别某个语言代码，就断言当前模型包含该语种专用 token；原生对齐器会再次校验模型的 token 范围。

`lyrics-lite --self-test` 包含20项匹配/语言检查，覆盖日文汉字、半角假名、韩文组合、重音字母、阿拉伯表现形式、印度文字元音标记和跨token重组等。V1 的 confidence 为文本匹配覆盖率，V2/V3 为强制前模型 token 概率的几何平均，两者均不是时间戳正确概率，不能直接跨模式比较。V3 对较低 token 概率的候选要求更强的独立识别支持，不按语种任意降低门槛。

`benchmark.py --full` 测试额外三首完整歌曲；`MINIVOICE_LITE_BENCHMARK_DIR` 可隔离不同版本结果。`negative_tests.py` 验证静音、不相干歌词、错语种歌词不产生匹配。`multilingual_tests.py` 另做日、韩、法、西、德、阿、印地、泰8种系统合成语音的显式语言/自动语言检查，并测试曲库中的一首日文歌曲片段。合成文本由本实验编写，不是歌曲歌词；结果不能推算为歌唱准确率。合成语音的参考时间是各句音频的拼接边界，也不是人工标注的首个音素。

## 结论与边界

详细实测见 `V2改进报告.md`、`v2-benchmark-summary.json`；V1 结果保留在 `对比报告.md`。V2 显著改善部分中文片段，并扩大到完整歌曲及负例检查，但混唱和英文的缺失行仍多，尚不足以替换正式版本。尚未做大批量曲库、不同硬件泛化和人工逐句听音标注。
