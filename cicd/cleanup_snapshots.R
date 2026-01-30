snapshot_dir <- "outputs/snapshots"
log_dir <- "cicd/logs"
log_path <- file.path(log_dir, "cleanup_latest.log")

log_action <- function(action, msg) {
  date_tag <- format(Sys.Date(), "%Y-%m-%d")
  line <- sprintf("[%s %s] %s", action, date_tag, msg)
  dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)
  cat(line, "\n", file = log_path, append = TRUE)
  message(line)
}

if (!dir.exists(snapshot_dir)) {
  log_action("cleanup", paste0("Snapshot directory not found: ", snapshot_dir))
} else {
  snapshots <- list.files(snapshot_dir, pattern = "^snapshot_.*\\.rds$", full.names = TRUE)
  if (length(snapshots) <= 3) {
    log_action("cleanup", paste0("Nothing to clean. Snapshots found: ", length(snapshots)))
  } else {
    info <- file.info(snapshots)
    ordered <- snapshots[order(info$mtime, decreasing = TRUE)]
    to_keep <- ordered[seq_len(3)]
    to_remove <- setdiff(snapshots, to_keep)

    if (length(to_remove) > 0) {
      removed <- file.remove(to_remove)
      log_action("cleanup", paste0("Removed ", sum(removed), " snapshot(s). Kept ", length(to_keep), "."))
    } else {
      log_action("cleanup", "Nothing to remove.")
    }
  }
}
