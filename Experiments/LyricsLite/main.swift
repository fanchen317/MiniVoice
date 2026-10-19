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
func normalize(_ text: String) -> [Character] {
    let transformed = text.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? text
    return Array(transformed.lowercased().filter { $0.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) } })
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
func readCharacters(_ url: URL) throws -> [TimedCharacter] {
    let json=try JSONSerialization.jsonObject(with:Data(contentsOf:url)) as! [String:Any]
    var characters=[TimedCharacter]()
    for segment in json["transcription"] as? [[String:Any]] ?? [] {
        for token in segment["tokens"] as? [[String:Any]] ?? [] {
            let text=token["text"] as? String ?? ""
            guard !text.hasPrefix("[_"), !text.hasPrefix("[<"), let times=token["offsets"] as? [String:Any],
                  let start=times["from"] as? Double, let end=times["to"] as? Double,
                  start>=0,end>start else { continue }
            for c in normalize(text) { characters.append(TimedCharacter(value:c,start:start/1000,end:end/1000)) }
        }
    }
    return characters
}
func match(lines: [String], characters: [TimedCharacter], duration: Double, seedsOnly: Bool = false) -> [Aligned] {
    let normalized = lines.map(normalize)
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
        try check(normalize("愛，Hello！")==normalize("爱 hello"),"Normalization failed")
        try check(match(lines:["你好"],characters:[],duration:20)[0].start==nil,"Empty ASR was accepted")
        print("5 LyricsLite matching regression checks passed")
        exit(0)
    }
    guard CommandLine.arguments.count == 3 else { throw NSError(domain:"LyricsLite",code:1,userInfo:[NSLocalizedDescriptionKey:"Usage: lyrics-lite request.json output.json"]) }
    let request = try JSONDecoder().decode(Request.self,from:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1])))
    let output = URL(fileURLWithPath:CommandLine.arguments[2])
    let work = output.deletingLastPathComponent().appendingPathComponent("lite-"+UUID().uuidString)
    try FileManager.default.createDirectory(at:work,withIntermediateDirectories:true)
    let wav=work.appendingPathComponent("audio.wav"), prefix=work.appendingPathComponent("transcript"), log=work.appendingPathComponent("inference.log")
    FileManager.default.createFile(atPath:log.path,contents:Data())
    let began=Date()
    try execute(request.ffmpegPath,["-nostdin","-v","error","-y","-i",request.audioPath,"-map","0:a:0","-vn","-ar","16000","-ac","1","-c:a","pcm_s16le",wav.path],log:log)
    var arguments=["-m",request.modelPath,"-f",wav.path,"-l",request.language,"-t","4","-ojf","-of",prefix.path,"-dtw","small","-np"]
    if request.useLyricsPrompt == true { arguments += ["--prompt",request.lines.joined(separator:" "),"--carry-initial-prompt"] }
    try execute(request.cliPath,arguments,log:log)
    let characters=try readCharacters(prefix.appendingPathExtension("json"))
    var aligned=match(lines:request.lines,characters:characters,duration:request.duration)
    if let forcePath=request.forceAlignerPath {
        let independent=work.appendingPathComponent("independent")
        try execute(request.cliPath,["-m",request.modelPath,"-f",wav.path,"-l",request.language,"-t","4","-ojf","-of",independent.path,"-dtw","small","-np"],log:log)
        let evidence=match(lines:request.lines,characters:try readCharacters(independent.appendingPathExtension("json")),duration:request.duration,seedsOnly:true)
        let raw=work.appendingPathComponent("audio.f32")
        try execute(request.ffmpegPath,["-nostdin","-v","error","-y","-i",wav.path,"-f","f32le",raw.path],log:log)
        let seeds=match(lines:request.lines,characters:characters,duration:request.duration,seedsOnly:true)
        var windows=[[String:Any]]()
        func addWindow(_ range: Range<Int>) {
            let starts=range.compactMap { seeds[$0].start }, ends=range.compactMap { seeds[$0].end }
            guard let earliest=starts.min(), let latest=ends.max() else { return }
            let left=max(0,earliest-4), right=min(request.duration,latest+4)
            if right-left>29.5 && range.count>1 {
                for i in range { addWindow(i..<(i+1)) }
            } else if right>left && right-left<=29.5 {
                windows.append(["start":left,"end":right,"firstIndex":range.lowerBound,"lines":range.map { request.lines[$0] }])
            }
        }
        // Re-align overlapping contexts: a line at a crop boundary must agree
        // with the same line inside neighbouring acoustic windows.
        for first in 0..<request.lines.count { addWindow(first..<min(first+3,request.lines.count)) }
        if request.lines.count>=3 { addWindow(0..<1); addWindow(0..<2) }
        let forcedRequest=work.appendingPathComponent("forced-request.json"), forcedOutput=work.appendingPathComponent("forced-output.json")
        try JSONSerialization.data(withJSONObject:["pcmPath":raw.path,"modelPath":request.modelPath,"language":request.language,"windows":windows],options:.prettyPrinted).write(to:forcedRequest)
        try execute(forcePath,[forcedRequest.path,forcedOutput.path],log:log)
        let rows=try JSONSerialization.jsonObject(with:Data(contentsOf:forcedOutput)) as! [[String:Any]]
        aligned=request.lines.map { Aligned(text:$0,start:nil,end:nil,confidence:0) }
        var candidates=[Int:[(Double,Double,Double)]]()
        for row in rows {
            guard let i=row["index"] as? Int, aligned.indices.contains(i) else { continue }
            let score=row["confidence"] as? Double ?? 0
            if let start=row["start"] as? Double,let end=row["end"] as? Double, start>=0, end>start, end<=request.duration {
                candidates[i,default:[]].append((start,end,score))
            }
        }
        var lastStart = -1.0
        for i in aligned.indices {
            let values=(candidates[i] ?? []).sorted { $0.0 < $1.0 }
            guard !values.isEmpty else { continue }
            let clusters=values.map { center in values.filter { abs($0.0-center.0)<=0.65 } }
            let cluster=clusters.max { $0.count < $1.count } ?? []
            guard cluster.count>=2, evidence[i].confidence>=0.3,
                  let supportedStart=evidence[i].start, let supportedEnd=evidence[i].end else { continue }
            let middle=cluster[cluster.count/2]
            if middle.0>lastStart && middle.0>=supportedStart-6 && middle.0<=supportedEnd+2 {
                aligned[i]=Aligned(text:request.lines[i],start:middle.0,end:middle.1,confidence:middle.2)
                lastStart=middle.0
            }
        }
    }
    try JSONEncoder().encode(aligned).write(to:output,options:.atomic)
    let matched=aligned.filter { $0.start != nil }.count
    print("LyricsLite: \(matched)/\(aligned.count) lines, \(String(format:"%.2f",Date().timeIntervalSince(began))) seconds; artifacts: \(work.path)")
} catch {
    fputs("\(error.localizedDescription)\n",stderr)
    exit(1)
}
