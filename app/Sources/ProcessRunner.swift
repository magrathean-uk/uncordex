import Foundation
import Darwin

struct ProcessResult {
    let status: Int32
    let stdout: Data
    let stderr: Data

    var stdoutText: String { String(data: stdout, encoding: .utf8) ?? "" }
    var stderrText: String { String(data: stderr, encoding: .utf8) ?? "" }
}

protocol ProcessRunning {
    func run(executable: URL, arguments: [String], environment: [String: String]?, timeout: TimeInterval) throws -> ProcessResult
}

enum ProcessRunnerError: LocalizedError {
    case launch(String)
    case timedOut(String)

    var errorDescription: String? {
        switch self {
        case .launch(let message): return message
        case .timedOut(let command): return "Timed out while running or draining \(command)."
        }
    }
}

private final class PipeDrain {
    private let handle: FileHandle
    private let lock = NSLock()
    private let finished = DispatchSemaphore(value: 0)
    private var storage = Data()
    private var isFinished = false

    init(_ pipe: Pipe) { handle = pipe.fileHandleForReading }

    func start() {
        handle.readabilityHandler = { [weak self] readable in
            guard let self else { return }
            lock.lock()
            guard !isFinished else { lock.unlock(); return }
            let chunk = readable.availableData
            if chunk.isEmpty {
                isFinished = true
                lock.unlock()
                readable.readabilityHandler = nil
                finished.signal()
            } else {
                storage.append(chunk)
                lock.unlock()
            }
        }
    }

    func wait(until deadline: DispatchTime) -> Bool {
        finished.wait(timeout: deadline) == .success
    }

    func cancel() {
        handle.readabilityHandler = nil
        lock.lock()
        guard !isFinished else { lock.unlock(); return }
        isFinished = true
        lock.unlock()
        try? handle.close()
        finished.signal()
    }

    func data() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

final class SystemProcessRunner: ProcessRunning {
    private let wrapper = """
    set -m
    command_pid=0
    cleanup() {
      [ "$command_pid" -gt 0 ] || return 0
      if /bin/kill -TERM -- "-$command_pid" 2>/dev/null; then
        if /bin/kill -0 -- "-$command_pid" 2>/dev/null; then
          /bin/sleep 0.1
          /bin/kill -KILL -- "-$command_pid" 2>/dev/null || true
        fi
      fi
    }
    interrupted() {
      trap - EXIT HUP INT TERM
      cleanup
      exit 143
    }
    trap interrupted HUP INT TERM
    trap cleanup EXIT
    "$@" &
    command_pid=$!
    wait "$command_pid"
    command_status=$?
    trap - EXIT HUP INT TERM
    cleanup
    exit "$command_status"
    """

    func run(executable: URL, arguments: [String], environment: [String: String]?, timeout: TimeInterval) throws -> ProcessResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let outputDrain = PipeDrain(outputPipe)
        let errorDrain = PipeDrain(errorPipe)
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", wrapper, "uncordex-process", executable.path] + arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        if let environment { process.environment = environment }
        outputDrain.start()
        errorDrain.start()

        do { try process.run() }
        catch {
            outputDrain.cancel()
            errorDrain.cancel()
            throw ProcessRunnerError.launch("Could not run \(executable.path): \(error.localizedDescription)")
        }
        outputPipe.fileHandleForWriting.closeFile()
        errorPipe.fileHandleForWriting.closeFile()

        let deadline = DispatchTime.now() + timeout
        let processFinished = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            processFinished.signal()
        }

        guard processFinished.wait(timeout: deadline) == .success else {
            cancel(process, finished: processFinished)
            outputDrain.cancel()
            errorDrain.cancel()
            throw ProcessRunnerError.timedOut(executable.lastPathComponent)
        }
        guard outputDrain.wait(until: deadline), errorDrain.wait(until: deadline) else {
            outputDrain.cancel()
            errorDrain.cancel()
            throw ProcessRunnerError.timedOut(executable.lastPathComponent)
        }
        return ProcessResult(status: process.terminationStatus, stdout: outputDrain.data(), stderr: errorDrain.data())
    }

    private func cancel(_ process: Process, finished: DispatchSemaphore) {
        if process.isRunning { process.terminate() }
        if finished.wait(timeout: .now() + 0.25) == .timedOut, process.isRunning {
            kill(process.processIdentifier, SIGKILL)
            _ = finished.wait(timeout: .now() + 0.25)
        }
    }
}
