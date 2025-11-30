import Anansi
import Configuration
import Foundation
import POSIXCore
import VirtualTerminal

@main
struct AnansiChat {
  static func main() async throws {
    let renderer = try await VTRenderer(mode: .raw)
    let terminal = renderer.terminal
    await terminal <<< .SetMode([.DEC(.UseAlternateScreenBufferSaveCursor)])

    defer {
      Task.immediate {
        await terminal <<< .ResetMode([.DEC(.UseAlternateScreenBufferSaveCursor)])
      }
    }

    let state = State()

    try await withThrowingTaskGroup(of: Void.self) { group in
      defer { group.cancelAll() }

      let signals = try await SignalHandler.install(SIGINT) { _ in
        // Disable SIGINT
      }

      group.addTask {
        for try await event in renderer.terminal.input {
          switch event {
          case .key(let key) where key.character == "q":
            return
          case .key(let key):
            await state.setState("\(key)")
          default:
            break
          }
        }
      }

      let displayLink = VTDisplayLink(fps: 60) { link in
        let messsage = await state.message
        renderer.back.write(string: messsage, at: VTPosition(row: 1, column: 1))
        await renderer.present()
        renderer.back.clear()
      }
      displayLink.add(to: &group)
      try await group.next()
      signals.remove()
    }
  }
}

actor State {
  var message: String = ""

  func setState(_ message: String) {
    self.message = message
  }

  func reset() {
    message = ""
  }
}
