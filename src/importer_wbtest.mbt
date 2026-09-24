///|
test "integer importer accepts signed whole numbers" {
  assert_eq(import_int("42").unwrap(), 42)
  assert_eq(import_int("-7").unwrap(), -7)
  assert_eq(import_int("+9").unwrap(), 9)
}

///|
test "integer importer rejects mixed text" {
  match import_int("12kg") {
    Ok(_) => assert_true(false)
    Err(message) => assert_true(message.contains("non-digit"))
  }
}

///|
test "lot importer returns valid values and row diagnostics" {
  let result = import_lots(
    "id,category,storage,received_day,expires_day,grams,state,reference,notes\nvalid,produce,ambient,0,3,400,available,fixture,ok\nbad,unknown,ambient,0,3,400,available,fixture,bad\n",
  ).unwrap()
  assert_eq(result.values.length(), 1)
  assert_eq(result.values[0].id, "valid")
  assert_eq(result.diagnostics.length(), 1)
  assert_eq(result.diagnostics[0].row, 3)
}

///|
test "site importer parses capacity and capability" {
  let result = import_sites(
    "id,name,priority,ambient_grams,chilled_grams,frozen_grams,accepts_prepared_meals\nnorth,North,5,1000,2000,0,true\n",
  ).unwrap()
  assert_eq(result.values.length(), 1)
  assert_eq(result.values[0].chilled_capacity.grams, 2000)
  assert_true(result.values[0].accepts_prepared_meals)
}

///|
test "demand importer records malformed priorities" {
  let result = import_demands(
    "id,site_id,category,requested_grams,minimum_grams,delivery_day,priority\nd1,north,produce,1000,500,1,urgent\n",
  ).unwrap()
  assert_eq(result.values.length(), 0)
  assert_eq(result.diagnostics.length(), 1)
  assert_eq(result.diagnostics[0].field, "priority")
}
