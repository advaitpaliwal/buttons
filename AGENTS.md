# AGENTS.md — Buttons

Native macOS app for one-click AI workflow buttons. See `README.md` for the runtime layout.

## Product model — a button IS a prompt

- Every button is one user-authored prompt that a local agent (Codex or Claude Code) runs. There is no other kind of button. Do not add hardcoded action types ("Open URL", "Copy text", "Star repo") or special-cased built-in actions — those are prompts the user writes, not product features. When you find old action-typed buttons or decoders, migrate them into prompts and delete the action machinery; keep no parallel hardcoded-action path as the user-facing product.
- Treat each button as a tactile prompt object. Press/run, open/edit, and configure are distinct affordances; a single click target must never both open the object and start a run.
- The board stays quiet: clicking the button object opens its button room/editor. Running is only triggered by an explicit visible play/run affordance, and a running button's play/run affordance focuses its live run instead of launching a duplicate.
- Create starts with the prompt. Infer or tuck runner/model/permission behind progressive disclosure; do not make the primary flow a Settings form or expose agent machinery as the product.
- Saved files or executables may exist only as internal automation/memory that the agent can improve; do not present the product as a manual script generator or make the user manage scripts.
- Never hardcode a repo URL, workspace path, account name, or default input value into a button, its run UI, or its sample/default board. The current dev repo is your session context, not a product default — baking it in as a placeholder or default has been corrected more than once. Anything that varies per run lives in the user's prompt text, not in a separate field the app injects.
- Keep run configuration to what `README.md` already names: runner (Codex/Claude Code), model override, thinking level, permission mode, button face, category. Do not invent new required input fields beyond the prompt. The prompt is the content; everything else is a setting on how to run it.

When the user says "nothing hardcoded," "every button is a prompt," or objects to the run/open/edit interaction, it is the product spec, not a style note — reread this file before adding non-prompt structure or shared click targets.

## Interaction research before UI edits

- Before changing the board, button tile, creation flow, run flow, or opened-button surface, write or update `docs/interaction-research.md` with the researched references, observed patterns, rejected alternatives, and the exact interaction contract to implement.
- Treat HeyClicky as the closest local runtime reference: it hides agent/computer-use complexity behind a compact user-facing surface. Treat Stream Deck as the closest physical/digital affordance reference: a board of pressable actions with configuration behind each key. Treat Apple Shortcuts, Automator, Keyboard Maestro, and Raycast as comparison points for what to expose or hide.
- The desired visual direction is tactile neo-skeuomorphic macOS: raised, dimensional, physical, colorful, and pressable, while keeping the information architecture sparse.
- The opened button is not "Settings." It is the inside of that button: prompt, face, category, execution details, live state, and history arranged by frequency of use.
- Do not use invisible hit targets over decorative controls. If an icon, face, run state, or edit affordance appears clickable, clicking it must directly do the thing it implies.
- A running button has one active run surface. Another press on the same button reveals the live state and Stop affordance; it must not silently launch a duplicate run.
