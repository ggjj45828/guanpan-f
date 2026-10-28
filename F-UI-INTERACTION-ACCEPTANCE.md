# F UI, Quote Time, Chart and Dividend Acceptance

This specification records user-observed B usability problems and the F response. B Frozen remains read-only. Source presence is evidence of code, never proof of discoverability or actual usability.

## User-observed B feedback and F arbitration

| Area | A source observation | B source observation / field report | F verdict and acceptance |
|---|---|---|---|
| Index timestamp | A index detail/sample paths retain timestamps, but no F-level quote provenance contract. | `GlobalIndices.swift` returns `时间未知` when `observedAt` is absent; `MarketDataSources.swift` documents a source that sets request time as `time`. User observed the home index card persisting in this state. | **F Refactor**. Keep verified quote timestamp separate from fetchedAt; show verified market time, closed-session last quote time, explicit fetch-only fallback or unverified state. Include source, freshness and market-session status. Never relabel fetchedAt as market time. |
| AI holding Q&A | A has online AI entry, but this task does not treat it as a prominent portfolio composer. | `AIGuidanceViews.swift` does contain a TextField and send button; user did not find an obvious place to ask in actual use. This is a discoverability defect despite source implementation. | **F Refactor**. Make the portfolio question composer a primary visible home/Advisor action, with five shortcuts, an obvious send action, current scope, and a visible real-holdings context status. Detail entry carries that instrument; home entry defaults to the real portfolio. Capture DecisionContext before submission. |
| Text/background color controls | A design tokens support semantic colors and typography; no need to offer free-form design controls. | `GuanpanAdvisorApp.swift` settings expose ColorPicker for text, card and page background on top of themes. User finds this over-configurable. | **F Refactor**. Theme selection owns ordinary text, card and page colors. No free-form color palette. Keep semantic chart and state colors only: move, cost, average, previous close, IOPV, buy/sell and risk. |
| Direct daily-candle tap | A unified chart source is a possible interaction reference; acceptance still needs exact hit-testing. | User reports drag works but tapping an individual daily candle does not select it. `UnifiedChartView.swift` has drag handling; no direct candle tap was established in this review. | **F Refactor**. One chart-selection model supports direct tap, long-press crosshair, horizontal drag, stable release, zoom and landscape. Selection shows the bar's date/OHLC/change/volume/MA and only historically valid evidence; overlays remain intact. |
| Dividend threshold | A/B-derived dividend heuristics are not inherited as a hard eligibility gate. | `GPDividendScore.swift`, `LocalRules.swift` and settings provide a configurable target-yield threshold; settings text says default 4% and the score uses the target for yield points. The observed design risks turning a reference into a user-maintained hard rule. | **F Refactor**. Default to automatic/AI evidence assessment. 4% is a research reference only. Optional custom minimum exists only under an explicit advanced setting. Dividend conclusions combine verified yield, historical percentile, continuity/stability/trend, payout, earnings/FCF reliability, index features, valuation, rate environment, peers and the user's income preference; no 3.9/4.1 cliff. |

| Home semantic entries and route identity | A does not set the F route contract. | User reports that differently named home entries such as “今日市场观察”, “跨市场脉搏” and “AI今日指导” can all end at the same AI guidance page, so the claimed tasks are not distinct. | **F Refactor**. Keep three distinct typed destinations and page tasks: domestic market facts; timezone-aware cross-market context/research; portfolio-specific AI judgment. AI may cite the first two as evidence but cannot replace their pages. Click-through acceptance checks title, content, source/time semantics and primary action for each. |

## Visible guidance and interaction rules

- Each screen exposes one primary action. Advisor input is visible without hunting through a secondary route; a screenshot review checks whether a first-time user can identify it.
- “今日市场观察”, “跨市场脉搏” and “AI今日指导” have independent information duties and distinct destinations. They may link with explicit context but must not route to one generic guidance page.
- The composer identifies `我的真实组合` or the current instrument, and shows whether the real ledger snapshot, latest quote, news and NAS Research Evidence are available/current/partial/missing. It creates DecisionContext from existing ledger data automatically.
- Quote time displays use distinct labels: verified exchange time, `获取于 HH:mm:ss · 行情时间未验证`, or `时间未验证/来源未提供时间`. Closed markets retain the most recent verified quote date/time and say `已收盘`; time quality also changes the visible data-quality state.
- Historical minute access is visible on the chart through today/previous session/calendar controls. The selected date and availability state remain visible. Only time-valid historical overlays appear.
- Chart help affordance explains tap-select, long-press crosshair, drag and zoom. Tap selection must be deterministic after zoom/rotation. Ambiguous gaps do not silently select a bar.
- AI answers show the exact context snapshot time, instruments, evidence sources/freshness, guard findings and unavailable inputs. The text separates observed data from interpretation and candidate plan.
- Five themes determine ordinary text and surface colors. Settings do not expose arbitrary text/card/page ColorPickers. Business-signal colors retain their semantic meaning and accessible contrast.
- Dividend defaults to automatic/AI assessment. Advanced custom minimum is optional, clearly labeled as a preference, and cannot suppress the multi-factor evidence explanation.

## F test and verification ladder

1. Pure model/hit-test XCTest: verified quote time, retrieval-time fallback, unverified/missing state, freshness, close-session rendering; candle first/last, ambiguous midpoint, zoom-transformed centers, screen-width layouts, invalid geometry and large series; automatic-vs-custom dividend behavior; DecisionContext-carrying question request.
2. Static visual review: first-open home action prominence, prompt composer, context status, quote-time semantics, historical date selection, theme-only color settings.
3. Simulator and iPhone review: actual tap/long-press/drag arbitration, release behavior, zoom and landscape coordinates across supported widths; VoiceOver labels and dynamic text.
4. Actual usability acceptance: ask a first-time reviewer to find AI input, historical date selection, candle selection, data timestamp/source, evidence and primary action without instruction. A visible view or accessibility identifier alone does not pass.

Current stage defines quote metadata, chart hit-testing geometry, advisor entry scope/request and dividend preference models. Swift acceptance tests are defined only. Native UI, actual rendering, actual discoverability, chart gesture arbitration and source/provider integration remain External Verification Pending.


## B 主布局基线与首页卡片责任

F 采用 B 的东方编辑室、现代卡片、交易仪表盘、杂志卡片和 Bento 五种首页布局作为主要布局基线。F 重建卡片职责、数据和导航，不把 B 源码视为视觉或可发现性验收通过。不同卡片若执行同一动作，必须合并或携带明确不同上下文；不得用不同标题制造多个入口。职责与路由细节见 `F-HOME-CARD-ROUTE-ACCEPTANCE.md`。

后续多主题目标、Theme/Layout Manifest字段、10套结构差异与截图验收标准见 `F-THEME-LAYOUT-MANIFEST-DESIGN.md`。这项设计不代表额外五套主题已编码，也不改变当前Ledger、Apple CI、NAS历史分钟进入iOS和DeepSeek闭环优先级。
