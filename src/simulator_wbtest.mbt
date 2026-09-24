///|
test "simulation removes expired inventory before fulfilment" {
  let lots = [sample_lot("old-apple", Produce, Ambient, 0, 600)]
  let demands = [sample_demand("next-day", "north", Produce, 500, 0, 1)]
  let result = simulate(lots, demands, [], SimulationConfig::{
    start_day: Day::new(0),
    horizon_days: 2,
    daily_decay_basis_points: 0,
    preserve_frozen: true,
    include_planned_allocations: false,
  })
  assert_eq(result.expired.grams, 600)
  assert_eq(result.delivered.grams, 0)
  assert_eq(result.unmet.grams, 500)
}

///|
test "simulation uses FEFO for unplanned issue" {
  let lots = [
    sample_lot("later", Bakery, Ambient, 10, 500),
    sample_lot("earlier", Bakery, Ambient, 2, 400),
  ]
  let demands = [sample_demand("bakery-day", "north", Bakery, 700, 0, 0)]
  let result = simulate(lots, demands, [], SimulationConfig::{
    start_day: Day::new(0),
    horizon_days: 1,
    daily_decay_basis_points: 0,
    preserve_frozen: true,
    include_planned_allocations: false,
  })
  assert_eq(result.delivered.grams, 700)
  assert_eq(result.final_inventory.grams, 200)
}

///|
test "daily decay does not spoil frozen inventory by default" {
  let lots = [sample_lot("frozen-protein", Protein, Frozen, 20, 1000)]
  let result = simulate(lots, [], [], SimulationConfig::{
    start_day: Day::new(0),
    horizon_days: 3,
    daily_decay_basis_points: 1000,
    preserve_frozen: true,
    include_planned_allocations: false,
  })
  assert_eq(result.spoiled.grams, 0)
  assert_eq(result.final_inventory.grams, 1000)
}
