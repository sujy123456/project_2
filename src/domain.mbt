/// PantryFlow domain model.
///
/// The core deliberately contains no donor, recipient, account, map, or payment
/// data. It operates on anonymous stock lots and aggregate demand only.

pub enum FoodCategory {
  Produce
  Bakery
  Dairy
  Protein
  PreparedMeal
  ShelfStable
  InfantNutrition
} derive(Eq, Show)

pub enum StorageZone {
  Ambient
  Chilled
  Frozen
} derive(Eq, Show)

pub enum LotState {
  Available
  Reserved
  Allocated
  Expired
  Blocked
} derive(Eq, Show)

pub enum Urgency {
  Routine
  Soon
  Critical
} derive(Eq, Show)

pub enum AllocationReason {
  EarliestExpiry
  MinimumCoverage
  HighPrioritySite
  StorageCompatibility
  ManualReservation
} derive(Eq, Show)

pub enum ValidationCode {
  EmptyIdentifier
  NegativeQuantity
  InvalidDate
  ExpiredLot
  StorageMismatch
  UnknownCategory
  DuplicateIdentifier
  MissingDemand
  ImpossibleCapacity
  ParseFailure
} derive(Eq, Show)

pub struct Day {
  value : Int
} derive(Eq, Show)

pub fn Day::new(value : Int) -> Day {
  { value }
}

pub fn Day::add(self : Day, days : Int) -> Day {
  { value: self.value + days }
}

pub fn Day::distance_to(self : Day, later : Day) -> Int {
  later.value - self.value
}

pub fn Day::is_before(self : Day, other : Day) -> Bool {
  self.value < other.value
}

pub fn Day::is_after(self : Day, other : Day) -> Bool {
  self.value > other.value
}

pub struct Quantity {
  grams : Int
} derive(Eq, Show)

pub fn Quantity::zero() -> Quantity {
  { grams: 0 }
}

pub fn Quantity::from_grams(grams : Int) -> Quantity {
  { grams: if grams < 0 { 0 } else { grams } }
}

pub fn Quantity::add(self : Quantity, other : Quantity) -> Quantity {
  { grams: self.grams + other.grams }
}

pub fn Quantity::subtract_floor(self : Quantity, other : Quantity) -> Quantity {
  { grams: if self.grams > other.grams { self.grams - other.grams } else { 0 } }
}

pub fn Quantity::min(self : Quantity, other : Quantity) -> Quantity {
  if self.grams < other.grams { self } else { other }
}

pub fn Quantity::is_zero(self : Quantity) -> Bool {
  self.grams == 0
}

pub struct FoodLot {
  id : String
  category : FoodCategory
  storage : StorageZone
  received_on : Day
  expires_on : Day
  quantity : Quantity
  state : LotState
  donor_reference : String
  notes : String
} derive(Show)

pub fn FoodLot::remaining_days(self : FoodLot, on : Day) -> Int {
  on.distance_to(self.expires_on)
}

pub fn FoodLot::is_usable_on(self : FoodLot, on : Day) -> Bool {
  self.state == Available && not(self.expires_on.is_before(on)) && not(self.quantity.is_zero())
}

pub fn FoodLot::urgency(self : FoodLot, on : Day, critical_days : Int, soon_days : Int) -> Urgency {
  let remaining = self.remaining_days(on)
  if remaining <= critical_days {
    Critical
  } else if remaining <= soon_days {
    Soon
  } else {
    Routine
  }
}

pub struct DistributionSite {
  id : String
  name : String
  priority : Int
  ambient_capacity : Quantity
  chilled_capacity : Quantity
  frozen_capacity : Quantity
  accepts_prepared_meals : Bool
} derive(Show)

pub fn DistributionSite::capacity_for(self : DistributionSite, zone : StorageZone) -> Quantity {
  match zone {
    Ambient => self.ambient_capacity
    Chilled => self.chilled_capacity
    Frozen => self.frozen_capacity
  }
}

pub fn DistributionSite::accepts(self : DistributionSite, lot : FoodLot) -> Bool {
  match lot.category {
    PreparedMeal => self.accepts_prepared_meals
    _ => true
  }
}

pub struct DemandLine {
  id : String
  site_id : String
  category : FoodCategory
  requested : Quantity
  minimum : Quantity
  delivery_day : Day
  priority : Int
} derive(Show)

pub fn DemandLine::is_valid(self : DemandLine) -> Bool {
  self.requested.grams >= self.minimum.grams && self.minimum.grams >= 0
}

pub struct Allocation {
  id : String
  lot_id : String
  demand_id : String
  site_id : String
  quantity : Quantity
  planned_for : Day
  reason : AllocationReason
  score : Int
} derive(Show)

pub struct PolicyProfile {
  id : String
  version : String
  critical_days : Int
  soon_days : Int
  max_site_priority : Int
  waste_penalty_per_gram : Int
  unmet_minimum_penalty : Int
  over_supply_penalty : Int
  allow_cross_category_substitution : Bool
} derive(Show)

pub fn PolicyProfile::default() -> PolicyProfile {
  {
    id: "default",
    version: "1",
    critical_days: 2,
    soon_days: 5,
    max_site_priority: 5,
    waste_penalty_per_gram: 5,
    unmet_minimum_penalty: 1000,
    over_supply_penalty: 1,
    allow_cross_category_substitution: false,
  }
}

pub struct ValidationIssue {
  code : ValidationCode
  subject : String
  message : String
} derive(Show)

pub struct PlanMetrics {
  mut total_received : Quantity
  mut total_allocated : Quantity
  total_expired : Quantity
  mut total_unallocated : Quantity
  mut demand_requested : Quantity
  mut demand_fulfilled : Quantity
  mut demand_minimum_met : Int
  mut demand_minimum_total : Int
  mut critical_lots_allocated : Int
  mut critical_lots_total : Int
} derive(Show)

pub fn PlanMetrics::empty() -> PlanMetrics {
  {
    total_received: Quantity::zero(),
    total_allocated: Quantity::zero(),
    total_expired: Quantity::zero(),
    total_unallocated: Quantity::zero(),
    demand_requested: Quantity::zero(),
    demand_fulfilled: Quantity::zero(),
    demand_minimum_met: 0,
    demand_minimum_total: 0,
    critical_lots_allocated: 0,
    critical_lots_total: 0,
  }
}

pub struct AllocationPlan {
  created_on : Day
  policy : PolicyProfile
  allocations : Array[Allocation]
  issues : Array[ValidationIssue]
  metrics : PlanMetrics
} derive(Show)

pub struct SimulationDay {
  day : Day
  delivered : Quantity
  expired : Quantity
  remaining : Quantity
  unmet_demand : Quantity
} derive(Show)

pub struct SimulationResult {
  timeline : Array[SimulationDay]
  total_expired : Quantity
  total_delivered : Quantity
  total_unmet : Quantity
} derive(Show)

pub fn category_name(category : FoodCategory) -> String {
  match category {
    Produce => "produce"
    Bakery => "bakery"
    Dairy => "dairy"
    Protein => "protein"
    PreparedMeal => "prepared_meal"
    ShelfStable => "shelf_stable"
    InfantNutrition => "infant_nutrition"
  }
}

pub fn storage_name(zone : StorageZone) -> String {
  match zone {
    Ambient => "ambient"
    Chilled => "chilled"
    Frozen => "frozen"
  }
}

pub fn urgency_name(urgency : Urgency) -> String {
  match urgency {
    Routine => "routine"
    Soon => "soon"
    Critical => "critical"
  }
}

pub fn reason_name(reason : AllocationReason) -> String {
  match reason {
    EarliestExpiry => "earliest_expiry"
    MinimumCoverage => "minimum_coverage"
    HighPrioritySite => "high_priority_site"
    StorageCompatibility => "storage_compatibility"
    ManualReservation => "manual_reservation"
  }
}
