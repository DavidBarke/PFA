library(shiny)
library(shinyjs)
library(dplyr)
# library needs to be called, otherwise qrcode generation does not work
library(qrcode)
library(shiny.i18n)

# app.yml stores settings that may differ between execution environments
app_yml <- "./app.yml"
if (!file.exists(app_yml)) {
    x <- list(
        # In showcase mode passwords for default users are shown. Furthermore
        # default users may neither be modified nor removed
        showcase = TRUE,
        url = "http://127.0.0.1:1234"
    )

    yaml::write_yaml(x, app_yml)
}

if (!dir.exists("files")) {
    dir.create("files")
    dir.create("files/group")
    dir.create("files/type")
    dir.create("files/subtype")
}

addResourcePath("files", "./files")
options(shiny.port = 1234)

ui_server <- function(source_to_globalenv = FALSE) {
    # If source_to_global_env all sourced functions get added to the global
    # environment which takes some time after the app has stopped

    source("init/source_directory.R")

    source_directory(
        # chdir makes it possible to use relative paths in source statements inside
        # these sourced files (for example DataStorage2.R)
        path = "modules",
        encoding = "UTF-8",
        modifiedOnly = FALSE,
        chdir = TRUE,
        recursive = TRUE,
        envir = if (source_to_globalenv) globalenv() else environment()
    )

    source_directory(
        path = "db/func",
        encoding = "UTF-8",
        modifiedOnly = FALSE,
        chdir = TRUE,
        recursive = TRUE,
        envir = if (source_to_globalenv) globalenv() else environment()
    )

    # Globals ------------------------------------------------------------------

    # Translator
    i18n <- shiny.i18n::Translator$new(
        translation_json_path = "translation/translation.json"
    )
    i18n$set_language("de")

    # Allow bigger file inputs
    options(shiny.maxRequestSize = 100*1024^2)

    # UI -----------------------------------------------------------------------
    ui <- htmltools::tagList(
        # Enable shiny.18n
        shiny.i18n::usei18n(i18n),
        waiter::use_waiter(),
        waiter::waiter_show_on_load(
            html = waiter::spin_solar()
        ),
        tags$head(
            # Include custom scripts
            htmltools::includeScript("www/js/dark-mode.js"),
            htmltools::includeScript("www/js/fileInputText.js"),
            htmltools::includeScript("www/js/language-selector.js"),
            # Include custom css styles
            htmltools::includeCSS("www/css/styles.css"),
            htmltools::includeCSS("www/css/dt-dark.css"),
            htmltools::tags$script(
                src="https://cdn.jsdelivr.net/npm/js-cookie@rc/dist/js.cookie.min.js"
            )
        ),
        # ui_ui generates the UI which is displayed in the content_list,
        # viewer_data and viewer_plot
        container_ui(
            id = "container"
        ),
        # Enable shinybrowser
        shinybrowser::detect(),
        # Enable rclipboard
        rclipboard::rclipboardSetup(),
        # Enable shinyjs
        shinyjs::useShinyjs(),
        # Extend shinyjs with custom JavaScript
        shinyjs::extendShinyjs(
            "js/cookies.js",
            functions = c("getCookie", "setCookie", "rmCookie")
        )
        #),
        # shinydisconnect::disconnectMessage(
        #     text = "Verbindung zum Server unterbrochen. Lade neu und versuche es erneut!",
        #     refresh = "Neu laden",
        #     background = "#343a40",
        #     colour = "white",
        #     top = "center"
        # )
    )

    # SERVER -------------------------------------------------------------------

    server <- function(input, output, session) {
        # .VALUES ENVIRONMENT ------------------------------------------------

        # The .values environment is available to all modules so that arbitrary information
        # can be shared via this environment. Elements that underly reactive changes can be
        # stored as reactiveValues or reactiveVal
        .values <- new.env()
        # Set a value to .values$trigger$<value> inside a module and listen to its
        # change in some other module with observeEvent(.values$trigger$<value>, ...)
        .values$trigger <- shiny::reactiveValues()
        # Same purpose as above, but you must set the reactiveValues by yourself. This
        # is useful for modules that get reused multiple times and therefore can
        # store a trigger for each instance
        .values$trigger_list <- list()

        .values$i18n <- i18n$clone()

        .values$user$id <- shiny::reactiveVal(0L)
        .values$user$status <- shiny::reactiveVal("not_logged")
        .values$user$name <- shiny::reactiveVal("")
        .values$user$last_logged <- shiny::reactiveVal("2011-11-11 11:11:11")

        .values$settings$password$length <- list(min = 4, max = 32)
        .values$settings$user_name$length <- list(min = 4, max = 32)
        .values$settings$group_name$length <- list(min = 4, max = 32)
        .values$settings$type_name$length <- list(min = 4, max = 32)
        .values$settings$subtype_name$length <- list(min = 4, max = 32)

        .values$settings$status_dict <- list(
            admin = .values$i18n$t("admin"),
            mod = .values$i18n$t("mod"),
            user = .values$i18n$t("user")
        )

        .values$settings$status_dict_chr <- list(
            admin = .values$i18n$t_chr("admin"),
            mod = .values$i18n$t_chr("mod"),
            user = .values$i18n$t_chr("user")
        )

        .values$settings$time_unit_dict <- function() {
            list(
                secs = .values$i18n$t("secs"),
                mins = .values$i18n$t("mins"),
                hours = .values$i18n$t("hours"),
                days = .values$i18n$t("days"),
                weeks = .values$i18n$t("weeks")
            )
        }

        .values$settings$table_dict <- function() {
            .values$language_rv()
            list(
                "group" = .values$i18n$t_chr("group"),
                "type" = .values$i18n$t_chr("type"),
                "subtype" = .values$i18n$t_chr("subtype")
            )
        }

        # These reactiveVals should be written after the corresponding database
        # table has been updated. They should be read in all location where
        # the content of the corresponding table is retrieved
        .values$update$user <- shiny::reactiveVal(0)
        .values$update$group <- shiny::reactiveVal(0)
        .values$update$type <- shiny::reactiveVal(0)
        .values$update$subtype <- shiny::reactiveVal(0)
        .values$update$group_type <- shiny::reactiveVal(0)
        .values$update$files <- shiny::reactiveVal(0)
        .values$update$circulation <- shiny::reactiveVal(0)

        # Query string's type parameter
        .values$query$type <- shiny::reactiveVal(NULL)

        # Store reference to this session
        .values$app_session <- session

        # Detect if mobile device or not
        shiny::observe(.values$device$large <- shinybrowser::get_width() > 768)

        # Internationalization
        .values$language_rv <- shiny::reactiveVal("de")

        # Language for DT::datatable
        dt_languages <- list(
            de = "//cdn.datatables.net/plug-ins/1.10.24/i18n/de_de.json",
            en = "//cdn.datatables.net/plug-ins/1.10.24/i18n/en-gb.json",
            es = "//cdn.datatables.net/plug-ins/1.10.24/i18n/es_es.json",
            fr = "//cdn.datatables.net/plug-ins/1.10.24/i18n/fr_fr.json"
        )

        .values$dt_language_r <- shiny::reactive({
            dt_languages[[.values$language_rv()]]
        })

        # Connect to db
        .values$db <- DBI::dbConnect(RSQLite::SQLite(), "./db/db.sqlite")
        # Enable foreign key support
        DBI::dbExecute(.values$db, "PRAGMA foreign_keys=ON")

        # Store app.yml contents
        .values$yaml <- yaml::read_yaml(app_yml)

        # Use regex
        # RSQLite::initRegExp(.values$db)

        # Call container module
        container_server(
            id = "container",
            .values = .values
        )

        # Hide waiter when initialisation is done
        waiter::waiter_hide()

        # Handle dark mode cookie
        shiny::observeEvent(TRUE, {
            js$getCookie(
                cookie = "dark-mode",
                id = "cookie_dark_mode"
            )
        }, once = TRUE)

        shiny::observeEvent(input$dark_mode, {
            js$setCookie(
                cookie = "dark-mode",
                value = input$dark_mode,
                id = "cookie_dark_mode"
            )
        })

        # Disconnect on session end
        session$onSessionEnded(function() {
            DBI::dbDisconnect(.values$db)
        })
    }

    return(list(ui = ui, server = server))
}

ui_server <- ui_server(source_to_globalenv = FALSE)

ui <- ui_server$ui
server <- ui_server$server

shinyApp(ui, server)
