fn audit_sample_allocation(quantity : Int, planned_day : Int) -> Allocation {
  { id: "audit-a", lot_id: "audit-lot", demand_id: "audit-demand", site_id: "audit-site", quantity: Quantity::from_grams(quantity), planned_for: Day::new(planned_day), reason: EarliestExpiry, score: 0 }
}

fn audit_sample_lot() -> FoodLot {
  { id: "audit-lot", category: Produce, storage: Ambient, received_on: Day::new(0), expires_on: Day::new(2), quantity: Quantity::from_grams(1000), state: Available, donor_reference: "test", notes: "" }
}

fn audit_sample_site() -> DistributionSite {
  { id: "audit-site", name: "Audit", priority: 1, ambient_capacity: Quantity::from_grams(900), chilled_capacity: Quantity::zero(), frozen_capacity: Quantity::zero(), accepts_prepared_meals: false }
}

fn audit_sample_demand() -> DemandLine {
  { id: "audit-demand", site_id: "audit-site", category: Produce, requested: Quantity::from_grams(800), minimum: Quantity::from_grams(400), delivery_day: Day::new(1), priority: 1 }
}

fn audit_plan_for(allocations : Array[Allocation]) -> AllocationPlan {
  { allocations, issues: [], metrics: { total_received: Quantity::zero(), total_allocated: Quantity::zero(), total_expired: Quantity::zero(), total_unallocated: Quantity::zero(), demand_requested: Quantity::zero(), demand_fulfilled: Quantity::zero(), demand_minimum_met: 0, demand_minimum_total: 0 }, generated_on: Day::new(0), policy_id: "test" }
}

test "audit accepts a feasible allocation" {
  let report = audit_plan(audit_plan_for([audit_sample_allocation(700, 1)]), [audit_sample_lot()], [audit_sample_site()], [audit_sample_demand()])
  assert_true(audit_is_clean(report))
  assert_eq(report.accepted_allocations, 1)
}

test "audit detects capacity and demand oversupply" {
  let report = audit_plan(audit_plan_for([audit_sample_allocation(950, 1)]), [audit_sample_lot()], [audit_sample_site()], [audit_sample_demand()])
  assert_true(report.findings.length() >= 2)
}

test "audit detects expired deliveries" {
  let report = audit_plan(audit_plan_for([audit_sample_allocation(500, 3)]), [audit_sample_lot()], [audit_sample_site()], [audit_sample_demand()])
  assert_eq(report.findings[0].code, DeliveryAfterExpiry)
}
