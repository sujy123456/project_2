///|
/// Compact operator-facing text summary shared by CLI and future adapters.
pub fn render_operator_summary(
  plan : AllocationPlan,
  audit : AuditReport,
  forecast : HorizonForecast,
  comparison : ScenarioComparison,
) -> String {
  let recommendation = match comparison.recommended_id {
    Some(id) => id
    None => "none"
  }
  "PantryFlow operator summary\n" +
  "allocated=" +
  plan.metrics.total_allocated.grams.to_string() +
  "g\n" +
  "unallocated=" +
  plan.metrics.total_unallocated.grams.to_string() +
  "g\n" +
  "audit-findings=" +
  audit.findings.length().to_string() +
  "\n" +
  "forecast-shortfall=" +
  forecast.total_shortfall_grams.to_string() +
  "g\n" +
  "recommended-policy=" +
  recommendation
}

///|
pub fn build_operator_summary(
  lots : Array[FoodLot],
  sites : Array[DistributionSite],
  demands : Array[DemandLine],
  on : Day,
) -> String {
  let plan = plan_allocations(
    lots,
    sites,
    demands,
    on,
    PolicyProfile::default(),
  )
  let audit = audit_plan(plan, lots, sites, demands)
  let forecast = forecast_horizon(lots, demands, on, 7)
  let comparison = compare_scenarios(
    default_scenarios(),
    lots,
    sites,
    demands,
    on,
  )
  render_operator_summary(plan, audit, forecast, comparison)
}
