import ButtonsCore
import Foundation
import Testing

@Suite("Button templates")
struct ButtonTemplateTests {
    @Test("Template export and import keeps recipe while minting a new id")
    func exportImportKeepsRecipeWithNewID() throws {
        let button = ButtonSeed.starRepo

        let data = try ButtonTemplateCodec.encode(button)
        let decoded = try ButtonTemplateCodec.decode(data)

        #expect(decoded.id != button.id)
        #expect(decoded.title == button.title)
        #expect(decoded.workflow.steps == button.workflow.steps)
    }

    @Test("Legacy workflow inputs fold into the saved prompt")
    func legacyWorkflowInputsFoldIntoSavedPrompt() throws {
        let data = """
        {
          "inputs": [
            { "key": "repo", "label": "Repo", "defaultValue": "example/project" }
          ],
          "steps": [
            {
              "id": "9D4C6A7B-8A31-4C7A-A15B-AC4C70C31289",
              "title": "Workflow",
              "kind": "askAI",
              "value": "Star {{repo}}"
            }
          ]
        }
        """.data(using: .utf8)!

        let workflow = try JSONDecoder().decode(ButtonWorkflow.self, from: data)

        #expect(workflow.steps.first?.value == "Star example/project")
    }
}
