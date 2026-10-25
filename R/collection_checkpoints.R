# =============================================================================
# Collection-stage manual and external checkpoints
# =============================================================================
# Created: 2026-10-05
# =============================================================================

#' Run the existing manual/external source checkpoints before estimation.
#'
#' D4.1 microdata files are validated by the D4.1 manifest, which runs after
#' preprocessing, so they are not re-checked here.
#'
#' @param params Pipeline parameters.
#' @return Named list of checkpoint results.
#' @export
run_collection_checkpoints <- function(params) {
  list(
    imf = checkpoint_imf_workbook(params),
    wdi = checkpoint_wdi_metadata(params),
    ilo = checkpoint_ilo_lfp(params),
    odin = verify_odin_data(params),
    unigme = verify_unigme_data(params)
  )
}
