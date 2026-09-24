///|
test "scenario comparison produces a recommendation" {
  let comparison = compare_scenarios(
    default_scenarios(),
    example_lots(),
    example_sites(),
    example_demands(),
    Day::new(0),
  )
  assert_eq(comparison.scores.length(), 3)
  assert_true(comparison.recommended_id.is_some())
}

///|
test "scenario comparison handles empty candidates" {
  let comparison = compare_scenarios(
    [],
    example_lots(),
    example_sites(),
    example_demands(),
    Day::new(0),
  )
  assert_true(comparison.recommended_id.is_none())
  assert_eq(comparison.scores.length(), 0)
}

///|
test "scenario scores can be found by identifier" {
  let comparison = compare_scenarios(
    [scenario_balanced()],
    example_lots(),
    example_sites(),
    example_demands(),
    Day::new(0),
  )
  let score = scenario_find_score(comparison, "balanced").unwrap()
  assert_true(score.allocated_grams > 0)
}
