# Core 协议 v1

`include/minivoice_core.h` 提供纯 C ABI；调用者释放 `mv_core_execute` 的返回值（`mv_core_free`），不能使用其他堆分配器释放。空指针表示分配失败。UTF-8 JSON；请求最多 4 MiB，歌词原文最多 1 MiB。无全局可变状态，调用可并发。

请求 `{ "version": 1, "op": "...", ... }`；当前宿主迁移兼容省略 version=1。响应 `{ "version": 1, "ok": true, "value": ... }`，错误 `{ "version": 1, "ok": false, "error": "..." }`。未知操作/协议版本拒绝，不执行其他动作。

时间均为毫秒；纯文本歌词行的 ms=-1；未给出词结束时间为 -1。文本位置为 UTF-16 单元，与 Java/JS 的字符串索引一致。ID 必须为字符串，防止 JS 丢失 Java long 精度。

| op | 参数 | value |
| --- | --- | --- |
| lyrics.parse | raw | `[{ms,text,translation,words:[{ms,endMs,text}]}]` |
| lyrics.sweep | line, next, duration, position | 当前行已显示的 UTF-16 字符数量（浮点） |
| artist.key | value | NFKC casefold + 合并空白 |
| artist.canonical | value, aliases（标准 key→名称） | 归并名称，环路受保护 |
| scan.reusable | previous,current（modified:size） | 两项均已知且相等时 true |
| page.restore | items,identity,index,offset | `{index,offset}`，优先 ID，缺失时夹紧索引 |
| state.reduce | state,action | 合并后的 v1 state |
| library.filter | songs,query | 匹配标题/歌手/专辑的完整歌曲 DTO 数组 |

state action：`navigate`(section,group)、`page`(key,patch，JSON merge patch)、`sort`(category,value)。存储、schema 迁移及写入失败仍由宿主负责。不是数据库，不扫描目录，也不启动音频。

宿主桥接另有 `{version:1,kind,...}` 信封，core 请求放在 request 字段；返回 `{ok,value}` 或 `{ok:false,error}`。Android 只加载本地拦截的 HTTPS 页面、禁用 file/content 读取和外部导航，限制命令集合与大小，歌曲播放必须匹配当前文件夹索引中的 ID；Electron 保留主 frame IPC 校验与命令白名单。
