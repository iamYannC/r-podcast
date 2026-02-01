snapshot_dir <- "outputs/snapshots"
log_path <- file.path("cicd", "logs.txt")
log_task <- "snapshot-cleanup"

log_action <- function(task, msg) {
  date_tag <- format(Sys.Date(), "%Y-%m-%d")
  line <- sprintf("[%s %s] %s", task, date_tag, msg)
  dir.create("cicd", showWarnings = FALSE, recursive = TRUE)
  cat(line, "\n", file = log_path, append = TRUE)
  message(line)
}

if (!dir.exists(snapshot_dir)) {
  log_action(log_task, paste0("Snapshot directory not found: ", snapshot_dir))
} else {
  snapshots <- list.files(
    snapshot_dir,
    pattern = "^snapshot_\\d{4}-\\d{2}-\\d{2}.*\\.rds$",
    full.names = TRUE
  )
  if (length(snapshots) <= 3) {
    log_action(log_task, paste0("Nothing to clean. Snapshots found: ", length(snapshots)))
  } else {
    info <- file.info(snapshots)
    ordered <- snapshots[order(info$mtime, decreasing = TRUE)]
    to_keep <- ordered[seq_len(3)]
    to_remove <- setdiff(snapshots, to_keep)

    if (length(to_remove) > 0) {
      removed <- file.remove(to_remove)
      log_action(log_task, paste0("Removed ", sum(removed), " snapshot(s). Kept ", length(to_keep), "."))
    } else {
      log_action(log_task, "Nothing to remove.")
    }
  }
}
