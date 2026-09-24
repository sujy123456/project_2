///|
/// Greedy, explainable allocation planner.  The planner chooses the best
/// eligible lot for each demand line and preserves every scoring decision.
pub fn lot_index_by_id(lots : Array[FoodLot], id : String) -> Int {
  let mut index = 0
  while index < lots.length() {
    if lots[index].id == id {
      return index
    }
    index = index + 1
  }
  -1
}

///|
pub fn demand_index_by_id(demands : Array[DemandLine], id : String) -> Int {
  let mut index = 0
  while index < demands.length() {
    if demands[index].id == id {
      return index
    }
    index = index + 1
  }
  -1
}

///|
pub fn total_quantity_of_lots(lots : Array[FoodLot]) -> Quantity {
  let mut total = Quantity::zero()
  let mut index = 0
  while index < lots.length() {
    total = total.add(lots[index].quantity)
    index = index + 1
  }
  total
}

///|
pub fn total_quantity_of_demands(demands : Array[DemandLine]) -> Quantity {
  let mut total = Quantity::zero()
  let mut index = 0
  while index < demands.length() {
    total = total.add(demands[index].requested)
    index = index + 1
  }
  total
}

///|
pub fn initial_quantities_lots(lots : Array[FoodLot]) -> Array[Quantity] {
  let values : Array[Quantity] = []
  let mut index = 0
  while index < lots.length() {
    values.push(lots[index].quantity)
    index = index + 1
  }
  values
}

///|
pub fn initial_quantities_demands(
  demands : Array[DemandLine],
) -> Array[Quantity] {
  let values : Array[Quantity] = []
  let mut index = 0
  while index < demands.length() {
    values.push(demands[index].requested)
    index = index + 1
  }
  values
}

///|
pub fn initial_site_capacity(
  sites : Array[DistributionSite],
  zone : StorageZone,
) -> Array[Quantity] {
  let values : Array[Quantity] = []
  let mut index = 0
  while index < sites.length() {
    values.push(sites[index].capacity_for(zone))
    index = index + 1
  }
  values
}

///|
pub fn site_index_by_id(sites : Array[DistributionSite], id : String) -> Int {
  let mut index = 0
  while index < sites.length() {
    if sites[index].id == id {
      return index
    }
    index = index + 1
  }
  -1
}

///|
pub fn capacity_available(
  ambient : Array[Quantity],
  chilled : Array[Quantity],
  frozen : Array[Quantity],
  site_index : Int,
  zone : StorageZone,
) -> Quantity {
  if site_index < 0 {
    Quantity::zero()
  } else {
    match zone {
      Ambient => ambient[site_index]
      Chilled => chilled[site_index]
      Frozen => frozen[site_index]
    }
  }
}

///|
pub fn reduce_capacity(
  ambient : Array[Quantity],
  chilled : Array[Quantity],
  frozen : Array[Quantity],
  site_index : Int,
  zone : StorageZone,
  amount : Quantity,
) -> Unit {
  if site_index >= 0 {
    match zone {
      Ambient =>
        ambient[site_index] = ambient[site_index].subtract_floor(amount)
      Chilled =>
        chilled[site_index] = chilled[site_index].subtract_floor(amount)
      Frozen => frozen[site_index] = frozen[site_index].subtract_floor(amount)
    }
  }
}

///|
pub fn best_lot_for_demand(
  lots : Array[FoodLot],
  remaining : Array[Quantity],
  demand : DemandLine,
  site : DistributionSite,
  on : Day,
  policy : PolicyProfile,
) -> Int {
  let mut best_index = -1
  let mut best_score = 2147483647
  let mut index = 0
  while index < lots.length() {
    let lot = lots[index]
    if !remaining[index].is_zero() &&
      allocation_is_feasible(lot, demand, site, on, policy) {
      let score = allocation_score(lot, demand, site, on, policy)
      if score < best_score {
        best_score = score
        best_index = index
      }
    }
    index = index + 1
  }
  best_index
}

///|
pub fn allocation_id(
  lot : FoodLot,
  demand : DemandLine,
  ordinal : Int,
) -> String {
  lot.id + "::" + demand.id + "::" + ordinal.to_string()
}

///|
pub fn allocate_demand(
  lots : Array[FoodLot],
  sites : Array[DistributionSite],
  demand : DemandLine,
  lot_remaining : Array[Quantity],
  site_ambient : Array[Quantity],
  site_chilled : Array[Quantity],
  site_frozen : Array[Quantity],
  on : Day,
  policy : PolicyProfile,
  ordinal_start : Int,
) -> Array[Allocation] {
  let allocations : Array[Allocation] = []
  let site_index = site_index_by_id(sites, demand.site_id)
  if site_index < 0 {
    return allocations
  }
  let site = sites[site_index]
  let mut unfilled = demand.requested
  let mut ordinal = ordinal_start
  while !unfilled.is_zero() {
    let lot_index = best_lot_for_demand(
      lots, lot_remaining, demand, site, on, policy,
    )
    if lot_index < 0 {
      return allocations
    }
    let lot = lots[lot_index]
    let capacity = capacity_available(
      site_ambient,
      site_chilled,
      site_frozen,
      site_index,
      lot.storage,
    )
    let amount = lot_remaining[lot_index].min(unfilled).min(capacity)
    if amount.is_zero() {
      lot_remaining[lot_index] = Quantity::zero()
    } else {
      let score = allocation_score(lot, demand, site, on, policy)
      allocations.push({
        id: allocation_id(lot, demand, ordinal),
        lot_id: lot.id,
        demand_id: demand.id,
        site_id: site.id,
        quantity: amount,
        planned_for: demand.delivery_day,
        reason: choose_reason(lot, demand, site, on, policy),
        score,
      })
      lot_remaining[lot_index] = lot_remaining[lot_index].subtract_floor(amount)
      reduce_capacity(
        site_ambient,
        site_chilled,
        site_frozen,
        site_index,
        lot.storage,
        amount,
      )
      unfilled = unfilled.subtract_floor(amount)
      ordinal = ordinal + 1
    }
  }
  allocations
}

///|
pub fn append_allocations(
  target : Array[Allocation],
  source : Array[Allocation],
) -> Unit {
  let mut index = 0
  while index < source.length() {
    target.push(source[index])
    index = index + 1
  }
}

///|
pub fn quantity_allocated_to_demand(
  allocations : Array[Allocation],
  demand_id : String,
) -> Quantity {
  let mut total = Quantity::zero()
  let mut index = 0
  while index < allocations.length() {
    if allocations[index].demand_id == demand_id {
      total = total.add(allocations[index].quantity)
    }
    index = index + 1
  }
  total
}

///|
pub fn quantity_allocated(allocations : Array[Allocation]) -> Quantity {
  let mut total = Quantity::zero()
  let mut index = 0
  while index < allocations.length() {
    total = total.add(allocations[index].quantity)
    index = index + 1
  }
  total
}

///|
pub fn metrics_for_plan(
  lots : Array[FoodLot],
  demands : Array[DemandLine],
  allocations : Array[Allocation],
  on : Day,
  policy : PolicyProfile,
) -> PlanMetrics {
  let metrics = PlanMetrics::empty()
  metrics.total_received = total_quantity_of_lots(lots)
  metrics.total_allocated = quantity_allocated(allocations)
  metrics.total_unallocated = metrics.total_received.subtract_floor(
    metrics.total_allocated,
  )
  metrics.demand_requested = total_quantity_of_demands(demands)
  metrics.demand_fulfilled = metrics.total_allocated
  let mut demand_index = 0
  while demand_index < demands.length() {
    metrics.demand_minimum_total = metrics.demand_minimum_total + 1
    if quantity_allocated_to_demand(allocations, demands[demand_index].id).grams >=
      demands[demand_index].minimum.grams {
      metrics.demand_minimum_met = metrics.demand_minimum_met + 1
    }
    demand_index = demand_index + 1
  }
  let mut lot_index = 0
  while lot_index < lots.length() {
    if lots[lot_index].urgency(on, policy.critical_days, policy.soon_days) ==
      Critical {
      metrics.critical_lots_total = metrics.critical_lots_total + 1
      if lots[lot_index].quantity.grams >
        remaining_for_lot(lots[lot_index], allocations).grams {
        metrics.critical_lots_allocated = metrics.critical_lots_allocated + 1
      }
    }
    lot_index = lot_index + 1
  }
  metrics
}

///|
pub fn remaining_for_lot(
  lot : FoodLot,
  allocations : Array[Allocation],
) -> Quantity {
  let mut allocated = Quantity::zero()
  let mut index = 0
  while index < allocations.length() {
    if allocations[index].lot_id == lot.id {
      allocated = allocated.add(allocations[index].quantity)
    }
    index = index + 1
  }
  lot.quantity.subtract_floor(allocated)
}

///|
pub fn plan_allocations(
  lots : Array[FoodLot],
  sites : Array[DistributionSite],
  demands : Array[DemandLine],
  on : Day,
  policy : PolicyProfile,
) -> AllocationPlan {
  let issues = collect_validation_issues(lots, sites, demands, on)
  let lot_remaining = initial_quantities_lots(lots)
  let site_ambient = initial_site_capacity(sites, Ambient)
  let site_chilled = initial_site_capacity(sites, Chilled)
  let site_frozen = initial_site_capacity(sites, Frozen)
  let allocations : Array[Allocation] = []
  let mut demand_index = 0
  let mut ordinal = 1
  while demand_index < demands.length() {
    let demand = demands[demand_index]
    if !has_error_for(issues, demand.id) {
      let made = allocate_demand(
        lots, sites, demand, lot_remaining, site_ambient, site_chilled, site_frozen,
        on, policy, ordinal,
      )
      ordinal = ordinal + made.length()
      append_allocations(allocations, made)
    }
    demand_index = demand_index + 1
  }
  {
    created_on: on,
    policy,
    allocations,
    issues,
    metrics: metrics_for_plan(lots, demands, allocations, on, policy),
  }
}
