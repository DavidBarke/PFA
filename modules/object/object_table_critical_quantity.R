object_table_critical_quantity_ui <- function(id, object_id, quantity) {
  ns <- shiny::NS(id)

  as.character(
    shiny::actionLink(
      inputId = ns("quantity") %_% object_id,
      label = htmltools::div(
        id = ns("label-container"),
        htmltools::div(
          id = ns("label"),
          quantity
        )
      ),
      class = "primary",
      onclick = glue::glue(
        'Shiny.setInputValue(\"{inputId}\", {{
          object_id: {object_id},
          nonce: Math.random()
        }});',
        inputId = ns("quantity"),
        object_id = object_id
      )
    )
  )
}

object_table_critical_quantity_server <- function(id,
                                                  .values,
                                                  settings,
                                                  db,
                                                  label
) {
  required <- list(
    settings = "update_name",
    db = "func",
    func = c(
      "get_object_quantity",
      "set_object_quantity"
    ),
    label = c(
      "change_critical_quantity",
      "new_critical_quantity",
      "object_critical_quantity_with_article"
    )
  )

  check_required(
    required,
    settings,
    db,
    db$func,
    label
  )

  shiny::moduleServer(
    id,
    function(input, output, session) {

      ns <- session$ns

      object_id_r <- shiny::reactive({
        input$quantity$object_id
      })

      old_quantity_r <- shiny::reactive({
        purrr::walk(settings$update_name, function(update_name) {
          .values$update[[update_name]]()
        })

        db$func$get_object_quantity(.values$db, object_id_r())
      })

      shiny::observeEvent(input$quantity, {
        shiny::showModal(shiny::modalDialog(
          title = htmltools::tagList(
            .values$i18n$t(label$change_critical_quantity),
            shiny::modalButton(
              label = NULL,
              icon = shiny::icon("window-close")
            )
          ),
          easyClose = TRUE,
          object_quantity_input_ui(
            id = ns("object_quantity_input"),
            old_quantity = old_quantity_r(),
            label = .values$i18n$t(label$new_critical_quantity)
          ),
          footer = shiny::uiOutput(
            outputId = ns("confirm_object_quantity")
          )
        ))
      })

      output$confirm_object_quantity <- shiny::renderUI({
        if (quantity_return$error_r()) {
          shinyjs::disabled(
            shiny::actionButton(
              inputId = ns("confirm_object_quantity"),
              label = .values$i18n$t("confirm")
            )
          )
        } else {
          shiny::actionButton(
            inputId = ns("confirm_object_quantity"),
            label = .values$i18n$t("confirm")
          )
        }
      })

      shiny::observeEvent(input$confirm_object_quantity, {
        shiny::removeModal()

        success <- db$func$set_object_quantity(
          .values$db,
          object_id_r(),
          quantity_return$quantity_r()
        )

        if (success) {
          shiny::showNotification(
            ui = .values$i18n$t(
              "msg_obj_changed_to",
              label$object_critical_quantity_with_article,
              quantity_return$quantity_r()
            ),
            type = "warning",
            duration = 5
          )

          amount <- quantity_return$quantity_r() - old_quantity_r()

          db_add_circulation(
            db = .values$db,
            user_id = .values$user$id(),
            subtype_id = object_id_r(),
            quantity = amount,
            op_type = 2
          )

          .values$update$circulation(.values$update$circulation() + 1)
        } else {
          shiny::showNotification(
            ui = .values$i18n$t(
              "err_obj_could_not_be_changed",
              label$object_critical_quantity_with_article
            ),
            type = "error",
            duration = 5
          )
        }

        purrr::walk(settings$update_name, function(update_name) {
          .values$update[[update_name]](
            .values$update[[update_name]]() + 1
          )
        })
      })

      min_r <- shiny::reactive({
        .values$update$circulation()
        .values$update$subtype()
        db_get_borrowed_quantity(.values$db, object_id_r())
      })

      quantity_return <- object_quantity_input_server(
        id = "object_quantity_input",
        .values = .values,
        min_r = shiny::reactive(0),
        min_message_r = shiny::reactive({
          "err_min_critical_quantity"
        })
      )
    }
  )
}
