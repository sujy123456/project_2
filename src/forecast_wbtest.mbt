///|
test "forecast identifies known category shortfall" {
  let forecast = forecast_horizon(
    example_lots(),
    example_demands(),
    Day::new(0),
    2,
  )
  let produce = forecast_find_category(forecast, Produce).unwrap()
  assert_eq(produce.available_grams, 18000)
  assert_eq(produce.requested_grams, 12000)
  assert_eq(produce.projected_shortfall_grams, 0)
}

///|
test "forecast excludes demand outside the horizon" {
  let early = forecast_horizon(
    example_lots(),
    example_demands(),
    Day::new(0),
    1,
  )
  let shelf = forecast_find_category(early, ShelfStable).unwrap()
  assert_eq(shelf.requested_grams, 0)
}

///|
test "forecast marks a synthetic shortage" {
  let demand = [
    {
      id: "d",
      site_id: "north",
      category: Dairy,
      requested: Quantity::from_grams(99000),
      minimum: Quantity::from_grams(1000),
      delivery_day: Day::new(1),
      priority: 1,
    },
  ]
  let forecast = forecast_horizon(example_lots(), demand, Day::new(0), 1)
  let dairy = forecast_find_category(forecast, Dairy).unwrap()
  assert_true(dairy.projected_shortfall_grams > 0)
  assert_eq(forecast_risk_label(dairy), "shortfall")
}

///|
test "forecast summary omits empty categories" {
  let forecast = forecast_horizon([], [], Day::new(0), 3)
  assert_eq(forecast_summary_lines(forecast).length(), 0)
}
