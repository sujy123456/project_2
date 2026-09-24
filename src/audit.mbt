///|
/// Independent plan audit rules.  The planner is intentionally not trusted as
/// the only line of defence: a caller can persist or edit allocations, so the
/// audit can be run before export or hand-off.
pub enum AuditCode {
  UnknownLot
  UnknownDemand
  UnknownSite
  CategoryMismatch
  StorageCapacityExceeded
  LotQuantityExceeded
  DemandQuantityExceeded
  DeliveryAfterExpiry
  SiteMismatch
  PreparedMealRejected
  NegativeAllocation
  DuplicateAllocation
} derive(Eq, Show)

///|
pub struct AuditFinding {
  code : AuditCode
  allocation_id : String
  message : String
} derive(Show)

///|
pub struct AuditReport {
  findings : Array[AuditFinding]
  checked_allocations : Int
  accepted_allocations : Int
} derive(Show)

///|
fn audit_finding(
  code : AuditCode,
  allocation_id : String,
  message : String,
) -> AuditFinding {
  { code, allocation_id, message, }
}

///|
fn audit_lot(lots : Array[FoodLot], id : String) -> FoodLot? {
  let mut index = 0
  while index < lots.length() {
    if lots[index].id == id {
      return Some(lots[index])
    }
    index = index + 1
  }
  None
}

///|
fn audit_demand(demands : Array[DemandLine], id : String) -> DemandLine? {
  let mut index = 0
  while index < demands.length() {
    if demands[index].id == id {
      return Some(demands[index])
    }
    index = index + 1
  }
  None
}

///|
fn audit_site(
  sites : Array[DistributionSite],
  id : String,
) -> DistributionSite? {
  let mut index = 0
  while index < sites.length() {
    if sites[index].id == id {
      return Some(sites[index])
    }
    index = index + 1
  }
  None
}

///|
fn allocation_total_for_lot(
  allocations : Array[Allocation],
  lot_id : String,
) -> Int {
  let mut total = 0
  let mut index = 0
  while index < allocations.length() {
    if allocations[index].lot_id == lot_id {
      total = total + allocations[index].quantity.grams
    }
    index = index + 1
  }
  total
}

///|
fn allocation_total_for_demand(
  allocations : Array[Allocation],
  demand_id : String,
) -> Int {
  let mut total = 0
  let mut index = 0
  while index < allocations.length() {
    if allocations[index].demand_id == demand_id {
      total = total + allocations[index].quantity.grams
    }
    index = index + 1
  }
  total
}

///|
fn allocation_total_for_site_zone(
  allocations : Array[Allocation],
  lots : Array[FoodLot],
  site_id : String,
  zone : StorageZone,
) -> Int {
  let mut total = 0
  let mut index = 0
  while index < allocations.length() {
    let allocation = allocations[index]
    if allocation.site_id == site_id {
      match audit_lot(lots, allocation.lot_id) {
        Some(lot) =>
          if lot.storage == zone {
            total = total + allocation.quantity.grams
          }
        None => ()
      }
    }
    index = index + 1
  }
  total
}

///|
fn is_duplicate_id(
  allocations : Array[Allocation],
  allocation_id : String,
) -> Bool {
  let mut count = 0
  let mut index = 0
  while index < allocations.length() {
    if allocations[index].id == allocation_id {
      count = count + 1
    }
    index = index + 1
  }
  count > 1
}

///|
fn audit_relationship(
  allocation : Allocation,
  lot : FoodLot,
  demand : DemandLine,
  site : DistributionSite,
) -> Array[AuditFinding] {
  let findings = []
  if lot.category != demand.category {
    findings.push(
      audit_finding(
        CategoryMismatch,
        allocation.id,
        "lot category does not match demand category",
      ),
    )
  }
  if allocation.site_id != demand.site_id {
    findings.push(
      audit_finding(
        SiteMismatch,
        allocation.id,
        "allocation site does not match demand site",
      ),
    )
  }
  if allocation.planned_for.is_after(lot.expires_on) {
    findings.push(
      audit_finding(
        DeliveryAfterExpiry,
        allocation.id,
        "delivery is scheduled after lot expiry",
      ),
    )
  }
  if !site.accepts(lot) {
    findings.push(
      audit_finding(
        PreparedMealRejected,
        allocation.id,
        "site does not accept this prepared meal lot",
      ),
    )
  }
  findings
}

///|
fn audit_totals(
  allocation : Allocation,
  plan : AllocationPlan,
  lots : Array[FoodLot],
  demand : DemandLine,
  site : DistributionSite,
  lot : FoodLot,
) -> Array[AuditFinding] {
  let findings = []
  let lot_total = allocation_total_for_lot(plan.allocations, allocation.lot_id)
  if lot_total > lot.quantity.grams {
    findings.push(
      audit_finding(
        LotQuantityExceeded,
        allocation.id,
        "total allocations exceed available lot quantity",
      ),
    )
  }
  let demand_total = allocation_total_for_demand(
    plan.allocations,
    allocation.demand_id,
  )
  if demand_total > demand.requested.grams {
    findings.push(
      audit_finding(
        DemandQuantityExceeded,
        allocation.id,
        "total allocations exceed requested demand",
      ),
    )
  }
  let zone_total = allocation_total_for_site_zone(
    plan.allocations,
    lots,
    site.id,
    lot.storage,
  )
  if zone_total > site.capacity_for(lot.storage).grams {
    findings.push(
      audit_finding(
        StorageCapacityExceeded,
        allocation.id,
        "site storage capacity is exceeded",
      ),
    )
  }
  findings
}

///|
pub fn audit_plan(
  plan : AllocationPlan,
  lots : Array[FoodLot],
  sites : Array[DistributionSite],
  demands : Array[DemandLine],
) -> AuditReport {
  let findings = []
  let mut accepted = 0
  let mut index = 0
  while index < plan.allocations.length() {
    let allocation = plan.allocations[index]
    if allocation.quantity.grams <= 0 {
      findings.push(
        audit_finding(
          NegativeAllocation,
          allocation.id,
          "allocation quantity must be positive",
        ),
      )
    }
    if is_duplicate_id(plan.allocations, allocation.id) {
      findings.push(
        audit_finding(
          DuplicateAllocation,
          allocation.id,
          "allocation id must be unique",
        ),
      )
    }
    match
      (
        audit_lot(lots, allocation.lot_id),
        audit_demand(demands, allocation.demand_id),
        audit_site(sites, allocation.site_id),
      ) {
      (None, _, _) =>
        findings.push(
          audit_finding(UnknownLot, allocation.id, "lot was not found"),
        )
      (_, None, _) =>
        findings.push(
          audit_finding(UnknownDemand, allocation.id, "demand was not found"),
        )
      (_, _, None) =>
        findings.push(
          audit_finding(UnknownSite, allocation.id, "site was not found"),
        )
      (Some(lot), Some(demand), Some(site)) => {
        let relation = audit_relationship(allocation, lot, demand, site)
        let totals = audit_totals(allocation, plan, lots, demand, site, lot)
        let mut local_index = 0
        while local_index < relation.length() {
          findings.push(relation[local_index])
          local_index = local_index + 1
        }
        local_index = 0
        while local_index < totals.length() {
          findings.push(totals[local_index])
          local_index = local_index + 1
        }
        if relation.length() == 0 &&
          totals.length() == 0 &&
          allocation.quantity.grams > 0 {
          accepted = accepted + 1
        }
      }
    }
    index = index + 1
  }
  {
    findings,
    checked_allocations: plan.allocations.length(),
    accepted_allocations: accepted,
  }
}

///|
pub fn audit_is_clean(report : AuditReport) -> Bool {
  report.findings.length() == 0
}
