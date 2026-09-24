///|
/// Portable text reports.  The format is deliberately dependency-free so a
/// plan can be reviewed in a terminal, attached to a ticket, or archived.
pub fn grams_text(quantity : Quantity) -> String {
  let kilograms = quantity.grams / 1000
  let remainder = quantity.grams % 1000
  kilograms.to_string() + "." + remainder.to_string() + " kg"
}

///|
pub fn line(label : String, value : String) -> String {
  "- " + label + ": " + value + "\n"
}

///|
pub fn title(text : String) -> String {
  "# " + text + "\n\n"
}

///|
pub fn heading(text : String) -> String {
  "## " + text + "\n\n"
}

///|
pub fn render_metrics(metrics : PlanMetrics) -> String {
  let text = heading("Plan metrics")
  text +
  line("Received", grams_text(metrics.total_received)) +
  line("Allocated", grams_text(metrics.total_allocated)) +
  line("Unallocated", grams_text(metrics.total_unallocated)) +
  line("Requested", grams_text(metrics.demand_requested)) +
  line(
    "Minimum coverage",
    metrics.demand_minimum_met.to_string() +
    "/" +
    metrics.demand_minimum_total.to_string(),
  ) +
  line(
    "Critical lots allocated",
    metrics.critical_lots_allocated.to_string() +
    "/" +
    metrics.critical_lots_total.to_string(),
  ) +
  "\n"
}

///|
pub fn render_allocation(allocation : Allocation) -> String {
  "| " +
  allocation.id +
  " | " +
  allocation.lot_id +
  " | " +
  allocation.site_id +
  " | " +
  allocation.demand_id +
  " | " +
  grams_text(allocation.quantity) +
  " | " +
  reason_name(allocation.reason) +
  " | " +
  allocation.score.to_string() +
  " |\n"
}

///|
pub fn render_allocations(allocations : Array[Allocation]) -> String {
  let mut text = heading("Allocations")
  text = text + "| Id | Lot | Site | Demand | Quantity | Reason | Score |\n"
  text = text + "| --- | --- | --- | --- | ---: | --- | ---: |\n"
  let mut index = 0
  while index < allocations.length() {
    text = text + render_allocation(allocations[index])
    index = index + 1
  }
  if allocations.length() == 0 {
    text = text +
      "| — | — | — | — | 0 kg | no feasible allocation | — |\n"
  }
  text + "\n"
}

///|
pub fn render_issue(issue : ValidationIssue) -> String {
  "- `" + issue.subject + "` — " + issue.message + "\n"
}

///|
pub fn render_issues(issues : Array[ValidationIssue]) -> String {
  let mut text = heading("Input issues")
  if issues.length() == 0 {
    return text + "No validation issues.\n\n"
  }
  let mut index = 0
  while index < issues.length() {
    text = text + render_issue(issues[index])
    index = index + 1
  }
  text + "\n"
}

///|
pub fn render_alert(alert : PlanAlert) -> String {
  "- **" +
  alert_level_name(alert.level) +
  "** `" +
  alert.subject +
  "` — " +
  alert.message +
  " (" +
  grams_text(alert.quantity) +
  ")\n"
}

///|
pub fn render_alerts(alerts : Array[PlanAlert]) -> String {
  let mut text = heading("Operational alerts")
  if alerts.length() == 0 {
    return text + "No operational alerts.\n\n"
  }
  let mut index = 0
  while index < alerts.length() {
    text = text + render_alert(alerts[index])
    index = index + 1
  }
  text + "\n"
}

///|
pub fn render_coverage(coverage : DemandCoverage) -> String {
  "| " +
  coverage.demand_id +
  " | " +
  coverage.site_id +
  " | " +
  grams_text(coverage.requested) +
  " | " +
  grams_text(coverage.allocated) +
  " | " +
  coverage.coverage_basis_points.to_string() +
  " bp |\n"
}

///|
pub fn render_coverages(coverages : Array[DemandCoverage]) -> String {
  let mut text = heading("Demand coverage")
  text = text + "| Demand | Site | Requested | Allocated | Coverage |\n"
  text = text + "| --- | --- | ---: | ---: | ---: |\n"
  let mut index = 0
  while index < coverages.length() {
    text = text + render_coverage(coverages[index])
    index = index + 1
  }
  text + "\n"
}

///|
pub fn render_disposition(disposition : LotDisposition) -> String {
  "| " +
  disposition.lot_id +
  " | " +
  category_name(disposition.category) +
  " | day " +
  disposition.expires_on.value.to_string() +
  " | " +
  grams_text(disposition.allocated) +
  " | " +
  grams_text(disposition.remaining) +
  " | " +
  urgency_name(disposition.urgency) +
  " |\n"
}

///|
pub fn render_dispositions(dispositions : Array[LotDisposition]) -> String {
  let mut text = heading("Lot disposition")
  text = text +
    "| Lot | Category | Expires | Allocated | Remaining | Urgency |\n"
  text = text + "| --- | --- | --- | ---: | ---: | --- |\n"
  let mut index = 0
  while index < dispositions.length() {
    text = text + render_disposition(dispositions[index])
    index = index + 1
  }
  text + "\n"
}

///|
pub fn render_simulation_day(outcome : DayOutcome) -> String {
  "| " +
  outcome.day.value.to_string() +
  " | " +
  grams_text(outcome.delivered) +
  " | " +
  grams_text(outcome.expired) +
  " | " +
  grams_text(outcome.spoiled) +
  " | " +
  grams_text(outcome.unmet) +
  " | " +
  grams_text(outcome.remaining) +
  " |\n"
}

///|
pub fn render_simulation(summary : ScenarioSummary) -> String {
  let mut text = heading("Loss simulation")
  text = text + "| Day | Delivered | Expired | Spoiled | Unmet | Remaining |\n"
  text = text + "| ---: | ---: | ---: | ---: | ---: | ---: |\n"
  let mut index = 0
  while index < summary.outcomes.length() {
    text = text + render_simulation_day(summary.outcomes[index])
    index = index + 1
  }
  text = text + "\n"
  text = text + line("Simulated delivery", grams_text(summary.delivered))
  text = text + line("Simulated expiry", grams_text(summary.expired))
  text = text + line("Simulated spoilage", grams_text(summary.spoiled))
  text = text + line("Simulated unmet", grams_text(summary.unmet))
  text + line("Final inventory", grams_text(summary.final_inventory))
}

///|
pub fn markdown_report(
  lots : Array[FoodLot],
  sites : Array[DistributionSite],
  demands : Array[DemandLine],
  plan : AllocationPlan,
  simulation : ScenarioSummary,
) -> String {
  let coverages = coverages_for_demands(demands, plan.allocations)
  let dispositions = dispositions_for_lots(
    lots,
    plan.allocations,
    plan.created_on,
    demands,
    plan.policy,
  )
  title("PantryFlow allocation plan") +
  line("Planning day", plan.created_on.value.to_string()) +
  line("Policy", plan.policy.id + " v" + plan.policy.version) +
  "\n" +
  render_metrics(plan.metrics) +
  render_allocations(plan.allocations) +
  render_coverages(coverages) +
  render_dispositions(dispositions) +
  render_issues(plan.issues) +
  render_alerts(analyze_plan(lots, sites, demands, plan)) +
  render_simulation(simulation)
}
