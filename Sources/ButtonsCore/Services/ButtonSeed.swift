import Foundation

public enum ButtonSeed {
    public static let defaults: [ActionButton] = [
        starRepo,
    ]

    public static let starRepo = ActionButton(
        id: UUID(uuidString: "B077005C-57A8-4B3C-A8F5-011C5A9B0A11") ?? UUID(),
        slug: "star-repo",
        title: "Star Repo",
        subtitle: "GitHub",
        category: "Code",
        taskDescription: "Star a GitHub repository and open it.",
        face: ButtonFace(symbolName: "star.fill", color: .lemon, surface: .raised),
        workflow: ButtonWorkflow(
            steps: [
                WorkflowStep(
                    title: "Workflow",
                    kind: .askAI,
                    value: """
                    Star the GitHub repository explicitly named in this saved prompt and open it in the browser.

                    If this saved prompt does not specify a repository, report BUTTONS_RUN_FAILED: Edit this prompt to name the repository you want to star. Do not choose a repository or infer one from the current workspace, git remotes, or signed-in account.

                    Use the available local tools and CLI as needed. Do not use Computer Use for this button. Opening the repository alone is not completion; report failure when the star action is blocked.
                    """,
                    aiConfiguration: AIConfiguration(
                        provider: .codex,
                        model: "",
                        systemPrompt: "Be operational. Run the button now; do not stop at an explanation.",
                        executionMode: .dangerouslyRun,
                        thinkingLevel: .low
                    )
                ),
            ]
        ),
        approvalPolicy: .never,
        permissions: [
            ButtonPermission(title: "Local agent", detail: "Uses the installed GitHub CLI and opens the repository in the browser."),
        ]
    )
}
