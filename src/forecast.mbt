///|
/// Short-horizon inventory forecast.  This is a deterministic planning aid,
/// not a food-safety or demand prediction system.  It summarizes known stock
/// and known aggregate demand by category and day.
pub struct CategoryForecast {
  category : FoodCategory
  available_grams : Int
  expiring_grams : Int
  requested_grams : Int
  minimum_grams : Int
  projected_shortfall_grams : Int
} derive(Show)

///|
pub struct HorizonForecast {
  start : Day
  end : Day
  categories : Array[CategoryForecast]
  total_available_grams : Int
  total_requested_grams : Int
  total_shortfall_grams : Int
} derive(Show)

///|
pub fn forecast_categories() -> Array[FoodCategory] {
  [Produce, Bakery, Dairy, Protein, PreparedMeal, ShelfStable, InfantNutrition]
}

///|
fn forecast_in_horizon(day : Day, start : Day, end : Day) -> Bool {
  !day.is_before(start) && !day.is_after(end)
}

///|
fn forecast_available(
  lots : Array[FoodLot],
  category : FoodCategory,
  start : Day,
) -> Int {
  let mut total = 0
  let mut index = 0
  while index < lots.length() {
    let lot = lots[index]
    if lot.category == category && lot.is_usable_on(start) {
      total = total + lot.quantity.grams
    }
    index = index + 1
  }
  total
}

///|
fn forecast_expiring(
  lots : Array[FoodLot],
  category : FoodCategory,
  start : Day,
  end : Day,
) -> Int {
  let mut total = 0
  let mut index = 0
  while index < lots.length() {
    let lot = lots[index]
    if lot.category == category &&
      lot.is_usable_on(start) &&
      forecast_in_horizon(lot.expires_on, start, end) {
      total = total + lot.quantity.grams
    }
    index = index + 1
  }
  total
}

///|
fn forecast_requested(
  demands : Array[DemandLine],
  category : FoodCategory,
  start : Day,
  end : Day,
) -> Int {
  let mut total = 0
  let mut index = 0
  while index < demands.length() {
    let demand = demands[index]
    if demand.category == category &&
      forecast_in_horizon(demand.delivery_day, start, end) {
      total = total + demand.requested.grams
    }
    index = index + 1
  }
  total
}

///|
fn forecast_minimum(
  demands : Array[DemandLine],
  category : FoodCategory,
  start : Day,
  end : Day,
) -> Int {
  let mut total = 0
  let mut index = 0
  while index < demands.length() {
    let demand = demands[index]
    if demand.category == category &&
      forecast_in_horizon(demand.delivery_day, start, end) {
      total = total + demand.minimum.grams
    }
    index = index + 1
  }
  total
}

///|
pub fn forecast_category(
  lots : Array[FoodLot],
  demands : Array[DemandLine],
  category : FoodCategory,
  start : Day,
  end : Day,
) -> CategoryForecast {
  let available = forecast_available(lots, category, start)
  let requested = forecast_requested(demands, category, start, end)
  {
    category,
    available_grams: available,
    expiring_grams: forecast_expiring(lots, category, start, end),
    requested_grams: requested,
    minimum_grams: forecast_minimum(demands, category, start, end),
    projected_shortfall_grams: if requested > available {
      requested - available
    } else {
      0
    },
  }
}

///|
pub fn forecast_horizon(
  lots : Array[FoodLot],
  demands : Array[DemandLine],
  start : Day,
  days : Int,
) -> HorizonForecast {
  let safe_days = if days < 0 { 0 } else { days }
  let end = start.add(safe_days)
  let categories = []
  let all_categories = forecast_categories()
  let mut total_available = 0
  let mut total_requested = 0
  let mut total_shortfall = 0
  let mut index = 0
  while index < all_categories.length() {
    let entry = forecast_category(
      lots,
      demands,
      all_categories[index],
      start,
      end,
    )
    total_available = total_available + entry.available_grams
    total_requested = total_requested + entry.requested_grams
    total_shortfall = total_shortfall + entry.projected_shortfall_grams
    categories.push(entry)
    index = index + 1
  }
  {
    start,
    end,
    categories,
    total_available_grams: total_available,
    total_requested_grams: total_requested,
    total_shortfall_grams: total_shortfall,
  }
}

///|
pub fn forecast_find_category(
  forecast : HorizonForecast,
  category : FoodCategory,
) -> CategoryForecast? {
  let mut index = 0
  while index < forecast.categories.length() {
    if forecast.categories[index].category == category {
      return Some(forecast.categories[index])
    }
    index = index + 1
  }
  None
}

///|
pub fn forecast_risk_label(entry : CategoryForecast) -> String {
  if entry.projected_shortfall_grams > 0 {
    "shortfall"
  } else if entry.expiring_grams > entry.requested_grams {
    "expiry-pressure"
  } else if entry.minimum_grams > entry.available_grams {
    "minimum-risk"
  } else {
    "covered"
  }
}

///|
pub fn forecast_summary_lines(forecast : HorizonForecast) -> Array[String] {
  let lines = []
  let mut index = 0
  while index < forecast.categories.length() {
    let entry = forecast.categories[index]
    if entry.available_grams > 0 || entry.requested_grams > 0 {
      lines.push(
        category_name(entry.category) +
        ": " +
        forecast_risk_label(entry) +
        ", available=" +
        entry.available_grams.to_string() +
        "g, requested=" +
        entry.requested_grams.to_string() +
        "g",
      )
    }
    index = index + 1
  }
  lines
}
