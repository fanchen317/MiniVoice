import Foundation
import MiniVoiceShared
while let line = readLine() {
    do {print(try SharedEngine.executeJSON(line))}
    catch {fputs("Shared core failed: \(error)\n", stderr); exit(1)}
}
