///|
/// Deterministic day-by-day loss simulation.  It consumes an approved plan and
/// models only stock movement, expiry, and unmet aggregate demand.
pub struct DailyDemand {
  day : Day
  category : FoodCategory
  quantity : Quantity
} derive(Show)

///|
pub struct SimulationConfig {
  start_day : Day
  horizon_days : Int
  daily_decay_basis_points : Int
  preserve_frozen : Bool
  include_planned_allocations : Bool
} derive(Show)

///|
pub struct InventoryPosition {
  lot_id : String
  category : FoodCategory
  storage : StorageZone
  expires_on : Day
  mut remaining : Quantity
} derive(Show)

///|
pub struct DayOutcome {
  day : Day
  delivered : Quantity
  expired : Quantity
  spoiled : Quantity
  unmet : Quantity
  remaining : Quantity
  active_lots : Int
} derive(Show)

///|
pub struct ScenarioSummary {
  outcomes : Array[DayOutcome]
  delivered : Quantity
  expired : Quantity
  spoiled : Quantity
  unmet : Quantity
  final_inventory : Quantity
} derive(Show)

///|
pub fn SimulationConfig::default(start_day : Day) -> SimulationConfig {
  {
    start_day,
    horizon_days: 14,
    daily_decay_basis_points: 0,
    preserve_frozen: true,
    include_planned_allocations: true,
  }
}

///|
pub fn positions_from_lots(lots : Array[FoodLot]) -> Array[InventoryPosition] {
  let positions : Array[InventoryPosition] = []
  let mut index = 0
  while index < lots.length() {
    let lot = lots[index]
    positions.push({
      lot_id: lot.id,
      category: lot.category,
      storage: lot.storage,
      expires_on: lot.expires_on,
      remaining: lot.quantity,
    })
    index = index + 1
  }
  positions
}

///|
pub fn planned_delivery_for_day(
  allocations : Array[Allocation],
  day : Day,
) -> Quantity {
  let mut total = Quantity::zero()
  let mut index = 0
  while index < allocations.length() {
    if allocations[index].planned_for == day {
      total = total.add(allocations[index].quantity)
    }
    index = index + 1
  }
  total
}

///|
pub fn planned_delivery_for_lot_on_day(
  allocations : Array[Allocation],
  lot_id : String,
  day : Day,
) -> Quantity {
  let mut total = Quantity::zero()
  let mut index = 0
  while index < allocations.length() {
    let allocation = allocations[index]
    if allocation.lot_id == lot_id && allocation.planned_for == day {
      total = total.add(allocation.quantity)
    }
    index = index + 1
  }
  total
}

///|
pub fn demand_for_day(demands : Array[DemandLine], day : Day) -> Quantity {
  let mut total = Quantity::zero()
  let mut index = 0
  while index < demands.length() {
    if demands[index].delivery_day == day {
      total = total.add(demands[index].requested)
    }
    index = index + 1
  }
  total
}

///|
pub fn category_demand_for_day(
  demands : Array[DemandLine],
  day : Day,
  category : FoodCategory,
) -> Quantity {
  let mut total = Quantity::zero()
  let mut index = 0
  while index < demands.length() {
    let demand = demands[index]
    if demand.delivery_day == day && demand.category == category {
      total = total.add(demand.requested)
    }
    index = index + 1
  }
  total
}

///|
pub fn total_remaining(positions : Array[InventoryPosition]) -> Quantity {
  let mut total = Quantity::zero()
  let mut index = 0
  while index < positions.length() {
    total = total.add(positions[index].remaining)
    index = index + 1
  }
  total
}

///|
pub fn active_position_count(positions : Array[InventoryPosition]) -> Int {
  let mut count = 0
  let mut index = 0
  while index < positions.length() {
    if !positions[index].remaining.is_zero() {
      count = count + 1
    }
    index = index + 1
  }
  count
}

///|
pub fn remove_expired(
  positions : Array[InventoryPosition],
  day : Day,
) -> Quantity {
  let mut expired = Quantity::zero()
  let mut index = 0
  while index < positions.length() {
    if positions[index].expires_on.is_before(day) &&
      !positions[index].remaining.is_zero() {
      expired = expired.add(positions[index].remaining)
      positions[index].remaining = Quantity::zero()
    }
    index = index + 1
  }
  expired
}

///|
pub fn decay_quantity(quantity : Quantity, basis_points : Int) -> Quantity {
  if basis_points <= 0 || quantity.is_zero() {
    Quantity::zero()
  } else {
    Quantity::from_grams(quantity.grams * basis_points / 10000)
  }
}

///|
pub fn apply_daily_decay(
  positions : Array[InventoryPosition],
  config : SimulationConfig,
) -> Quantity {
  let mut spoiled = Quantity::zero()
  let mut index = 0
  while index < positions.length() {
    let position = positions[index]
    let keep = config.preserve_frozen && position.storage == Frozen
    if !keep {
      let loss = decay_quantity(
        position.remaining,
        config.daily_decay_basis_points,
      )
      positions[index].remaining = positions[index].remaining.subtract_floor(
        loss,
      )
      spoiled = spoiled.add(loss)
    }
    index = index + 1
  }
  spoiled
}

///|
pub fn choose_earliest_position(
  positions : Array[InventoryPosition],
  category : FoodCategory,
  day : Day,
) -> Int {
  let mut selected = -1
  let mut index = 0
  while index < positions.length() {
    let current = positions[index]
    let eligible = current.category == category &&
      !current.remaining.is_zero() &&
      !current.expires_on.is_before(day)
    if eligible {
      if selected < 0 ||
        current.expires_on.is_before(positions[selected].expires_on) {
        selected = index
      }
    }
    index = index + 1
  }
  selected
}

///|
pub fn issue_from_category(
  positions : Array[InventoryPosition],
  category : FoodCategory,
  requested : Quantity,
  day : Day,
) -> Quantity {
  let mut outstanding = requested
  let mut issued = Quantity::zero()
  while !outstanding.is_zero() {
    let index = choose_earliest_position(positions, category, day)
    if index < 0 {
      return issued
    }
    let amount = positions[index].remaining.min(outstanding)
    positions[index].remaining = positions[index].remaining.subtract_floor(
      amount,
    )
    outstanding = outstanding.subtract_floor(amount)
    issued = issued.add(amount)
  }
  issued
}

///|
pub fn issue_demand(
  positions : Array[InventoryPosition],
  demands : Array[DemandLine],
  day : Day,
) -> Quantity {
  let mut total = Quantity::zero()
  let categories = [
    Produce,
    Bakery,
    Dairy,
    Protein,
    PreparedMeal,
    ShelfStable,
    InfantNutrition,
  ]
  let mut index = 0
  while index < categories.length() {
    let category = categories[index]
    total = total.add(
      issue_from_category(
        positions,
        category,
        category_demand_for_day(demands, day, category),
        day,
      ),
    )
    index = index + 1
  }
  total
}

///|
pub fn apply_planned_delivery(
  positions : Array[InventoryPosition],
  allocations : Array[Allocation],
  day : Day,
) -> Quantity {
  let mut delivered = Quantity::zero()
  let mut index = 0
  while index < positions.length() {
    let amount = planned_delivery_for_lot_on_day(
      allocations,
      positions[index].lot_id,
      day,
    )
    let actual = positions[index].remaining.min(amount)
    positions[index].remaining = positions[index].remaining.subtract_floor(
      actual,
    )
    delivered = delivered.add(actual)
    index = index + 1
  }
  delivered
}

///|
pub fn simulate_day(
  positions : Array[InventoryPosition],
  demands : Array[DemandLine],
  allocations : Array[Allocation],
  day : Day,
  config : SimulationConfig,
) -> DayOutcome {
  let expired = remove_expired(positions, day)
  let spoiled = apply_daily_decay(positions, config)
  let delivered = if config.include_planned_allocations {
    apply_planned_delivery(positions, allocations, day)
  } else {
    issue_demand(positions, demands, day)
  }
  let requested = demand_for_day(demands, day)
  {
    day,
    delivered,
    expired,
    spoiled,
    unmet: requested.subtract_floor(delivered),
    remaining: total_remaining(positions),
    active_lots: active_position_count(positions),
  }
}

///|
pub fn summarize_outcomes(outcomes : Array[DayOutcome]) -> ScenarioSummary {
  let mut delivered = Quantity::zero()
  let mut expired = Quantity::zero()
  let mut spoiled = Quantity::zero()
  let mut unmet = Quantity::zero()
  let mut final_inventory = Quantity::zero()
  let mut index = 0
  while index < outcomes.length() {
    let outcome = outcomes[index]
    delivered = delivered.add(outcome.delivered)
    expired = expired.add(outcome.expired)
    spoiled = spoiled.add(outcome.spoiled)
    unmet = unmet.add(outcome.unmet)
    final_inventory = outcome.remaining
    index = index + 1
  }
  { outcomes, delivered, expired, spoiled, unmet, final_inventory, }
}

///|
pub fn simulate(
  lots : Array[FoodLot],
  demands : Array[DemandLine],
  allocations : Array[Allocation],
  config : SimulationConfig,
) -> ScenarioSummary {
  let positions = positions_from_lots(lots)
  let outcomes : Array[DayOutcome] = []
  let mut offset = 0
  while offset < config.horizon_days {
    outcomes.push(
      simulate_day(
        positions,
        demands,
        allocations,
        config.start_day.add(offset),
        config,
      ),
    )
    offset = offset + 1
  }
  summarize_outcomes(outcomes)
}
