import Foundation

// Experimental ASR-to-reference matching. Not a replacement for forced alignment.
struct Request: Decodable {
    let audioPath: String
    let duration: Double
    let lines: [String]
    let language: String
    let modelPath: String
    let cliPath: String
    let ffmpegPath: String
    let useLyricsPrompt: Bool?
    let forceAlignerPath: String?
}
struct Aligned: Codable {
    let text: String
    var start: Double?
    var end: Double?
    let confidence: Double
}
struct TimedCharacter {
    let value: Character
    let start: Double
    let end: Double
}
func normalize(_ text: String, language: String = "auto") -> [Character] {
    LyricLanguage.normalized(text,language:language)
}
func execute(_ binary: String, _ arguments: [String], log: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: binary)
    process.arguments = arguments
    let handle = try FileHandle(forWritingTo: log)
    defer { try? handle.close() }
    try handle.seekToEnd()
    process.standardOutput = handle
    process.standardError = handle
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw NSError(domain: "LyricsLite", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey:"推理失败，见 \(log.path)"]) }
}
func readCharacters(_ url: URL, language: String) throws -> [TimedCharacter] {
    let json=try JSONSerialization.jsonObject(with:Data(contentsOf:url)) as! [String:Any]
    var chunks=[(String,Double,Double)]()
    for segment in json["transcription"] as? [[String:Any]] ?? [] {
        for token in segment["tokens"] as? [[String:Any]] ?? [] {
            let text=token["text"] as? String ?? ""
            guard !text.hasPrefix("[_"), !text.hasPrefix("[<"), let times=token["offsets"] as? [String:Any],
                  let start=times["from"] as? Double, let end=times["to"] as? Double,
                  start>=0,end>start else { continue }
            chunks.append((text,start/1000,end/1000))
        }
    }
    return charactersFromChunks(chunks,language:language)
}
func charactersFromChunks(_ chunks: [(String,Double,Double)], language: String) -> [TimedCharacter] {
    // Model tokens can split a combining vowel or Hangul syllable. Reassemble
    // complete Unicode graphemes before matching instead of dropping marks.
    let text=chunks.map { $0.0 }.joined()
    var ranges=[(Range<Int>,Double,Double)](),position=0
    for (chunk,start,end) in chunks {
        let next=position+chunk.utf8.count
        ranges.append((position..<next,start,end));position=next
    }
    var characters=[TimedCharacter](),offset=0,cursor=0
    for glyph in text {
        let next=offset+String(glyph).utf8.count
        while cursor<ranges.count && ranges[cursor].0.upperBound<=offset { cursor+=1 }
        var covering=[(Double,Double)](),index=cursor
        while index<ranges.count && ranges[index].0.lowerBound<next {
            covering.append((ranges[index].1,ranges[index].2));index+=1
        }
        if let start=covering.map(\.0).min(),let end=covering.map(\.1).max() {
            for value in normalize(String(glyph),language:language) { characters.append(TimedCharacter(value:value,start:start,end:end)) }
        }
        offset=next
    }
    return characters
}
func match(lines: [String], characters: [TimedCharacter], duration: Double, seedsOnly: Bool = false, language: String = "auto") -> [Aligned] {
    let normalized = lines.map { normalize($0,language:language) }
    let reference = normalized.flatMap { $0 }
    let n = reference.count, m = characters.count
    guard n > 0, m > 0, n <= 15000, m <= 15000 else {
        return lines.map { Aligned(text:$0, start:nil, end:nil, confidence:0) }
    }
    // Sequence alignment preserves the order of repeated choruses.
    var trace = [UInt8](repeating:0, count:(n+1)*(m+1))
    var previous = (0...m).map { -2*$0 }
    for i in 1...n {
        var current = [Int](repeating:0, count:m+1)
        current[0] = -2*i
        trace[i*(m+1)] = 1
        for j in 1...m {
            let diagonal = previous[j-1] + (reference[i-1] == characters[j-1].value ? 3 : -3)
            let deletion = previous[j]-2
            let insertion = current[j-1]-2
            let best = max(diagonal,deletion,insertion)
            current[j] = best
            trace[i*(m+1)+j] = best == diagonal ? 0 : best == deletion ? 1 : 2
        }
        previous = current
    }
    var mapping = [Int:Int](), i=n, j=m
    while i>0 || j>0 {
        if i==0 { j-=1; continue }
        if j==0 { i-=1; continue }
        switch trace[i*(m+1)+j] {
        case 0:
            if reference[i-1] == characters[j-1].value { mapping[i-1] = j-1 }
            i-=1; j-=1
        case 1: i-=1
        default: j-=1
        }
    }
    var offset=0, previousEnd=0.0
    return zip(lines,normalized).map { text, letters in
        defer { offset += letters.count }
        let hits = letters.indices.compactMap { k -> (Int,TimedCharacter)? in
            mapping[offset+k].map { (k,characters[$0]) }
        }
        let confidence = Double(hits.count)/Double(max(1,letters.count))
        if seedsOnly, let first=hits.first, let last=hits.last {
            return Aligned(text:text,start:first.1.start,end:last.1.end,confidence:confidence)
        }
        guard let first=hits.first, let last=hits.last, confidence>=0.7,
              first.0<=1, last.0>=letters.count-2,
              first.1.start>=previousEnd, last.1.end>first.1.start,
              last.1.end<=duration+0.1,
              zip(hits,hits.dropFirst()).allSatisfy({ $1.1.start-$0.1.end<3.5 }) else {
            return Aligned(text:text,start:nil,end:nil,confidence:confidence)
        }
        previousEnd=last.1.end
        return Aligned(text:text,start:first.1.start,end:last.1.end,confidence:confidence)
    }
}

do {
    if CommandLine.arguments.dropFirst().first == "--self-test" {
        func check(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain:"LyricsLiteTests",code:1,userInfo:[NSLocalizedDescriptionKey:message]) }
        }
        let tokens = Array("你好你好").enumerated().map { i,c in TimedCharacter(value:c,start:Double(i*2+1),end:Double(i*2+2)) }
        let repeated = match(lines:["你好","你好"],characters:tokens,duration:20)
        try check(repeated.count==2 && repeated[0].start==1 && repeated[1].start==5,"Repeated lines lost their sequence")
        let missing = match(lines:["完全不同"],characters:tokens,duration:20)
        try check(missing[0].start==nil,"Unmatched lyric received fabricated timing")
        let separated = [TimedCharacter(value:"你",start:1,end:2),TimedCharacter(value:"好",start:10,end:11)]
        try check(match(lines:["你好"],characters:separated,duration:20)[0].start==nil,"Large timing gap was accepted")
        try check(normalize("愛，Hello！",language:"zh")==normalize("爱 hello",language:"zh"),"Normalization failed")
        try check(match(lines:["你好"],characters:[],duration:20)[0].start==nil,"Empty ASR was accepted")
        try check(normalize("愛",language:"ja") != normalize("爱",language:"ja"),"Japanese kanji was rewritten")
        try check(normalize("ﾊﾞﾀﾌﾗｲ",language:"ja")==normalize("バタフライ",language:"ja"),"Half-width kana mismatch")
        try check(normalize("cafe\u{301}",language:"fr")==normalize("café",language:"fr"),"Canonical accents mismatch")
        try check(normalize("é",language:"fr") != normalize("e",language:"fr"),"Accents were erased")
        try check(normalize("한",language:"ko")==normalize("한",language:"ko"),"Hangul composition mismatch")
        try check(normalize("ﻻ",language:"ar")==normalize("لا",language:"ar"),"Arabic presentation mismatch")
        try check(normalize("क",language:"hi") != normalize("कि",language:"hi"),"Indic vowel signs were erased")
        try check(LyricLanguage.windowLanguage("君の愛を信じて",fallback:"zh")=="ja","Japanese routing failed")
        try check(LyricLanguage.windowLanguage("너의 사랑을 기억해",fallback:"en")=="ko","Korean routing failed")
        let hindi=charactersFromChunks([("क",1,2),("ि",2,3)],language:"hi")
        try check(hindi.count==1 && hindi[0].value=="कि" && hindi[0].start==1 && hindi[0].end==3,"Split vowel token lost its mark")
        let french=charactersFromChunks([("e",1,2),("\u{301}",2,3)],language:"fr")
        try check(french.count==1 && french[0].value=="é","Split accent token was erased")
        try check(LyricLanguage.code("zh-Hant-TW")=="zh","Chinese locale alias failed")
        try check(LyricLanguage.code("ko_KR")=="ko","Korean locale alias failed")
        try check(LyricLanguage.code("fr-CA")=="fr","French locale alias failed")
        try check(LyricLanguage.code(" AUTO ")=="auto","Auto language alias failed")
        print("20 LyricsLite matching/language regression checks passed")
        exit(0)
    }
    guard CommandLine.arguments.count == 3 else { throw NSError(domain:"LyricsLite",code:1,userInfo:[NSLocalizedDescriptionKey:"Usage: lyrics-lite request.json output.json"]) }
    let request = try JSONDecoder().decode(Request.self,from:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1])))
    guard request.duration.isFinite, request.duration>0, !request.lines.isEmpty,
          request.lines.count<=2000,
          request.lines.reduce(0,{ $0+$1.utf8.count })<=100_000 else {
        throw NSError(domain:"LyricsLite",code:2,userInfo:[NSLocalizedDescriptionKey:"Invalid duration or lyrics size"])
    }
    let output = URL(fileURLWithPath:CommandLine.arguments[2])
    let work = output.deletingLastPathComponent().appendingPathComponent("lite-"+UUID().uuidString)
    try FileManager.default.createDirectory(at:work,withIntermediateDirectories:true)
    let wav=work.appendingPathComponent("audio.wav"), prefix=work.appendingPathComponent("transcript"), log=work.appendingPathComponent("inference.log")
    FileManager.default.createFile(atPath:log.path,contents:Data())
    let began=Date()
    try execute(request.ffmpegPath,["-nostdin","-v","error","-y","-i",request.audioPath,"-map","0:a:0","-vn","-ar","16000","-ac","1","-c:a","pcm_s16le",wav.path],log:log)
    // Known lyrics provide a high-confidence text-language hint. This avoids
    // brief recordings being misdetected as an unrelated acoustic language.
    let requestedLanguage=LyricLanguage.code(request.language)
    let inputLanguage=requestedLanguage=="auto" ? LyricLanguage.windowLanguage(request.lines.joined(separator:" "),fallback:"auto") : requestedLanguage
    var arguments=["-m",request.modelPath,"-f",wav.path,"-l",inputLanguage,"-t","4","-ojf","-of",prefix.path,"-dtw","small","-np"]
    if request.useLyricsPrompt == true { arguments += ["--prompt",request.lines.joined(separator:" "),"--carry-initial-prompt"] }
    try execute(request.cliPath,arguments,log:log)
    let transcript=try JSONSerialization.jsonObject(with:Data(contentsOf:prefix.appendingPathExtension("json"))) as! [String:Any]
    let detected=(transcript["result"] as? [String:Any])?["language"] as? String
    let language=inputLanguage=="auto" ? (detected ?? "en") : inputLanguage
    let characters=try readCharacters(prefix.appendingPathExtension("json"),language:language)
    var diagnostics:[String:Any]=["requestedLanguage":request.language,"inputLanguage":inputLanguage,"modelLanguage":detected ?? "unknown","matchingLanguage":language,"mode":request.forceAlignerPath==nil ? "asr" : "forced"]
    var aligned=match(lines:request.lines,characters:characters,duration:request.duration,language:language)
    if let forcePath=request.forceAlignerPath {
        let independent=work.appendingPathComponent("independent")
        try execute(request.cliPath,["-m",request.modelPath,"-f",wav.path,"-l",language,"-t","4","-ojf","-of",independent.path,"-dtw","small","-np"],log:log)
        let evidence=match(lines:request.lines,characters:try readCharacters(independent.appendingPathExtension("json"),language:language),duration:request.duration,seedsOnly:true,language:language)
        let raw=work.appendingPathComponent("audio.f32")
        try execute(request.ffmpegPath,["-nostdin","-v","error","-y","-i",wav.path,"-f","f32le",raw.path],log:log)
        let decodedSeconds=Double(try Data(contentsOf:raw).count)/64000
        guard abs(decodedSeconds-request.duration)<=max(1,request.duration*0.01) else {
            throw NSError(domain:"LyricsLite",code:3,userInfo:[NSLocalizedDescriptionKey:"Decoded audio duration differs from request; refusing partial alignment"])
        }
        let seeds=match(lines:request.lines,characters:characters,duration:request.duration,seedsOnly:true,language:language)
        let lineLanguages=request.lines.map { LyricLanguage.windowLanguage($0,fallback:language) }
        var windows=[[String:Any]]()
        var windowKeys=Set<String>()
        func addWindow(_ range: Range<Int>,padding:Double=4) {
            let starts=range.compactMap { seeds[$0].start }, ends=range.compactMap { seeds[$0].end }
            guard let earliest=starts.min(), let latest=ends.max() else { return }
            let left=max(0,earliest-padding), right=min(request.duration,latest+padding)
            if right-left>29.5 && range.count>1 {
                for i in range { addWindow(i..<(i+1),padding:padding) }
            } else if right>left && right-left<=29.5 {
                let windowLanguage=LyricLanguage.windowLanguage(range.map { request.lines[$0] }.joined(separator:" "),fallback:language)
                let key="\(range.lowerBound):\(range.upperBound):\(left):\(right):\(windowLanguage)"
                guard windowKeys.insert(key).inserted else { return }
                windows.append(["start":left,"end":right,"language":windowLanguage,"context":"\(range.lowerBound):\(range.upperBound)","firstIndex":range.lowerBound,"lines":range.map { request.lines[$0] }])
            }
        }
        // Re-align overlapping contexts: a line at a crop boundary must agree
        // with the same line inside neighbouring acoustic windows.
        for first in 0..<request.lines.count {
            var end=first+1
            while end<min(first+3,request.lines.count) && lineLanguages[end]==lineLanguages[first] { end+=1 }
            addWindow(first..<end)
            // Keep mixed-language contexts as well as homogeneous ones. A hard
            // language boundary otherwise removes evidence around code switches.
            addWindow(first..<min(first+3,request.lines.count))
        }
        if request.lines.count>=3 {
            addWindow(0..<1)
            if lineLanguages[0]==lineLanguages[1] { addWindow(0..<2) }
        }
        let forcedRequest=work.appendingPathComponent("forced-request.json"), forcedOutput=work.appendingPathComponent("forced-output.json")
        diagnostics["windowsByLanguage"]=Dictionary(grouping:windows,by: { $0["language"] as? String ?? language }).mapValues(\.count)
        try JSONSerialization.data(withJSONObject:["pcmPath":raw.path,"modelPath":request.modelPath,"language":language,"windows":windows],options:.prettyPrinted).write(to:forcedRequest)
        try execute(forcePath,[forcedRequest.path,forcedOutput.path],log:log)
        let rows=try JSONSerialization.jsonObject(with:Data(contentsOf:forcedOutput)) as! [[String:Any]]
        aligned=request.lines.map { Aligned(text:$0,start:nil,end:nil,confidence:0) }
        var candidates=[Int:[(Double,Double,Double,String)]]()
        for row in rows {
            guard let i=row["index"] as? Int, aligned.indices.contains(i) else { continue }
            let score=row["confidence"] as? Double ?? 0
            if let start=row["start"] as? Double,let end=row["end"] as? Double, start.isFinite, end.isFinite, score.isFinite, score>=0, score<=1, start>=0, end>start, end<=request.duration {
                candidates[i,default:[]].append((start,end,score,row["context"] as? String ?? "unknown"))
            }
        }
        var lastStart = -1.0
        for i in aligned.indices {
            let values=(candidates[i] ?? []).sorted { $0.0 < $1.0 }
            guard !values.isEmpty else { continue }
            guard evidence[i].confidence>=0.3,let supportedStart=evidence[i].start,let supportedEnd=evidence[i].end else { continue }
            let clusters=values.map { center in values.filter { abs($0.0-center.0)<=0.65 } }
            let cluster=clusters.max {
                let a=Set($0.map(\.3)).count,b=Set($1.map(\.3)).count
                if a != b { return a<b }
                return abs($0[$0.count/2].0-supportedStart)>abs($1[$1.count/2].0-supportedStart)
            } ?? []
            guard Set(cluster.map(\.3)).count>=2 else { continue }
            let middle=cluster[cluster.count/2]
            // Token probabilities vary by script/tokenization. A low-probability
            // candidate needs much stronger independent acoustic corroboration.
            let acousticSupport=middle.2>=0.05 || (middle.2>=0.005 && evidence[i].confidence>=0.8 && abs(middle.0-supportedStart)<=0.75)
            if acousticSupport && middle.0>lastStart && middle.0>=supportedStart-2 && middle.0<=supportedEnd+2 {
                aligned[i]=Aligned(text:request.lines[i],start:middle.0,end:middle.1,confidence:middle.2)
                lastStart=middle.0
            }
        }
    }
    try JSONEncoder().encode(aligned).write(to:output,options:.atomic)
    let matched=aligned.filter { $0.start != nil }.count
    diagnostics["matched"]=matched;diagnostics["lines"]=aligned.count
    try JSONSerialization.data(withJSONObject:diagnostics,options:[.prettyPrinted,.sortedKeys]).write(to:output.deletingPathExtension().appendingPathExtension("diagnostics.json"),options:.atomic)
    print("LyricsLite: \(matched)/\(aligned.count) lines, \(String(format:"%.2f",Date().timeIntervalSince(began))) seconds; artifacts: \(work.path)")
} catch {
    fputs("\(error.localizedDescription)\n",stderr)
    exit(1)
}
