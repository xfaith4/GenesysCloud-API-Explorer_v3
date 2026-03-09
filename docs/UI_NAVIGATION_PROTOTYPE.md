## Workspace navigation prototype

Today the Explorer exposes every workflow (API request builder, favorite templates, insight packs, live/operational monitoring, queue reports, etc.) through a single tabbed area. That makes it easy to miss important panels and causes the tabs and content to “jump” vertically when sections expand. The prototype we added signals one possible way to break the experience into clearer workspaces:

1. **Workspace buttons** — three buttons (“API Explorer”, “Insights”, “Monitoring”) sit between the main action row and the tab area. They drive the `MainTabControl` selection so users can jump directly to the tab that contains the chosen workflow. The buttons are content-agnostic (they do not duplicate tooling) but help frame the mental model.
2. **Focused tab content** — each workspace reuses the existing tab items (Response/Transparency/Schema for API Explorer, Ops Insights/Quick Packs for Insights, Live Subscriptions/Operational Events/Audit Investigator for Monitoring). The prototype proves we can introduce a higher-level navigation layer without dismantling the current tabs.

Next:

- Curve the buttons into a more ribbon-like control that highlights the active workspace and optionally adds tooltips or short descriptions.
- Consider collapsing less-used sections (Quick Packs summary, metrics/drilldowns) inside the Ops Insights tab so the view remains focused even when packs expand.
- During validation we should ensure the Workspace buttons stay visible on smaller windows and that the tab selection still triggers analytics telemetry (already wired into the `MainTabControl` selection handler).
