fn sample_lot(id : String, category : FoodCategory, storage : StorageZone, expires : Int, grams : Int) -> FoodLot {
  {
    id,
    category,
    storage,
    received_on: Day::new(0),
    expires_on: Day::new(expires),
    quantity: Quantity::from_grams(grams),
    state: Available,
    donor_reference: "sample",
    notes: "",
  }
}

fn sample_site(id : String, priority : Int, ambient : Int, chilled : Int) -> DistributionSite {
  {
    id,
    name: id,
    priority,
    ambient_capacity: Quantity::from_grams(ambient),
    chilled_capacity: Quantity::from_grams(chilled),
    frozen_capacity: Quantity::from_grams(0),
    accepts_prepared_meals: true,
  }
}

fn sample_demand(id : String, site_id : String, category : FoodCategory, requested : Int, minimum : Int, day : Int) -> DemandLine {
  {
    id,
    site_id,
    category,
    requested: Quantity::from_grams(requested),
    minimum: Quantity::from_grams(minimum),
    delivery_day: Day::new(day),
    priority: 1,
  }
}

test "quantity floors at zero" {
  let remaining = Quantity::from_grams(20).subtract_floor(Quantity::from_grams(50))
  assert_eq(remaining.grams, 0)
}

test "earliest expiring compatible lot is allocated first" {
  let lots = [
    sample_lot("late", Produce, Ambient, 9, 1000),
    sample_lot("early", Produce, Ambient, 2, 1000),
  ]
  let sites = [sample_site("north", 3, 3000, 0)]
  let demands = [sample_demand("north-produce", "north", Produce, 800, 500, 1)]
  let plan = plan_allocations(lots, sites, demands, Day::new(0), PolicyProfile::default())
  assert_eq(plan.allocations.length(), 1)
  assert_eq(plan.allocations[0].lot_id, "early")
  assert_eq(plan.allocations[0].quantity.grams, 800)
}

test "site capacity limits an allocation" {
  let lots = [sample_lot("milk", Dairy, Chilled, 6, 2000)]
  let sites = [sample_site("east", 2, 0, 700)]
  let demands = [sample_demand("east-dairy", "east", Dairy, 1500, 500, 1)]
  let plan = plan_allocations(lots, sites, demands, Day::new(0), PolicyProfile::default())
  assert_eq(plan.allocations.length(), 1)
  assert_eq(plan.allocations[0].quantity.grams, 700)
  assert_eq(plan.metrics.demand_minimum_met, 1)
}

test "prepared meals are blocked by a site capability" {
  let lots = [sample_lot("meal", PreparedMeal, Chilled, 4, 900)]
  let sites = [{
    id: "south",
    name: "South",
    priority: 2,
    ambient_capacity: Quantity::from_grams(0),
    chilled_capacity: Quantity::from_grams(1000),
    frozen_capacity: Quantity::from_grams(0),
    accepts_prepared_meals: false,
  }]
  let demands = [sample_demand("south-meals", "south", PreparedMeal, 500, 100, 1)]
  let plan = plan_allocations(lots, sites, demands, Day::new(0), PolicyProfile::default())
  assert_eq(plan.allocations.length(), 0)
}

test "invalid lots are reported" {
  let lots = [sample_lot("", Produce, Ambient, -1, 0)]
  let issues = validate_lots(lots, Day::new(0))
  assert_true(issues.length() >= 3)
}
