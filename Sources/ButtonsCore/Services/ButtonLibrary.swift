import Foundation
import Observation

@MainActor
@Observable
public final class ButtonLibrary {
    public private(set) var buttons: [ActionButton] = []
    public private(set) var receipts: [ButtonRunReceipt] = []
    public private(set) var isLoaded = false
    public var lastError: String?

    private let repository: FileButtonRepository
    private let receiptRepository: ButtonRunReceiptRepository
    private let runner: WorkflowRunner
    private let metadataExtractor = ButtonMetadataExtractor()

    public init(
        repository: FileButtonRepository,
        receiptRepository: ButtonRunReceiptRepository = .production(),
        runner: WorkflowRunner = WorkflowRunner()
    ) {
        self.repository = repository
        self.receiptRepository = receiptRepository
        self.runner = runner
    }

    public static func production() -> ButtonLibrary {
        ButtonLibrary(
            repository: .production(),
            receiptRepository: .production(),
            runner: WorkflowRunner()
        )
    }

    public func load() async {
        do {
            let loadedButtons = try await repository.load()
            buttons = Self.withRequiredDefaults(loadedButtons.map(Self.migratedButton))
            receipts = try await receiptRepository.load()
            isLoaded = true
            if buttons != loadedButtons {
                await save()
            }
        } catch {
            buttons = ButtonSeed.defaults
            isLoaded = true
            lastError = error.localizedDescription
        }
    }

    public func add(_ button: ActionButton) async {
        var copy = Self.normalizedSlug(button)
        copy.slug = Self.uniqueSlug(copy.slug, excluding: copy.id, in: buttons)
        buttons.insert(copy.updated(), at: 0)
        await save()
    }

    public func update(_ button: ActionButton) async {
        guard let index = buttons.firstIndex(where: { $0.id == button.id }) else {
            return
        }
        var copy = Self.normalizedSlug(button)
        copy.slug = Self.uniqueSlug(copy.slug, excluding: copy.id, in: buttons)
        buttons[index] = copy.updated()
        await save()
    }

    public func delete(_ button: ActionButton) async {
        buttons.removeAll { $0.id == button.id }
        await save()
    }

    public func button(id: UUID) -> ActionButton? {
        buttons.first { $0.id == id }
    }

    public func importButton(from data: Data) async throws {
        let button = Self.normalizedSlug(Self.migratedButton(try ButtonTemplateCodec.decode(data)))
        await add(button)
    }

    @discardableResult
    public func run(
        _ button: ActionButton,
        prompt: String,
        configurationOverride: AIConfiguration? = nil,
        eventHandler: ButtonRunEventHandler? = nil
    ) async -> ButtonRunReceipt {
        let receipt = await runner.run(
            button: button,
            prompt: prompt,
            configurationOverride: configurationOverride,
            eventHandler: eventHandler
        )
        receipts.insert(receipt, at: 0)
        await saveReceipts()
        return receipt
    }

    public func receipts(for button: ActionButton) -> [ButtonRunReceipt] {
        receipts.filter { $0.buttonID == button.id }
    }

    /// Ask a small local model to label a prompt (name, category, goal, color,
    /// icon). Returns nil when the model is unavailable so callers can fall back.
    public func deriveMetadata(forPrompt prompt: String, provider: AIProvider) async -> ButtonMetadata? {
        await metadataExtractor.metadata(forPrompt: prompt, provider: provider)
    }

    private func save() async {
        do {
            try await repository.save(buttons)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func saveReceipts() async {
        do {
            try await receiptRepository.save(Array(receipts.prefix(500)))
        } catch {
            lastError = error.localizedDescription
        }
    }

    private static func migratedButton(_ button: ActionButton) -> ActionButton {
        var copy = button
        let originalSteps = copy.workflow.steps

        if copy.title == "New Button", copy.taskDescription == "Do the repetitive task.", copy.workflow.steps.first?.value == "Do this repetitive workflow end to end." {
            return ButtonSeed.starRepo
        }

        if copy.title == "Ask AI", copy.subtitle == "ChatGPT or Claude" {
            copy.title = "Run Agent"
            copy.subtitle = "Workspace task"
            copy.category = "Automation"
            copy.taskDescription = "Send a reusable task to the local Codex or Claude Code CLI."
            copy.face = ButtonFace(symbolName: "terminal.fill", color: .rose, surface: .raised)
        }

        if copy.title == "Run Agent", copy.subtitle == "Codex task" {
            copy.subtitle = "Workspace task"
            copy.category = "Automation"
        }

        if copy.subtitle == "Calendar setup" || copy.subtitle == "Triage prompt" || copy.subtitle == "GitHub" || copy.subtitle == "Prompt preset" {
            copy.subtitle = migratedSubtitle(for: copy)
        }

        copy.slug = ButtonWorkspaceSlug.make(from: copy.slug.isEmpty ? copy.title : copy.slug)

        if copy.category == "General" {
            copy.category = migratedCategory(for: copy)
        }

        copy.permissions = copy.permissions.map { permission in
            guard permission.title == "AI provider" else {
                return ButtonPermission(
                    id: permission.id,
                    title: "Local agent",
                    detail: "Runs the installed Codex or Claude Code CLI using its local login."
                )
            }

            return ButtonPermission(
                id: permission.id,
                title: "Local agent",
                detail: "Runs the installed Codex or Claude Code CLI using its local login."
            )
        }

        if copy.permissions.isEmpty {
            copy.permissions = [
                ButtonPermission(
                    title: "Local agent",
                    detail: "Runs the installed Codex or Claude Code CLI using its local login."
                ),
            ]
        }

        copy.workflow.steps = [
            WorkflowStep(
                title: "Workflow",
                kind: .askAI,
                value: promptValue(button: copy, originalSteps: originalSteps),
                aiConfiguration: migratedConfiguration(from: originalSteps.first?.aiConfiguration)
            ),
        ]

        return copy
    }

    private static func withRequiredDefaults(_ buttons: [ActionButton]) -> [ActionButton] {
        var copy = buttons.filter { button in
            !legacySeedTitles.contains(button.title)
        }

        // Keep the user's saved prompt (including its repository choice).
        // Only collapse duplicate instances of the stable starter identity.
        let starter = copy.first { $0.id == ButtonSeed.starRepo.id } ?? ButtonSeed.starRepo
        copy.removeAll { $0.id == ButtonSeed.starRepo.id }
        copy.insert(starter, at: 0)

        return uniquedSlugs(copy.map(normalizedSlug))
    }

    private static let legacySeedTitles: Set<String> = [
        "Plan Day",
        "Clean Inbox",
        "Open PR",
        "Run Agent",
    ]

    private static func migratedConfiguration(from configuration: AIConfiguration?) -> AIConfiguration {
        guard var configuration else {
            return AIConfiguration(
                provider: .codex,
                model: "",
                systemPrompt: "Be direct. Complete the button's workflow as an operational task.",
                executionMode: .workspaceWrite
            )
        }

        configuration.model = configuration.model.trimmingCharacters(in: .whitespacesAndNewlines)

        return configuration
    }

    private static func normalizedSlug(_ button: ActionButton) -> ActionButton {
        var copy = button
        copy.slug = ButtonWorkspaceSlug.make(from: copy.slug.isEmpty ? copy.title : copy.slug)
        return copy
    }

    private static func uniquedSlugs(_ buttons: [ActionButton]) -> [ActionButton] {
        var used = Set<String>()

        return buttons.map { button in
            var copy = normalizedSlug(button)
            var candidate = copy.slug
            var suffix = 2

            while used.contains(candidate) {
                candidate = "\(copy.slug)-\(suffix)"
                suffix += 1
            }

            copy.slug = candidate
            used.insert(candidate)
            return copy
        }
    }

    private static func uniqueSlug(_ slug: String, excluding id: UUID, in buttons: [ActionButton]) -> String {
        let base = ButtonWorkspaceSlug.make(from: slug)
        let used = Set(buttons.filter { $0.id != id }.map(\.slug))
        var candidate = base
        var suffix = 2

        while used.contains(candidate) {
            candidate = "\(base)-\(suffix)"
            suffix += 1
        }

        return candidate
    }

    private static func promptValue(button: ActionButton, originalSteps: [WorkflowStep]) -> String {
        if originalSteps.count == 1, let onlyStep = originalSteps.first, onlyStep.kind == .askAI {
            return onlyStep.value
        }

        let stepSummary = originalSteps
            .map(promptInstruction)
            .joined(separator: "\n")

        if stepSummary.isEmpty {
            return button.taskDescription
        }

        return """
        Complete this saved button as a workflow.

        Button: \(button.title)
        Goal: \(button.taskDescription)

        Prior recipe intent:
        \(stepSummary)
        """
    }

    private static func promptInstruction(_ step: WorkflowStep) -> String {
        switch step.kind {
        case .openURL:
            "- Open or use this URL: \(step.value)"
        case .copyText:
            "- Use this text: \(step.value)"
        case .runShortcut:
            "- Run or account for this Shortcut: \(step.value)"
        case .runShellCommand:
            "- Run or reason about this command: \(step.value)"
        case .showMessage:
            "- Produce this message or result: \(step.value)"
        case .askAI:
            "- \(step.value)"
        }
    }

    private static func migratedCategory(for button: ActionButton) -> String {
        switch button.title {
        case "Plan Day":
            "Planning"
        case "Clean Inbox":
            "Inbox"
        case "Open PR":
            "Code"
        case "Run Agent":
            "Automation"
        default:
            button.category
        }
    }

    private static func migratedSubtitle(for button: ActionButton) -> String {
        switch button.title {
        case "Plan Day":
            "Daily plan"
        case "Clean Inbox":
            "Triage"
        case "Open PR":
            "Review queue"
        default:
            button.subtitle
        }
    }
}
