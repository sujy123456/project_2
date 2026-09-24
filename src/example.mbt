/// A deterministic fictional scenario used by the CLI, tests, and browser demo.

pub fn example_lots() -> Array[FoodLot] {
  [
    { id: "apple-a", category: Produce, storage: Ambient, received_on: Day::new(0), expires_on: Day::new(2), quantity: Quantity::from_grams(18000), state: Available, donor_reference: "example", notes: "fictional apples" },
    { id: "bread-a", category: Bakery, storage: Ambient, received_on: Day::new(0), expires_on: Day::new(1), quantity: Quantity::from_grams(9000), state: Available, donor_reference: "example", notes: "fictional bread" },
    { id: "milk-a", category: Dairy, storage: Chilled, received_on: Day::new(0), expires_on: Day::new(3), quantity: Quantity::from_grams(12000), state: Available, donor_reference: "example", notes: "fictional milk" },
    { id: "beans-a", category: Protein, storage: Ambient, received_on: Day::new(0), expires_on: Day::new(30), quantity: Quantity::from_grams(24000), state: Available, donor_reference: "example", notes: "fictional beans" },
    { id: "meal-a", category: PreparedMeal, storage: Chilled, received_on: Day::new(0), expires_on: Day::new(1), quantity: Quantity::from_grams(7000), state: Available, donor_reference: "example", notes: "fictional meals" },
    { id: "rice-a", category: ShelfStable, storage: Ambient, received_on: Day::new(0), expires_on: Day::new(180), quantity: Quantity::from_grams(40000), state: Available, donor_reference: "example", notes: "fictional rice" },
    { id: "formula-a", category: InfantNutrition, storage: Ambient, received_on: Day::new(0), expires_on: Day::new(90), quantity: Quantity::from_grams(4000), state: Available, donor_reference: "example", notes: "fictional formula" },
  ]
}

pub fn example_sites() -> Array[DistributionSite] {
  [
    { id: "north", name: "North community pantry", priority: 5, ambient_capacity: Quantity::from_grams(50000), chilled_capacity: Quantity::from_grams(18000), frozen_capacity: Quantity::from_grams(0), accepts_prepared_meals: true },
    { id: "east", name: "East family centre", priority: 4, ambient_capacity: Quantity::from_grams(40000), chilled_capacity: Quantity::from_grams(8000), frozen_capacity: Quantity::from_grams(0), accepts_prepared_meals: false },
    { id: "west", name: "West outreach point", priority: 2, ambient_capacity: Quantity::from_grams(16000), chilled_capacity: Quantity::from_grams(3000), frozen_capacity: Quantity::from_grams(0), accepts_prepared_meals: true },
  ]
}

pub fn example_demands() -> Array[DemandLine] {
  [
    { id: "north-produce", site_id: "north", category: Produce, requested: Quantity::from_grams(12000), minimum: Quantity::from_grams(9000), delivery_day: Day::new(1), priority: 5 },
    { id: "north-dairy", site_id: "north", category: Dairy, requested: Quantity::from_grams(8000), minimum: Quantity::from_grams(5000), delivery_day: Day::new(1), priority: 5 },
    { id: "north-meals", site_id: "north", category: PreparedMeal, requested: Quantity::from_grams(4000), minimum: Quantity::from_grams(2000), delivery_day: Day::new(1), priority: 5 },
    { id: "east-bakery", site_id: "east", category: Bakery, requested: Quantity::from_grams(8000), minimum: Quantity::from_grams(5000), delivery_day: Day::new(1), priority: 4 },
    { id: "east-protein", site_id: "east", category: Protein, requested: Quantity::from_grams(10000), minimum: Quantity::from_grams(7000), delivery_day: Day::new(2), priority: 4 },
    { id: "west-shelf", site_id: "west", category: ShelfStable, requested: Quantity::from_grams(18000), minimum: Quantity::from_grams(10000), delivery_day: Day::new(2), priority: 2 },
    { id: "west-infant", site_id: "west", category: InfantNutrition, requested: Quantity::from_grams(3000), minimum: Quantity::from_grams(2000), delivery_day: Day::new(2), priority: 2 },
  ]
}

pub fn example_policy() -> PolicyProfile {
  { id: "community-week", version: "1.0", critical_days: 1, soon_days: 3, max_site_priority: 5, waste_penalty_per_gram: 5, unmet_minimum_penalty: 1000, over_supply_penalty: 1, allow_cross_category_substitution: false }
}

pub fn example_plan() -> AllocationPlan {
  plan_allocations(example_lots(), example_sites(), example_demands(), Day::new(0), example_policy())
}

pub fn example_simulation() -> ScenarioSummary {
  let plan = example_plan()
  simulate(example_lots(), example_demands(), plan.allocations, SimulationConfig::default(Day::new(0)))
}

pub fn example_report() -> String {
  let plan = example_plan()
  markdown_report(example_lots(), example_sites(), example_demands(), plan, example_simulation())
}
