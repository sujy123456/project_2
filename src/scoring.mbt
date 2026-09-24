///|
/// Scoring is intentionally transparent. A lower score is a better assignment.
pub fn compatible_category(
  lot : FoodLot,
  demand : DemandLine,
  policy : PolicyProfile,
) -> Bool {
  if lot.category == demand.category {
    true
  } else if policy.allow_cross_category_substitution {
    match (lot.category, demand.category) {
      (Produce, PreparedMeal) => false
      (PreparedMeal, Produce) => false
      (InfantNutrition, _) => false
      (_, InfantNutrition) => false
      _ => true
    }
  } else {
    false
  }
}

///|
pub fn compatibility_reason(
  lot : FoodLot,
  demand : DemandLine,
) -> AllocationReason {
  if lot.category == demand.category {
    EarliestExpiry
  } else {
    StorageCompatibility
  }
}

///|
pub fn urgency_penalty(lot : FoodLot, on : Day, policy : PolicyProfile) -> Int {
  match lot.urgency(on, policy.critical_days, policy.soon_days) {
    Critical => -500
    Soon => -100
    Routine => 0
  }
}

///|
pub fn site_priority_penalty(
  site : DistributionSite,
  policy : PolicyProfile,
) -> Int {
  let normalized = if site.priority > policy.max_site_priority {
    policy.max_site_priority
  } else {
    site.priority
  }
  (policy.max_site_priority - normalized) * 20
}

///|
pub fn expiry_penalty(lot : FoodLot, planned_for : Day) -> Int {
  let remaining = lot.remaining_days(planned_for)
  if remaining < 0 {
    1000000
  } else {
    remaining * 10
  }
}

///|
pub fn allocation_score(
  lot : FoodLot,
  demand : DemandLine,
  site : DistributionSite,
  on : Day,
  policy : PolicyProfile,
) -> Int {
  expiry_penalty(lot, demand.delivery_day) +
  urgency_penalty(lot, on, policy) +
  site_priority_penalty(site, policy) +
  (if lot.storage == Ambient { 0 } else { 5 })
}

///|
pub fn allocation_is_feasible(
  lot : FoodLot,
  demand : DemandLine,
  site : DistributionSite,
  on : Day,
  policy : PolicyProfile,
) -> Bool {
  lot.is_usable_on(on) &&
  !lot.expires_on.is_before(demand.delivery_day) &&
  compatible_category(lot, demand, policy) &&
  site.accepts(lot) &&
  !site.capacity_for(lot.storage).is_zero()
}

///|
pub fn choose_reason(
  lot : FoodLot,
  demand : DemandLine,
  site : DistributionSite,
  on : Day,
  policy : PolicyProfile,
) -> AllocationReason {
  if lot.urgency(on, policy.critical_days, policy.soon_days) == Critical {
    EarliestExpiry
  } else if site.priority >= policy.max_site_priority {
    HighPrioritySite
  } else if demand.minimum.grams > 0 {
    MinimumCoverage
  } else {
    compatibility_reason(lot, demand)
  }
}
