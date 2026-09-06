import ButtonsCore
import Foundation
import Testing

@Suite("Button repository")
struct ButtonRepositoryTests {
    @Test("Repository saves and loads buttons")
    func savesAndLoadsButtons() async throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "buttons.json")
        let repository = FileButtonRepository(fileURL: url)
        let button = ButtonSeed.defaults[0]

        try await repository.save([button])
        let loaded = try await repository.load()

        #expect(loaded.count == 1)
        #expect(loaded.first?.id == button.id)
        #expect(loaded.first?.title == button.title)
        #expect(loaded.first?.workflow == button.workflow)
    }

    @Test("Missing repository file returns seed buttons")
    func missingFileReturnsSeedButtons() async throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "buttons.json")
        let repository = FileButtonRepository(fileURL: url)

        let loaded = try await repository.load()

        #expect(loaded == ButtonSeed.defaults)
        #expect(loaded.count == 1)
    }

    @Test("Seed requires a user-supplied repository instead of promoting a development repo")
    func seedRequiresUserSuppliedRepository() {
        let button = ButtonSeed.defaults[0]

        #expect(ButtonSeed.defaults.count == 1)
        #expect(button.title == "Star Repo")
        #expect(button.slug == "star-repo")
        #expect(button.face.color == .lemon)
        #expect(button.approvalPolicy == .never)
        #expect(button.requiresRunConfirmation == false)
        #expect(button.workflow.steps.first?.kind == .askAI)
        #expect(button.workflow.steps.first?.aiConfiguration?.provider == .codex)
        #expect(button.workflow.steps.first?.aiConfiguration?.executionMode == .dangerouslyRun)
        #expect(button.workflow.steps.first?.aiConfiguration?.thinkingLevel == .low)
        let prompt = button.workflow.steps.first?.value ?? ""
        #expect(prompt.contains("Edit this prompt to name the repository you want to star"))
        #expect(prompt.contains("BUTTONS_RUN_FAILED:"))
        #expect(prompt.contains("Do not choose a repository or infer one"))
        #expect(!prompt.contains("https://"))
        #expect(!prompt.contains("companion-inc"))
        #expect(!prompt.contains("advaitpaliwal"))
        #expect(button.workflow.steps.first?.value.contains("gh api") == false)
        #expect(button.workflow.steps.first?.value.contains("gh repo view") == false)
    }

    @Test("Library collapses duplicate starter buttons")
    func libraryCollapsesDuplicateStarterButtons() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let buttonURL = rootURL.appending(path: "buttons.json")
        let runsURL = rootURL.appending(path: "runs.json")
        let repository = FileButtonRepository(fileURL: buttonURL)
        let receiptRepository = ButtonRunReceiptRepository(fileURL: runsURL)
        let customButton = ActionButton(
            title: "Custom",
            subtitle: "Saved prompt",
            category: "Personal",
            taskDescription: "Do a custom task.",
            face: ButtonFace(symbolName: "bolt.fill", color: .poppy, surface: .raised),
            workflow: ButtonWorkflow(
                steps: [
                    WorkflowStep(
                        title: "Workflow",
                        kind: .askAI,
                        value: "Do the custom task.",
                        aiConfiguration: AIConfiguration()
                    ),
                ]
            )
        )

        try await repository.save([
            ButtonSeed.starRepo,
            customButton,
            ButtonSeed.starRepo,
        ])

        let library = await ButtonLibrary(
            repository: repository,
            receiptRepository: receiptRepository
        )
        await library.load()

        let starButtons = await library.buttons.filter { $0.id == ButtonSeed.starRepo.id || $0.title == ButtonSeed.starRepo.title }
        let loadedCustomButton = await library.buttons.first { $0.id == customButton.id }

        #expect(starButtons.count == 1)
        #expect(loadedCustomButton?.title == "Custom")
    }

    @Test("Library preserves the user-supplied starter prompt across reloads")
    func libraryPreservesUserSuppliedStarterPrompt() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let repository = FileButtonRepository(fileURL: rootURL.appending(path: "buttons.json"))
        let receiptRepository = ButtonRunReceiptRepository(fileURL: rootURL.appending(path: "runs.json"))
        var edited = ButtonSeed.starRepo
        edited.workflow.steps[0].value = "Star example/project and open it."
        try await repository.save([edited])

        let library = await ButtonLibrary(repository: repository, receiptRepository: receiptRepository)
        await library.load()
        await library.load()

        let loaded = await library.buttons
        #expect(loaded.filter { $0.id == edited.id }.count == 1)
        #expect(loaded.first { $0.id == edited.id }?.workflow.steps.first?.value == "Star example/project and open it.")
        let persisted = try await repository.load()
        #expect(persisted.first { $0.id == edited.id }?.workflow.steps.first?.value == "Star example/project and open it.")
    }

    @Test("Production button workspace lives in the home dot-buttons directory")
    func productionWorkspaceLivesInHomeDotButtons() {
        let workspace = ButtonAutomationWorkspace.production()
        let expectedRoot = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".buttons", directoryHint: .isDirectory)
            .appending(path: "buttons", directoryHint: .isDirectory)

        #expect(workspace.rootURL.path == expectedRoot.path)
    }

    @Test("A user button sharing the starter title is not discarded")
    func sameTitleDoesNotDiscardUserButton() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let repository = FileButtonRepository(fileURL: rootURL.appending(path: "buttons.json"))
        let receiptRepository = ButtonRunReceiptRepository(fileURL: rootURL.appending(path: "runs.json"))
        let imported = try ButtonTemplateCodec.decode(ButtonTemplateCodec.encode(ButtonSeed.starRepo))
        var edited = imported
        edited.workflow.steps[0].value = "Star example/another-project."
        try await repository.save([edited])

        let library = await ButtonLibrary(repository: repository, receiptRepository: receiptRepository)
        await library.load()

        let loaded = await library.buttons
        #expect(loaded.first { $0.id == edited.id }?.workflow.steps.first?.value == "Star example/another-project.")
        #expect(loaded.contains { $0.id == ButtonSeed.starRepo.id })
    }
}
