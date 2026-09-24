///|
/// Post-plan analysis turns allocations into operational facts.  It deliberately
/// reports shortages and infeasible requests instead of silently filling them.
pub enum AlertKind {
  UnmetMinimum
  UnmetRequest
  CriticalLotUnallocated
  ExpiryRisk
  StorageCapacityRisk
  InvalidInput
} derive(Eq, Show)

///|
pub enum AlertLevel {
  Information
  Warning
  ActionRequired
} derive(Eq, Show)

///|
pub struct PlanAlert {
  kind : AlertKind
  level : AlertLevel
  subject : String
  message : String
  quantity : Quantity
} derive(Show)

///|
pub struct DemandCoverage {
  demand_id : String
  site_id : String
  requested : Quantity
  minimum : Quantity
  allocated : Quantity
  uncovered : Quantity
  minimum_satisfied : Bool
  request_satisfied : Bool
  coverage_basis_points : Int
} derive(Show)

///|
pub struct LotDisposition {
  lot_id : String
  category : FoodCategory
  expires_on : Day
  received : Quantity
  allocated : Quantity
  remaining : Quantity
  urgency : Urgency
  will_expire_before_plan_end : Bool
} derive(Show)

///|
pub struct SiteLoad {
  site_id : String
  ambient_used : Quantity
  chilled_used : Quantity
  frozen_used : Quantity
  ambient_capacity : Quantity
  chilled_capacity : Quantity
  frozen_capacity : Quantity
} derive(Show)

///|
pub fn quantity_sum(values : Array[Quantity]) -> Quantity {
  let mut total = Quantity::zero()
  let mut index = 0
  while index < values.length() {
    total = total.add(values[index])
    index = index + 1
  }
  total
}

///|
pub fn quantity_max(left : Quantity, right : Quantity) -> Quantity {
  if left.grams > right.grams {
    left
  } else {
    right
  }
}

///|
pub fn quantity_ratio_basis_points(
  numerator : Quantity,
  denominator : Quantity,
) -> Int {
  if denominator.grams <= 0 {
    10000
  } else {
    numerator.grams * 10000 / denominator.grams
  }
}

///|
pub fn coverage_for_demand(
  demand : DemandLine,
  allocations : Array[Allocation],
) -> DemandCoverage {
  let allocated = quantity_allocated_to_demand(allocations, demand.id)
  let uncovered = demand.requested.subtract_floor(allocated)
  {
    demand_id: demand.id,
    site_id: demand.site_id,
    requested: demand.requested,
    minimum: demand.minimum,
    allocated,
    uncovered,
    minimum_satisfied: allocated.grams >= demand.minimum.grams,
    request_satisfied: allocated.grams >= demand.requested.grams,
    coverage_basis_points: quantity_ratio_basis_points(
      allocated.min(demand.requested),
      demand.requested,
    ),
  }
}

///|
pub fn coverages_for_demands(
  demands : Array[DemandLine],
  allocations : Array[Allocation],
) -> Array[DemandCoverage] {
  let values : Array[DemandCoverage] = []
  let mut index = 0
  while index < demands.length() {
    values.push(coverage_for_demand(demands[index], allocations))
    index = index + 1
  }
  values
}

///|
pub fn latest_delivery_day(demands : Array[DemandLine], fallback : Day) -> Day {
  let mut latest = fallback
  let mut index = 0
  while index < demands.length() {
    if latest.is_before(demands[index].delivery_day) {
      latest = demands[index].delivery_day
    }
    index = index + 1
  }
  latest
}

///|
pub fn disposition_for_lot(
  lot : FoodLot,
  allocations : Array[Allocation],
  on : Day,
  plan_end : Day,
  policy : PolicyProfile,
) -> LotDisposition {
  let remaining = remaining_for_lot(lot, allocations)
  {
    lot_id: lot.id,
    category: lot.category,
    expires_on: lot.expires_on,
    received: lot.quantity,
    allocated: lot.quantity.subtract_floor(remaining),
    remaining,
    urgency: lot.urgency(on, policy.critical_days, policy.soon_days),
    will_expire_before_plan_end: lot.expires_on.is_before(plan_end),
  }
}

///|
pub fn dispositions_for_lots(
  lots : Array[FoodLot],
  allocations : Array[Allocation],
  on : Day,
  demands : Array[DemandLine],
  policy : PolicyProfile,
) -> Array[LotDisposition] {
  let values : Array[LotDisposition] = []
  let plan_end = latest_delivery_day(demands, on)
  let mut index = 0
  while index < lots.length() {
    values.push(
      disposition_for_lot(lots[index], allocations, on, plan_end, policy),
    )
    index = index + 1
  }
  values
}

///|
pub fn allocation_matches_site_and_zone(
  allocation : Allocation,
  lot : FoodLot,
  site_id : String,
  zone : StorageZone,
) -> Bool {
  allocation.site_id == site_id &&
  allocation.lot_id == lot.id &&
  lot.storage == zone
}

///|
pub fn used_capacity_for_site(
  allocations : Array[Allocation],
  lots : Array[FoodLot],
  site_id : String,
  zone : StorageZone,
) -> Quantity {
  let mut total = Quantity::zero()
  let mut allocation_index = 0
  while allocation_index < allocations.length() {
    let allocation = allocations[allocation_index]
    let lot_index = lot_index_by_id(lots, allocation.lot_id)
    if lot_index >= 0 &&
      allocation_matches_site_and_zone(
        allocation,
        lots[lot_index],
        site_id,
        zone,
      ) {
      total = total.add(allocation.quantity)
    }
    allocation_index = allocation_index + 1
  }
  total
}

///|
pub fn loads_for_sites(
  sites : Array[DistributionSite],
  lots : Array[FoodLot],
  allocations : Array[Allocation],
) -> Array[SiteLoad] {
  let loads : Array[SiteLoad] = []
  let mut index = 0
  while index < sites.length() {
    let site = sites[index]
    loads.push({
      site_id: site.id,
      ambient_used: used_capacity_for_site(allocations, lots, site.id, Ambient),
      chilled_used: used_capacity_for_site(allocations, lots, site.id, Chilled),
      frozen_used: used_capacity_for_site(allocations, lots, site.id, Frozen),
      ambient_capacity: site.ambient_capacity,
      chilled_capacity: site.chilled_capacity,
      frozen_capacity: site.frozen_capacity,
    })
    index = index + 1
  }
  loads
}

///|
pub fn issue_alerts(issues : Array[ValidationIssue]) -> Array[PlanAlert] {
  let alerts : Array[PlanAlert] = []
  let mut index = 0
  while index < issues.length() {
    let issue = issues[index]
    alerts.push({
      kind: InvalidInput,
      level: ActionRequired,
      subject: issue.subject,
      message: issue.message,
      quantity: Quantity::zero(),
    })
    index = index + 1
  }
  alerts
}

///|
pub fn coverage_alerts(coverages : Array[DemandCoverage]) -> Array[PlanAlert] {
  let alerts : Array[PlanAlert] = []
  let mut index = 0
  while index < coverages.length() {
    let coverage = coverages[index]
    if !coverage.minimum_satisfied {
      alerts.push({
        kind: UnmetMinimum,
        level: ActionRequired,
        subject: coverage.demand_id,
        message: "minimum requested quantity cannot be supplied",
        quantity: coverage.minimum.subtract_floor(coverage.allocated),
      })
    } else if !coverage.request_satisfied {
      alerts.push({
        kind: UnmetRequest,
        level: Warning,
        subject: coverage.demand_id,
        message: "requested quantity is partially supplied",
        quantity: coverage.uncovered,
      })
    }
    index = index + 1
  }
  alerts
}

///|
pub fn lot_alerts(dispositions : Array[LotDisposition]) -> Array[PlanAlert] {
  let alerts : Array[PlanAlert] = []
  let mut index = 0
  while index < dispositions.length() {
    let disposition = dispositions[index]
    if disposition.urgency == Critical && !disposition.remaining.is_zero() {
      alerts.push({
        kind: CriticalLotUnallocated,
        level: ActionRequired,
        subject: disposition.lot_id,
        message: "critical lot remains after planned allocations",
        quantity: disposition.remaining,
      })
    } else if disposition.will_expire_before_plan_end &&
      !disposition.remaining.is_zero() {
      alerts.push({
        kind: ExpiryRisk,
        level: Warning,
        subject: disposition.lot_id,
        message: "remaining lot expires before the final scheduled delivery",
        quantity: disposition.remaining,
      })
    }
    index = index + 1
  }
  alerts
}

///|
pub fn capacity_alerts(loads : Array[SiteLoad]) -> Array[PlanAlert] {
  let alerts : Array[PlanAlert] = []
  let mut index = 0
  while index < loads.length() {
    let load = loads[index]
    if load.ambient_used.grams >= load.ambient_capacity.grams &&
      load.ambient_capacity.grams > 0 {
      alerts.push({
        kind: StorageCapacityRisk,
        level: Information,
        subject: load.site_id,
        message: "ambient capacity is fully used",
        quantity: load.ambient_used,
      })
    }
    if load.chilled_used.grams >= load.chilled_capacity.grams &&
      load.chilled_capacity.grams > 0 {
      alerts.push({
        kind: StorageCapacityRisk,
        level: Information,
        subject: load.site_id,
        message: "chilled capacity is fully used",
        quantity: load.chilled_used,
      })
    }
    if load.frozen_used.grams >= load.frozen_capacity.grams &&
      load.frozen_capacity.grams > 0 {
      alerts.push({
        kind: StorageCapacityRisk,
        level: Information,
        subject: load.site_id,
        message: "frozen capacity is fully used",
        quantity: load.frozen_used,
      })
    }
    index = index + 1
  }
  alerts
}

///|
pub fn append_alerts(
  target : Array[PlanAlert],
  source : Array[PlanAlert],
) -> Unit {
  let mut index = 0
  while index < source.length() {
    target.push(source[index])
    index = index + 1
  }
}

///|
pub fn analyze_plan(
  lots : Array[FoodLot],
  sites : Array[DistributionSite],
  demands : Array[DemandLine],
  plan : AllocationPlan,
) -> Array[PlanAlert] {
  let coverages = coverages_for_demands(demands, plan.allocations)
  let dispositions = dispositions_for_lots(
    lots,
    plan.allocations,
    plan.created_on,
    demands,
    plan.policy,
  )
  let loads = loads_for_sites(sites, lots, plan.allocations)
  let alerts : Array[PlanAlert] = []
  append_alerts(alerts, issue_alerts(plan.issues))
  append_alerts(alerts, coverage_alerts(coverages))
  append_alerts(alerts, lot_alerts(dispositions))
  append_alerts(alerts, capacity_alerts(loads))
  alerts
}

///|
pub fn alert_level_name(level : AlertLevel) -> String {
  match level {
    Information => "information"
    Warning => "warning"
    ActionRequired => "action_required"
  }
}

///|
pub fn alert_kind_name(kind : AlertKind) -> String {
  match kind {
    UnmetMinimum => "unmet_minimum"
    UnmetRequest => "unmet_request"
    CriticalLotUnallocated => "critical_lot_unallocated"
    ExpiryRisk => "expiry_risk"
    StorageCapacityRisk => "storage_capacity_risk"
    InvalidInput => "invalid_input"
  }
}
