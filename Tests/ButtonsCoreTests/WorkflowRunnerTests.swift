@testable import ButtonsCore
import Foundation
import Testing

@Suite("Workflow runner")
struct WorkflowRunnerTests {
    @Test("Show message button returns a receipt")
    @MainActor
    func showMessageButtonReturnsReceipt() async {
        let button = ActionButton(
            title: "Say It",
            subtitle: "Message",
            taskDescription: "Show a rendered message.",
            face: ButtonFace(),
            workflow: ButtonWorkflow(
                steps: [
                    WorkflowStep(title: "Message", kind: .showMessage, value: "Hello Buttons"),
                ]
            )
        )
        let runner = WorkflowRunner()

        let receipt = await runner.run(button: button, prompt: "Run the button.")

        #expect(receipt.status == .succeeded)
        #expect(receipt.output == "Hello Buttons")
    }

    @Test("Button workspace keeps context and logs")
    @MainActor
    func buttonWorkspaceKeepsContextAndLogs() async throws {
        let buttonID = UUID()
        let rootURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let workspace = ButtonAutomationWorkspace(rootURL: rootURL)
        let button = ActionButton(
            id: buttonID,
            slug: "cached-workflow",
            title: "Cached",
            subtitle: "Workflow",
            category: "Automation",
            taskDescription: "Run a saved workflow.",
            face: ButtonFace(),
            workflow: ButtonWorkflow(
                steps: [
                    WorkflowStep(
                        title: "Workflow",
                        kind: .askAI,
                        value: "Run the cached workflow.",
                        aiConfiguration: AIConfiguration()
                    ),
                ]
            )
        )

        _ = try workspace.ensureWorkspace(for: button)
        #expect(FileManager.default.fileExists(atPath: workspace.logsURL(for: button).path))
        #expect(!FileManager.default.fileExists(atPath: workspace.runnerURL(for: button).path))
        #expect(!FileManager.default.fileExists(atPath: workspace.computerUseToolsURL(for: button).path))
    }

    @Test("Agent failure marker becomes failed task output")
    func agentFailureMarkerBecomesFailedTaskOutput() {
        let completion = WorkflowRunner.interpretedAgentCompletion("""
        BUTTONS_RUN_FAILED: GitHub CLI could not reach api.github.com.
        Try again when network is available.
        """)

        #expect(completion.isFailed)
        #expect(completion.output == """
        GitHub CLI could not reach api.github.com.
        Try again when network is available.
        """)
    }

    @Test("Agent done marker is stripped from user output")
    func agentDoneMarkerIsStrippedFromUserOutput() {
        let completion = WorkflowRunner.interpretedAgentCompletion("""
        BUTTONS_RUN_DONE: Starred example/project.
        Opened the repository.
        """)

        #expect(!completion.isFailed)
        #expect(completion.output == """
        Starred example/project.
        Opened the repository.
        """)
    }
}
