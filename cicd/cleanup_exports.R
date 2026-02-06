export_dir <- "outputs/exports"
log_path <- file.path("cicd", "logs.txt")
log_task <- "export-cleanup"

log_action <- function(task, msg) {
  date_tag <- format(Sys.Date(), "%Y-%m-%d")
  line <- sprintf("[%s %s] %s", task, date_tag, msg)
  dir.create("cicd", showWarnings = FALSE, recursive = TRUE)
  cat(line, "\n", file = log_path, append = TRUE)
  message(line)
}

if (!dir.exists(export_dir)) {
  log_action(log_task, paste0("Export directory not found: ", export_dir))
} else {
  keep <- file.path(export_dir, c("snapshot_xlsx.xlsx", "snapshot_sqlite.sqlite"))
  exports <- list.files(
    export_dir,
    pattern = "^snapshot_.*\\.(xlsx|sqlite)$",
    full.names = TRUE
  )

  if (length(exports) == 0) {
    log_action(log_task, "No exports found.")
  } else {
    to_remove <- setdiff(exports, keep)
    if (length(to_remove) > 0) {
      removed <- file.remove(to_remove)
      log_action(
        log_task,
        paste0(
          "Removed ",
          sum(removed),
          " export(s)."
        )
      )
    } else {
      log_action(log_task, "Nothing to remove.")
    }
  }
}
