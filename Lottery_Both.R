
library(dplyr)
library(tibble)
library(markdown)
library(shiny)
library(shinyBS)
library(DT)

temp <- read.csv("./Entrants.csv", stringsAsFactors = FALSE) #LOAD THE DATA
df <- as_tibble(temp)

# CSV already has multipliers applied (Volunteer *4, MarkCourse *6, PriorFinishes *2)
# so tickets = 1 + sum of the pre-multiplied columns
df$tickets <- 1 + df$Volunteer + df$MarkCourse + df$PriorFinishes

n_pick      <- 86
n_wait_pick <- min(75, nrow(df) - n_pick)

# ODDS CALCULATION
applicants             <- pull((df %>% count(tickets))[,2], n)
tickets_per_applicant  <- sort(df$tickets[!duplicated(df$tickets)])
original_tickets       <- applicants * tickets_per_applicant
ticket_counts          <- original_tickets

for (i in 1:n_pick) {
  prob_of_selecting_category <- ticket_counts / sum(ticket_counts)
  exp_ticket_reduction       <- prob_of_selecting_category * tickets_per_applicant
  ticket_counts              <- ticket_counts - exp_ticket_reduction
}
tickets_taken      <- original_tickets - ticket_counts
odds_of_selection  <- tickets_taken / original_tickets
num_people_taken   <- odds_of_selection * applicants
odds_table         <- cbind(tickets_per_applicant, odds_of_selection, applicants, num_people_taken)

df <- as.data.frame(df)

shinyApp(
  ui <- fluidPage(
    htmltools::includeMarkdown("./markdown/headline.md"),
    bsCollapse(id = "collapse", multiple = TRUE,
               bsCollapsePanel("Lottery Design",
                               htmltools::includeMarkdown("./markdown/background.md"),
                               style = "info"
               ),
               bsCollapsePanel("How many tickets do I have?",
                               htmltools::includeMarkdown("./markdown/howmanytickets.md"),
                               fluidRow(
                                 column(4, sliderInput("volunteer",  label = h5("Volunteer Shifts (+4 each)"),      min = 0, max = 30, value = 0)),
                                 column(4, sliderInput("coursemark", label = h5("Course Marking Shifts (+6 each)"), min = 0, max = 10, value = 0)),
                                 column(4, sliderInput("finishes",   label = h5("Prior Finishes (+2 each)"),        min = 0, max = 10, value = 0)),
                               ),
                               "Your tickets in the lottery:", textOutput("tickets"),
                               style = "success"
               ),
               bsCollapsePanel("What are my odds?",
                               htmltools::includeMarkdown("./markdown/justtellmetheodds.md"),
                               "These are the odds for each ticket level:",
                               DT::dataTableOutput("oddsTable"),
                               style = "info"
               ),
               bsCollapsePanel("Set the Seed",
                               fluidRow(
                                 column(6, numericInput("num",  label = h1("Enter the seed"),   value = NA)),
                                 column(6, numericInput("num2", label = h1("Confirm the seed"), value = NA)),
                               ),
                               style = "success"
               ),
               bsCollapsePanel("Results: Winners",
                               "These are the entrants selected in the lottery:",
                               DT::dataTableOutput("valueWinners"),
                               downloadButton("downloadWinners", "Download Winners"),
                               style = "info"
               ),
               bsCollapsePanel("Results: Waitlist",
                               "These are the waitlisted entrants:",
                               dataTableOutput("valueWaitlist"),
                               downloadButton("downloadWaitlist", "Download Waitlist"),
                               style = "success"
               ),
               bsCollapsePanel("Alternative Algorithm: Results",
                               htmltools::includeMarkdown("./markdown/alternativealgorithm.md"),
                               bsCollapse(id = "collapseTickets", multiple = FALSE,
                                 bsCollapsePanel("Ticket Number Assignments (click to expand)",
                                                 radioButtons("ticketSort", label = NULL,
                                                              choices = c("Order by ticket number" = "number",
                                                                          "Order by person"        = "person"),
                                                              selected = "number", inline = TRUE),
                                                 DT::dataTableOutput("ticketAssignments"),
                                                 style = "default"
                                 )
                               ),
                               br(),
                               "START number drawn: ", textOutput("startNum", inline = TRUE),
                               br(), br(),
                               fluidRow(
                                 column(6,
                                        "These are the winners under the alternative algorithm:",
                                        DT::dataTableOutput("altWinners"),
                                        downloadButton("downloadAltWinners", "Download Alt Winners")
                                 ),
                                 column(6,
                                        "These are the waitlisted entrants under the alternative algorithm:",
                                        DT::dataTableOutput("altWaitlist"),
                                        downloadButton("downloadAltWaitlist", "Download Alt Waitlist")
                                 )
                               ),
                               style = "info"
               )
    ), #bsCollapse
  ), #fluidPage

  server <- function(input, output) {

    output$tickets <- renderText({
      1 + 4*input$volunteer + 6*input$coursemark + 2*input$finishes
    })

    output$oddsTable <- DT::renderDataTable({
      datatable(odds_table) %>%
        formatPercentage("odds_of_selection", digits = 2) %>%
        formatRound(c("tickets_per_applicant", "num_people_taken"), digits = 3)
    })

    # WINNERS
    winners <- reactive({
      req(input$num, input$num2)
      if (input$num == input$num2) {
        set.seed(input$num)
        selected      <- sample_n(df, n_pick, replace = FALSE, weight = df$tickets)
        out           <- subset(selected, select = c("Name", "tickets"))
        out$Num       <- seq.int(nrow(out))
        as.data.frame(out)
      }
    })

    output$valueWinners <- DT::renderDataTable(
      winners(), options = list(pageLength = 10)
    )
    output$downloadWinners <- downloadHandler(
      filename = function() { "Winners.csv" },
      content  = function(fname) { write.csv(winners(), fname) }
    )

    # WAITLIST
    waitlist <- reactive({
      req(input$num, input$num2)
      if (input$num == input$num2) {
        set.seed(input$num)
        selected      <- sample_n(df, n_pick, replace = FALSE, weight = df$tickets)
        waitlist_pool <- anti_join(df, selected, by = "Name")
        waiters       <- sample_n(waitlist_pool, n_wait_pick, replace = FALSE, weight = waitlist_pool$tickets)
        out           <- subset(waiters, select = c("Name", "tickets"))
        out$Num       <- seq.int(nrow(out))
        as.data.frame(out)
      }
    })

    output$valueWaitlist <- renderDataTable(
      waitlist(), options = list(pageLength = 10)
    )
    output$downloadWaitlist <- downloadHandler(
      filename = function() { "Waitlist.csv" },
      content  = function(fname) { write.csv(waitlist(), fname) }
    )

    # ALTERNATIVE ALGORITHM
    # Build the full ticket table and run the count-up-from-START selection
    alt_draw <- reactive({
      req(input$num, input$num2)
      if (input$num == input$num2) {
        set.seed(input$num)

        total_tickets <- sum(df$tickets)

        # Assign a unique random number (1..total_tickets) to each ticket
        ticket_numbers <- sample(1:total_tickets, total_tickets, replace = FALSE)

        # Expand df so each row is one ticket
        ticket_owner <- rep(df$Name, times = df$tickets)
        ticket_df <- data.frame(
          Name         = ticket_owner,
          TicketNumber = ticket_numbers,
          stringsAsFactors = FALSE
        )

        # Draw START
        start <- sample(1:total_tickets, 1)

        # Compute "distance counting up" from START with wraparound
        ticket_df$Distance <- (ticket_df$TicketNumber - start) %% total_tickets

        # Sort by distance (closest first)
        ticket_df <- ticket_df[order(ticket_df$Distance), ]

        # Walk through, selecting each entrant the first time we see them
        selected_names  <- character(0)
        selection_order <- integer(0)
        pick_num <- 0
        for (i in seq_len(nrow(ticket_df))) {
          name <- ticket_df$Name[i]
          if (!(name %in% selected_names)) {
            pick_num <- pick_num + 1
            selected_names  <- c(selected_names, name)
            selection_order <- c(selection_order, pick_num)
          }
          if (pick_num == n_pick + n_wait_pick) break
        }

        list(
          ticket_df   = ticket_df,
          ordered     = selected_names,
          start       = start
        )
      }
    })

    output$startNum <- renderText({
      req(alt_draw())
      as.character(alt_draw()$start)
    })

    output$ticketAssignments <- DT::renderDataTable({
      req(alt_draw())
      out <- alt_draw()$ticket_df[, c("Name", "TicketNumber")]
      if (input$ticketSort == "number") {
        out <- out[order(out$TicketNumber), ]
      } else {
        out <- out[order(out$Name, out$TicketNumber), ]
      }
      datatable(out, rownames = FALSE, options = list(pageLength = 15))
    })

    output$altWinners <- DT::renderDataTable({
      req(alt_draw())
      winners <- alt_draw()$ordered[1:n_pick]
      out <- data.frame(Num = seq_along(winners), Name = winners)
      datatable(out, rownames = FALSE, options = list(pageLength = 10))
    })
    output$downloadAltWinners <- downloadHandler(
      filename = function() { "AltWinners.csv" },
      content  = function(fname) {
        winners <- alt_draw()$ordered[1:n_pick]
        write.csv(data.frame(Num = seq_along(winners), Name = winners), fname, row.names = FALSE)
      }
    )

    output$altWaitlist <- DT::renderDataTable({
      req(alt_draw())
      waiters <- alt_draw()$ordered[(n_pick + 1):(n_pick + n_wait_pick)]
      out <- data.frame(Num = seq_along(waiters), Name = waiters)
      datatable(out, rownames = FALSE, options = list(pageLength = 10))
    })
    output$downloadAltWaitlist <- downloadHandler(
      filename = function() { "AltWaitlist.csv" },
      content  = function(fname) {
        waiters <- alt_draw()$ordered[(n_pick + 1):(n_pick + n_wait_pick)]
        write.csv(data.frame(Num = seq_along(waiters), Name = waiters), fname, row.names = FALSE)
      }
    )

  }, #CLOSE SERVER
  options = list(height = 900)
)
