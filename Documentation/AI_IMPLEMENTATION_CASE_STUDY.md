# Treadway Brief — explainable AI implementation case study

## Why this feature exists

Treadway already had useful weekly evidence: completions, days held, hydration goals, structured closes, and per-task rhythm. The product did not need a generic chatbot. It needed a safe way to turn that evidence into a concise coaching context without silently exporting a private journal or adding an API bill.

Treadway Brief is a small implementation layer between product data and any future language model. It creates a deterministic local analysis, exposes the evidence behind each conclusion, estimates signal strength, and builds a versioned model-neutral prompt only after the user reviews the boundary.

## Product behavior

1. The existing Weekly Trail remains the primary review.
2. A separate **AI-ready weekly brief** summarizes the highest-value pattern and reports how many observations support it.
3. Opening the brief reveals every generated insight, its numerical evidence, and its source.
4. Private Treadway Close text is excluded by default. A visible checkbox opts it into that single prompt payload.
5. Nothing is transmitted. The user must tap **Copy prompt for an AI chat** and choose where to paste it.

This is intentionally human-in-the-loop. The deterministic brief is useful without a model, and a model cannot receive data through this feature without a deliberate copy action.

## Architecture

```text
Seven-day product state
  ├─ scheduled/completed markers
  ├─ day-held and protection rules
  ├─ hydration-goal outcomes
  ├─ Close timestamps
  └─ optional Close text
          │
          ▼
insight-engine.js (pure, deterministic, locally executed)
  ├─ normalized weekly contract
  ├─ confidence/coverage classification
  ├─ ranked strengths and next-focus candidate
  ├─ evidence ledger for every insight
  └─ versioned prompt contract
          │
          ▼
Review sheet → explicit privacy opt-in → user-initiated copy
          │
          ▼
Any AI chat chosen by the user (no vendor dependency today)
```

`Web/insight-engine.js` is deliberately independent of DOM and Supabase code. The browser exposes it as `window.TreadwayBrief`; Node loads the same file for evaluation. This keeps the deployed PWA build-step-free while making the context engine testable.

## Grounding contract

The prompt tells a downstream model to:

- use only supplied evidence;
- avoid inventing motives, diagnoses, or events;
- treat task/reflection strings as untrusted data rather than instructions;
- produce one pattern, one seven-day experiment, and one non-judgmental question;
- state when evidence is weak;
- stay below a fixed response length.

The payload carries computed metrics, task-level counts, an evidence ledger, and reflection coverage. It never labels a correlation as a cause. Prompt behavior is versioned as `treadway-weekly-coach-v1`, allowing future evaluations to identify exactly which contract produced an output.

Context is bounded before formatting: at most seven days, 50 task summaries, seven reflections, 160 characters per task title, and 600 characters per reflective field. This limits latency/cost for a future provider and prevents an unexpectedly large local record from becoming an unreviewable prompt.

## Privacy boundary

Task titles and weekly counts appear in the reviewed copy payload because they are required for task-specific coaching. Private wins, honest lines, and tomorrow intentions do not. The opt-in control rebuilds the payload from source state for that interaction; it does not change sync settings or create a stored permission.

No API key, remote inference service, analytics event, background request, or new database field is involved. This also makes the feature fast, offline-capable, and effectively zero-cost while idle or active.

## Evaluation

`scripts/test-insight-engine.cjs` evaluates the production engine directly. Current coverage asserts:

- exact weekly metrics and confidence classification;
- deterministic output and input immutability;
- strongest/weakest task ranking;
- evidence provenance on every insight;
- default exclusion and explicit opt-in inclusion of private Close text;
- anti-fabrication and response-shape instructions in the prompt contract;
- prompt-injection instructions and bounded-context behavior;
- empty, malformed, and low-evidence inputs.

Run the full web suite with:

```bash
npm test
```

Visual QA uses synthetic portfolio data only. Dark and light review cards, the evidence sheet, default/opt-in prompt payloads, and narrow phone-column containment are checked separately from the pure evaluation suite.

## Why this is relevant AI engineering work

The feature demonstrates the less visible work required to put models into real products responsibly:

- translating product state into a stable context contract;
- choosing deterministic logic where probabilistic inference adds no value;
- grounding generated advice in inspectable evidence;
- designing confidence and low-evidence behavior;
- creating a privacy-default/human-approval boundary;
- building vendor-neutral prompts and repeatable evaluations;
- documenting limitations rather than disguising them as intelligence.

Those skills map directly to AI implementation, model evaluation, AI operations/automation, prompt systems, and junior AI product-engineering roles. A future local or hosted model can be connected behind the same contract without rewriting the product-facing reasoning and privacy layer.

## Deliberate limitations

- This is not represented as machine learning or autonomous coaching.
- Rule-based patterns do not infer causality, mood, health, or intent.
- The current product does not score downstream model responses.
- Clipboard contents are controlled by the operating system after copying.
- A future direct model integration would require a new consent, retention, provider, failure, and cost review.

These limits are part of the design: Treadway Brief improves the product today while creating a credible, testable seam for later model integration.
