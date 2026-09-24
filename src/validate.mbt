/// Validation keeps invalid planning input out of the allocator.  The checks are
/// deterministic so every report can explain why a record was skipped.

pub fn validate_lots(lots : Array[FoodLot], on : Day) -> Array[ValidationIssue] {
  let issues : Array[ValidationIssue] = []
  let mut i = 0
  while i < lots.length() {
    let lot = lots[i]
    if lot.id == "" {
      issues.push({ code: EmptyIdentifier, subject: "lot", message: "lot id must not be empty" })
    }
    if lot.quantity.grams <= 0 {
      issues.push({ code: NegativeQuantity, subject: lot.id, message: "lot quantity must be positive" })
    }
    if lot.expires_on.is_before(lot.received_on) {
      issues.push({ code: InvalidDate, subject: lot.id, message: "expiry cannot precede receipt" })
    }
    if lot.expires_on.is_before(on) {
      issues.push({ code: ExpiredLot, subject: lot.id, message: "lot is already expired on planning day" })
    }
    let mut j = i + 1
    while j < lots.length() {
      if lot.id != "" && lot.id == lots[j].id {
        issues.push({ code: DuplicateIdentifier, subject: lot.id, message: "lot id occurs more than once" })
      }
      j = j + 1
    }
    i = i + 1
  }
  issues
}

pub fn validate_sites(sites : Array[DistributionSite]) -> Array[ValidationIssue] {
  let issues : Array[ValidationIssue] = []
  let mut i = 0
  while i < sites.length() {
    let site = sites[i]
    if site.id == "" {
      issues.push({ code: EmptyIdentifier, subject: "site", message: "site id must not be empty" })
    }
    if site.priority < 0 {
      issues.push({ code: ImpossibleCapacity, subject: site.id, message: "site priority cannot be negative" })
    }
    if site.ambient_capacity.grams < 0 || site.chilled_capacity.grams < 0 || site.frozen_capacity.grams < 0 {
      issues.push({ code: ImpossibleCapacity, subject: site.id, message: "storage capacity cannot be negative" })
    }
    let mut j = i + 1
    while j < sites.length() {
      if site.id != "" && site.id == sites[j].id {
        issues.push({ code: DuplicateIdentifier, subject: site.id, message: "site id occurs more than once" })
      }
      j = j + 1
    }
    i = i + 1
  }
  issues
}

pub fn validate_demands(demands : Array[DemandLine], sites : Array[DistributionSite], on : Day) -> Array[ValidationIssue] {
  let issues : Array[ValidationIssue] = []
  let mut i = 0
  while i < demands.length() {
    let demand = demands[i]
    if demand.id == "" {
      issues.push({ code: EmptyIdentifier, subject: "demand", message: "demand id must not be empty" })
    }
    if not(demand.is_valid()) {
      issues.push({ code: NegativeQuantity, subject: demand.id, message: "requested must be at least minimum and non-negative" })
    }
    if demand.delivery_day.is_before(on) {
      issues.push({ code: InvalidDate, subject: demand.id, message: "delivery day cannot precede planning day" })
    }
    if find_site(sites, demand.site_id) is None {
      issues.push({ code: MissingDemand, subject: demand.id, message: "demand references an unknown site" })
    }
    let mut j = i + 1
    while j < demands.length() {
      if demand.id != "" && demand.id == demands[j].id {
        issues.push({ code: DuplicateIdentifier, subject: demand.id, message: "demand id occurs more than once" })
      }
      j = j + 1
    }
    i = i + 1
  }
  issues
}

pub fn find_site(sites : Array[DistributionSite], id : String) -> DistributionSite? {
  let mut i = 0
  while i < sites.length() {
    if sites[i].id == id {
      return Some(sites[i])
    }
    i = i + 1
  }
  None
}

pub fn has_error_for(issues : Array[ValidationIssue], subject : String) -> Bool {
  let mut i = 0
  while i < issues.length() {
    if issues[i].subject == subject {
      return true
    }
    i = i + 1
  }
  false
}

pub fn collect_validation_issues(
  lots : Array[FoodLot],
  sites : Array[DistributionSite],
  demands : Array[DemandLine],
  on : Day,
) -> Array[ValidationIssue] {
  let all : Array[ValidationIssue] = []
  let lot_issues = validate_lots(lots, on)
  let site_issues = validate_sites(sites)
  let demand_issues = validate_demands(demands, sites, on)
  let mut i = 0
  while i < lot_issues.length() {
    all.push(lot_issues[i])
    i = i + 1
  }
  let mut j = 0
  while j < site_issues.length() {
    all.push(site_issues[j])
    j = j + 1
  }
  let mut k = 0
  while k < demand_issues.length() {
    all.push(demand_issues[k])
    k = k + 1
  }
  all
}
