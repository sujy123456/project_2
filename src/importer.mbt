/// Typed import adapters for PantryFlow's deliberately small CSV dialect.
/// Inputs become allocation records only after each row is parsed and checked.

pub enum ImportKind {
  Lots
  Sites
  Demands
} derive(Eq, Show)

pub struct ImportDiagnostic {
  kind : ImportKind
  row : Int
  field : String
  message : String
} derive(Show)

pub struct ImportResult[T] {
  values : Array[T]
  diagnostics : Array[ImportDiagnostic]
} derive(Show)

pub fn import_int(text : String) -> Result[Int, String] {
  if text.length() == 0 { return Err("integer is empty") }
  let mut offset = 0
  let mut negative = false
  if text.unsafe_get(0).to_int() == 45 { negative = true; offset = 1 }
  if text.unsafe_get(0).to_int() == 43 { offset = 1 }
  if offset == text.length() { return Err("integer has no digits") }
  let mut value = 0
  while offset < text.length() {
    let code = text.unsafe_get(offset).to_int()
    if code < 48 || code > 57 { return Err("integer contains a non-digit") }
    value = value * 10 + code - 48
    offset = offset + 1
  }
  Ok(if negative { -value } else { value })
}

pub fn import_category(text : String) -> Result[FoodCategory, String] {
  match text {
    "produce" => Ok(Produce)
    "bakery" => Ok(Bakery)
    "dairy" => Ok(Dairy)
    "protein" => Ok(Protein)
    "prepared_meal" => Ok(PreparedMeal)
    "shelf_stable" => Ok(ShelfStable)
    "infant_nutrition" => Ok(InfantNutrition)
    _ => Err("unknown food category: " + text)
  }
}

pub fn import_storage(text : String) -> Result[StorageZone, String] {
  match text {
    "ambient" => Ok(Ambient)
    "chilled" => Ok(Chilled)
    "frozen" => Ok(Frozen)
    _ => Err("unknown storage zone: " + text)
  }
}

pub fn import_state(text : String) -> Result[LotState, String] {
  match text {
    "available" => Ok(Available)
    "reserved" => Ok(Reserved)
    "allocated" => Ok(Allocated)
    "expired" => Ok(Expired)
    "blocked" => Ok(Blocked)
    _ => Err("unknown lot state: " + text)
  }
}

pub fn import_bool(text : String) -> Result[Bool, String] {
  match text {
    "true" => Ok(true)
    "false" => Ok(false)
    _ => Err("expected true or false")
  }
}

fn issue(kind : ImportKind, row : Int, field : String, message : String) -> ImportDiagnostic {
  { kind, row, field, message }
}

fn lot_from_row(table : CsvTable, row : Array[String]) -> Result[FoodLot, ImportDiagnostic] {
  let category = match import_category(csv_cell(table, row, "category")) {
    Ok(value) => value
    Err(message) => return Err(issue(Lots, 0, "category", message))
  }
  let storage = match import_storage(csv_cell(table, row, "storage")) {
    Ok(value) => value
    Err(message) => return Err(issue(Lots, 0, "storage", message))
  }
  let received = match import_int(csv_cell(table, row, "received_day")) {
    Ok(value) => value
    Err(message) => return Err(issue(Lots, 0, "received_day", message))
  }
  let expires = match import_int(csv_cell(table, row, "expires_day")) {
    Ok(value) => value
    Err(message) => return Err(issue(Lots, 0, "expires_day", message))
  }
  let grams = match import_int(csv_cell(table, row, "grams")) {
    Ok(value) => value
    Err(message) => return Err(issue(Lots, 0, "grams", message))
  }
  let state = match import_state(csv_cell(table, row, "state")) {
    Ok(value) => value
    Err(message) => return Err(issue(Lots, 0, "state", message))
  }
  Ok({
    id: csv_cell(table, row, "id"), category, storage,
    received_on: Day::new(received), expires_on: Day::new(expires),
    quantity: Quantity::from_grams(grams), state,
    donor_reference: csv_cell(table, row, "reference"), notes: csv_cell(table, row, "notes"),
  })
}

pub fn import_lots(text : String) -> Result[ImportResult[FoodLot], String] {
  let table = match parse_csv(text) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match csv_require_columns(table, ["id", "category", "storage", "received_day", "expires_day", "grams", "state", "reference", "notes"]) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let values = []
  let diagnostics = []
  let mut index = 0
  while index < table.rows.length() {
    match lot_from_row(table, table.rows[index]) {
      Ok(value) => values.push(value)
      Err(problem) => diagnostics.push({ ..problem, row: index + 2 })
    }
    index = index + 1
  }
  Ok({ values, diagnostics })
}

fn site_from_row(table : CsvTable, row : Array[String]) -> Result[DistributionSite, ImportDiagnostic] {
  let priority = match import_int(csv_cell(table, row, "priority")) {
    Ok(value) => value
    Err(message) => return Err(issue(Sites, 0, "priority", message))
  }
  let ambient = match import_int(csv_cell(table, row, "ambient_grams")) {
    Ok(value) => value
    Err(message) => return Err(issue(Sites, 0, "ambient_grams", message))
  }
  let chilled = match import_int(csv_cell(table, row, "chilled_grams")) {
    Ok(value) => value
    Err(message) => return Err(issue(Sites, 0, "chilled_grams", message))
  }
  let frozen = match import_int(csv_cell(table, row, "frozen_grams")) {
    Ok(value) => value
    Err(message) => return Err(issue(Sites, 0, "frozen_grams", message))
  }
  let prepared = match import_bool(csv_cell(table, row, "accepts_prepared_meals")) {
    Ok(value) => value
    Err(message) => return Err(issue(Sites, 0, "accepts_prepared_meals", message))
  }
  Ok({ id: csv_cell(table, row, "id"), name: csv_cell(table, row, "name"), priority, ambient_capacity: Quantity::from_grams(ambient), chilled_capacity: Quantity::from_grams(chilled), frozen_capacity: Quantity::from_grams(frozen), accepts_prepared_meals: prepared })
}

pub fn import_sites(text : String) -> Result[ImportResult[DistributionSite], String] {
  let table = match parse_csv(text) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match csv_require_columns(table, ["id", "name", "priority", "ambient_grams", "chilled_grams", "frozen_grams", "accepts_prepared_meals"]) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let values = []
  let diagnostics = []
  let mut index = 0
  while index < table.rows.length() {
    match site_from_row(table, table.rows[index]) {
      Ok(value) => values.push(value)
      Err(problem) => diagnostics.push({ ..problem, row: index + 2 })
    }
    index = index + 1
  }
  Ok({ values, diagnostics })
}

fn demand_from_row(table : CsvTable, row : Array[String]) -> Result[DemandLine, ImportDiagnostic] {
  let category = match import_category(csv_cell(table, row, "category")) {
    Ok(value) => value
    Err(message) => return Err(issue(Demands, 0, "category", message))
  }
  let requested = match import_int(csv_cell(table, row, "requested_grams")) {
    Ok(value) => value
    Err(message) => return Err(issue(Demands, 0, "requested_grams", message))
  }
  let minimum = match import_int(csv_cell(table, row, "minimum_grams")) {
    Ok(value) => value
    Err(message) => return Err(issue(Demands, 0, "minimum_grams", message))
  }
  let delivery = match import_int(csv_cell(table, row, "delivery_day")) {
    Ok(value) => value
    Err(message) => return Err(issue(Demands, 0, "delivery_day", message))
  }
  let priority = match import_int(csv_cell(table, row, "priority")) {
    Ok(value) => value
    Err(message) => return Err(issue(Demands, 0, "priority", message))
  }
  Ok({ id: csv_cell(table, row, "id"), site_id: csv_cell(table, row, "site_id"), category, requested: Quantity::from_grams(requested), minimum: Quantity::from_grams(minimum), delivery_day: Day::new(delivery), priority })
}

pub fn import_demands(text : String) -> Result[ImportResult[DemandLine], String] {
  let table = match parse_csv(text) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match csv_require_columns(table, ["id", "site_id", "category", "requested_grams", "minimum_grams", "delivery_day", "priority"]) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let values = []
  let diagnostics = []
  let mut index = 0
  while index < table.rows.length() {
    match demand_from_row(table, table.rows[index]) {
      Ok(value) => values.push(value)
      Err(problem) => diagnostics.push({ ..problem, row: index + 2 })
    }
    index = index + 1
  }
  Ok({ values, diagnostics })
}