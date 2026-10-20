import Foundation

@main
struct LRCParserTests {
    static func main() {
        let lines = LRCParser.parse("[offset:250]\n[00:01.20][00:03.000]你好\n[00:04.00]<00:04.00>世<00:04.30>界")
        precondition(lines.count == 3)
        precondition(abs(lines[0].time - 1.45) < 0.001 && lines[0].text == "你好")
        precondition(abs(lines[1].time - 3.25) < 0.001 && lines[1].text == "你好")
        precondition(abs(lines[2].time - 4.25) < 0.001 && lines[2].text == "世界")

        let plain = LRCParser.parse("第一行\n第二行")
        precondition(plain.count == 2 && plain.allSatisfy { $0.time == -1 })
        print("PASS: iOS LRC 时间轴、偏移、逐字标记和纯文本歌词")
    }
}
