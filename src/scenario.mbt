/// Scenario comparison turns policy choices into an auditable trade-off table.
/// It does not silently choose a policy: callers receive all candidate scores.

pub struct ScenarioDefinition {
  id : String
  label : String
  policy : PolicyProfile
  simulation_days : Int
} derive(Show)

pub struct ScenarioScore {
  scenario_id : String
  allocated_grams : Int
  unmet_minimum_count : Int
  expired_grams : Int
  audit_findings : Int
  utility : Int
} derive(Show)

pub struct ScenarioComparison {
  scores : Array[ScenarioScore]
  recommended_id : String?
  explanation : String
} derive(Show)

pub fn scenario_conservative() -> ScenarioDefinition {
  let policy = { ..PolicyProfile::default(), id: "conservative", version: "1", critical_days: 3, soon_days: 7, unmet_minimum_penalty: 2000 }
  { id: "conservative", label: "protect minimum coverage", policy, simulation_days: 7 }
}

pub fn scenario_balanced() -> ScenarioDefinition {
  { id: "balanced", label: "balance coverage and loss", policy: PolicyProfile::default(), simulation_days: 7 }
}

pub fn scenario_loss_first() -> ScenarioDefinition {
  let policy = { ..PolicyProfile::default(), id: "loss-first", version: "1", critical_days: 4, soon_days: 10, waste_penalty_per_gram: 15, unmet_minimum_penalty: 800 }
  { id: "loss-first", label: "prioritize expiring stock", policy, simulation_days: 7 }
}

pub fn default_scenarios() -> Array[ScenarioDefinition] {
  [scenario_conservative(), scenario_balanced(), scenario_loss_first()]
}

fn scenario_unmet_minimum(plan : AllocationPlan) -> Int {
  plan.metrics.demand_minimum_total - plan.metrics.demand_minimum_met
}

fn scenario_utility(plan : AllocationPlan, simulation : ScenarioSummary, audit : AuditReport, policy : PolicyProfile) -> Int {
  plan.metrics.total_allocated.grams - simulation.expired.grams * policy.waste_penalty_per_gram - scenario_unmet_minimum(plan) * policy.unmet_minimum_penalty - audit.findings.length() * 100000
}

pub fn score_scenario(definition : ScenarioDefinition, lots : Array[FoodLot], sites : Array[DistributionSite], demands : Array[DemandLine], on : Day) -> ScenarioScore {
  let plan = plan_allocations(lots, sites, demands, on, definition.policy)
  let config = { ..SimulationConfig::default(on), horizon_days: definition.simulation_days }
  let simulation = simulate(lots, demands, plan.allocations, config)
  let audit = audit_plan(plan, lots, sites, demands)
  {
    scenario_id: definition.id,
    allocated_grams: plan.metrics.total_allocated.grams,
    unmet_minimum_count: scenario_unmet_minimum(plan),
    expired_grams: simulation.expired.grams,
    audit_findings: audit.findings.length(),
    utility: scenario_utility(plan, simulation, audit, definition.policy),
  }
}

fn scenario_better(left : ScenarioScore, right : ScenarioScore) -> Bool {
  if left.audit_findings != right.audit_findings { return left.audit_findings < right.audit_findings }
  if left.unmet_minimum_count != right.unmet_minimum_count { return left.unmet_minimum_count < right.unmet_minimum_count }
  if left.utility != right.utility { return left.utility > right.utility }
  left.scenario_id < right.scenario_id
}

pub fn compare_scenarios(definitions : Array[ScenarioDefinition], lots : Array[FoodLot], sites : Array[DistributionSite], demands : Array[DemandLine], on : Day) -> ScenarioComparison {
  let scores = []
  let mut index = 0
  while index < definitions.length() {
    scores.push(score_scenario(definitions[index], lots, sites, demands, on))
    index = index + 1
  }
  if scores.length() == 0 { return { scores, recommended_id: None, explanation: "No policy scenarios were supplied." } }
  let mut best = scores[0]
  index = 1
  while index < scores.length() {
    if scenario_better(scores[index], best) { best = scores[index] }
    index = index + 1
  }
  { scores, recommended_id: Some(best.scenario_id), explanation: "Recommendation minimizes audit findings, then unmet minimums, then maximizes documented utility." }
}

pub fn scenario_find_score(comparison : ScenarioComparison, id : String) -> ScenarioScore? {
  let mut index = 0
  while index < comparison.scores.length() {
    if comparison.scores[index].scenario_id == id { return Some(comparison.scores[index]) }
    index = index + 1
  }
  None
}

pub fn scenario_summary(comparison : ScenarioComparison) -> Array[String] {
  let lines = []
  let mut index = 0
  while index < comparison.scores.length() {
    let score = comparison.scores[index]
    lines.push(score.scenario_id + ": allocated=" + score.allocated_grams.to_string() + "g, expired=" + score.expired_grams.to_string() + "g, unmet-minimums=" + score.unmet_minimum_count.to_string() + ", audit-findings=" + score.audit_findings.to_string())
    index = index + 1
  }
  lines
}
