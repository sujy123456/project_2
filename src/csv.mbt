/// Minimal deterministic CSV reader for PantryFlow fixtures.
/// It accepts UTF-8, comma-separated, unquoted rows and intentionally rejects
/// quoted fields so callers never mistake partial parsing for complete CSV.

pub struct CsvTable {
  header : Array[String]
  rows : Array[Array[String]]
} derive(Show)

pub fn csv_trim(value : String) -> String {
  value.trim().to_string()
}

pub fn csv_split_line(line : String) -> Array[String] {
  line.split(",").map(fn (cell) { csv_trim(cell.to_string()) }).collect()
}

pub fn csv_is_blank(line : String) -> Bool {
  line.trim() == ""
}

pub fn csv_has_quote(line : String) -> Bool {
  line.contains("\"")
}

pub fn parse_csv(text : String) -> Result[CsvTable, String] {
  let lines : Array[String] = text.split("\n").map(fn (line) { line.to_string() }).collect()
  if lines.length() == 0 || csv_is_blank(lines[0]) {
    return Err("CSV must contain a header row")
  }
  if csv_has_quote(lines[0]) {
    return Err("quoted CSV fields are not supported")
  }
  let header = csv_split_line(lines[0])
  let rows : Array[Array[String]] = []
  let mut index = 1
  while index < lines.length() {
    let row = lines[index]
    if !csv_is_blank(row) {
      if csv_has_quote(row) {
        return Err("quoted CSV fields are not supported")
      }
      let values = csv_split_line(row)
      if values.length() != header.length() {
        return Err("CSV row " + index.to_string() + " has a different field count")
      }
      rows.push(values)
    }
    index = index + 1
  }
  Ok({ header, rows })
}

pub fn csv_column_index(header : Array[String], name : String) -> Int {
  let mut index = 0
  while index < header.length() {
    if header[index] == name { return index }
    index = index + 1
  }
  -1
}

pub fn csv_require_columns(table : CsvTable, names : Array[String]) -> Result[Unit, String] {
  let mut index = 0
  while index < names.length() {
    if csv_column_index(table.header, names[index]) < 0 {
      return Err("missing required CSV column: " + names[index])
    }
    index = index + 1
  }
  Ok(())
}

pub fn csv_cell(table : CsvTable, row : Array[String], name : String) -> String {
  let index = csv_column_index(table.header, name)
  if index < 0 { "" } else { row[index] }
}
