test "CSV parser trims fixture cells and preserves rows" {
  let table = match parse_csv("id, quantity\n apple , 42 \n") {
    Ok(value) => value
    Err(message) => panic(message)
  }
  assert_eq(table.header[0], "id")
  assert_eq(table.rows.length(), 1)
  assert_eq(csv_cell(table, table.rows[0], "quantity"), "42")
}

test "CSV parser rejects malformed rows" {
  match parse_csv("id,quantity\napple\n") {
    Ok(_) => panic("expected malformed row to fail")
    Err(message) => assert_true(message.contains("different field count"))
  }
}

test "CSV parser exposes missing columns" {
  let table = match parse_csv("id\napple\n") {
    Ok(value) => value
    Err(message) => panic(message)
  }
  match csv_require_columns(table, ["id", "quantity"]) {
    Ok(_) => panic("expected missing column error")
    Err(message) => assert_true(message.contains("quantity"))
  }
}
