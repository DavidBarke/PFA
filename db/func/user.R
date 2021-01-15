#' Add User to User Table
#'
#' Add a new user to the user table.
#'
#' @template db
#' @template xxx-name
#' @templateVar key user
#' @template user-status
#' @template user-password
#'
#' @family user
#'
#' @export
db_add_user <- function(db,
                        name,
                        status = c("admin", "mod", "user"),
                        password,
                        added_from = "Admin"
) {
  entry <- tibble::tibble(
    name = name,
    status = status,
    # Hashed password
    password = password,
    added_from = added_from,
    time_added = as.character(Sys.time()),
    time_logged = as.character(Sys.time()),
    times_logged = 0
  )

  DBI::dbAppendTable(db, "user", entry)
}



#' Get User Status
#'
#' @inheritParams db_add_user
#'
#' @family user
#'
#' @export
db_get_user_status <- function(db, name) {
  DBI::dbGetQuery(
    db,
    "SELECT status FROM user WHERE name = ?",
    params = list(name)
  )$status
}



#' Set User Status
#'
#' @inheritParams db_add_user
#'
#' @family user
#'
#' @export
db_set_user_status <- function(db, name, status) {
  current_status <- db_get_user_status(db, name)
  if (status != "admin" && current_status == "admin") {
    n_admins <- DBI::dbGetQuery(
      db,
      "SELECT COUNT(*) AS n_admins FROM user WHERE status = ?",
      params = list("admin")
    )$n_admins

    if (n_admins == 1) return(0)
  }

  DBI::dbExecute(
    db,
    "UPDATE user SET status = ? WHERE name = ?",
    params = list(status, name)
  )
}


#' Get User Names
#'
#' @template db
#'
#' @family user
#'
#' @export
db_get_user_names <- function(db) {
  DBI::dbGetQuery(db, "SELECT name FROM user")$name
}



#' Remove User from User Table
#'
#' @inheritParams db_add_user
#'
#' @family user
#'
#' @export
db_remove_user <- function(db, name) {
  status <- db_get_user_status(db, name)

  if (status == "admin") {
    n_admins <- DBI::dbGetQuery(
      db,
      "SELECT COUNT(*) AS n_admins FROM user WHERE status = ?",
      params = list("admin")
    )$n_admins

    if (n_admins == 1) return(0)
  }

  DBI::dbExecute(
    db,
    "DELETE FROM user WHERE name = ?",
    params = list(name)
  )
}



#' Get Hashed Password From User
#'
#' @inheritParams db_add_user
#'
#' @family user
#'
#' @export
db_get_password <- function(db, name) {
  pwd <- DBI::dbGetQuery(
    db,
    "SELECT password FROM user WHERE name = ?",
    params = list(name)
  )$password
}



#' Set Hashed Password
#'
#' @inheritParams db_add_user
#'
#' @family user
#'
#' @export
db_set_password <- function(db, name, password) {
  DBI::dbExecute(
    db,
    "UPDATE user SET password = ? WHERE name = ?",
    params = list(password, name)
  )
}



#' Check If User Table Has User Name
#'
#' @inheritParams db_add_user
#'
#' @family user
#'
#' @export
db_has_user_name <- function(db, name) {
  name %in% db_get_user_names(db)
}



#' Log User In
#'
#' @inheritParams db_add_user
#'
#' @family user
#'
#' @export
db_log_user_in <- function(db, name) {
  DBI::dbExecute(
    db,
    "UPDATE user SET time_logged = ? WHERE name = ?",
    params = list(as.character(Sys.time()), name)
  )

  times_logged <- db_get_user_times_logged(db, name)

  DBI::dbExecute(
    db,
    "UPDATE user SET times_logged = ? WHERE name = ?",
    params = list(times_logged + 1, name)
  )
}



#' Get Number of Times a User Logged In
#'
#' @inheritParams db_add_user
#'
#' @family user
#'
#' @export
db_get_user_times_logged <- function(db, name) {
  DBI::dbGetQuery(
    db,
    "SELECT times_logged FROM user WHERE name = ?",
    params = list(name)
  )$times_logged
}



#' Get Name of User Who Added User
#'
#' @inheritParams db_add_user
#'
#' @family user
#'
#' @export
db_get_adding_user <- function(db, name) {
  DBI::dbGetQuery(
    db,
    "SELECT added_from FROM user WHERE name = ?",
    params = list(name)
  )$added_from
}



#' Get Time When User Last Logged
#'
#' @inheritParams db_add_user
#'
#' @family user
#'
#' @export
db_get_user_last_logged <- function(db, name) {
  DBI::dbGetQuery(
    db,
    "SELECT time_logged FROM user WHERE name = ?",
    params = list(name)
  )$time_logged
}