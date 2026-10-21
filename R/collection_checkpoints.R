# =============================================================================
# Collection-stage manual and external checkpoints
# =============================================================================
# Created: 2026-10-05
# =============================================================================

#' Run the existing manual/external source checkpoints before estimation.
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
    nada = verify_nada_data(params),
    microdata = verify_microdata_files(params),
    unigme = verify_unigme_data(params)
  )
}
