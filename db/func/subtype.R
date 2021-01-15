#' Add Subtype to Subtype Table
#'
#' @template db
#' @template id
#' @templateVar key type
#' @param subtype_name Subtype name.
#' @template quantity
#'
#' @family subtype
#'
#' @export
db_add_subtype <- function(db, type_id, subtype_name, quantity) {
  entry <- tibble::tibble(
    type_id = type_id,
    subtype_name = subtype_name,
    quantity = quantity
  )

  DBI::dbAppendTable(db, "subtype", entry)
}



#' Set Subtype Name
#'
#' @inheritParams db_add_subtype
#' @template id
#' @templateVar key subtype
#'
#' @family subtype
#'
#' @export
db_set_subtype_name <- function(db, subtype_id, subtype_name) {
  DBI::dbExecute(
    db,
    "UPDATE subtype SET subtype_name = ? WHERE rowid = ?",
    params = list(subtype_name, subtype_id)
  )
}



#' Set Available Quantity of Subtype
#'
#' @template db
#' @template id
#' @templateVar key subtype
#' @template quantity
#'
#' @family subtype
#'
#' @export
db_set_subtype_quantity <- function(db, subtype_id, quantity) {
  DBI::dbExecute(
    db,
    "UPDATE subtype SET quantity = ? WHERE rowid = ?",
    params = list(quantity, subtype_id)
  )
}



#' Get Subtypes by Type ID
#'
#' @template db
#' @template id
#' @templateVar key type
#'
#' @family subtype
#'
#' @export
db_get_subtypes_by_type_id <- function(db, type_id) {
  tbl <- DBI::dbGetQuery(
    db,
    "SELECT rowid, subtype_name FROM subtype WHERE type_id = ?",
    params = list(type_id)
  )

  x <- tbl$rowid
  names(x) <- tbl$subtype_name

  x
}



db_get_subtypes <- function(db) {
  tbl <- DBI::dbGetQuery(
    db,
    "SELECT rowid, subtype_name FROM subtype"
  )

  x <- tbl$rowid
  names(x) <- tbl$subtype_name

  x
}



#' Get Subtype Table by Type ID
#'
#' @template db
#' @template id
#' @templateVar key type
#'
#' @family subtype
#'
#' @export
db_get_subtype_table_by_type_id <- function(db, type_id) {
  DBI::dbGetQuery(
    db,
    "SELECT rowid AS subtype_id, subtype_name, quantity FROM subtype WHERE type_id = ?",
    params = list(type_id)
  )
}



#' Remove Subtype
#'
#' @template
#' @template id
#' @templateVar key subtype
#'
#' @family subtype
#'
#' @export
db_remove_subtype <- function(db, subtype_id) {
  DBI::dbExecute(
    db,
    "DELETE FROM subtype WHERE rowid = ?",
    params = list(subtype_id)
  )
}




#' Remove Subtypes by Type Id
#'
#' @template db
#' @template id
#' @templateVar key type
#'
#' @family subtype
#'
#' @export
db_remove_subtypes_by_type_id <- function(db, type_id) {
  DBI::dbExecute(
    db,
    "DELETE FROM subtype WHERE type_id = ?",
    params = list(type_id)
  )
}